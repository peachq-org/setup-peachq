#!/usr/bin/env bash
# Install a peachq release and print the absolute path of its q. Usage: install.sh [--version V] [--dir D]
set -euo pipefail

REPO=peachq-org/peachq
GITHUB_BASE=https://github.com/$REPO/releases/download

say() { printf 'setup-peachq: %s\n' "$*" >&2; }
die() { say "error: $*"; exit 1; }

usage() {
  cat >&2 <<'EOF'
usage: install.sh [--version V] [--dir D]
  V   0.92.20261115 (exact build), v0.92 (release tag) or latest       env PEACHQ_VERSION
  D   install directory (default ~/.peachq/<V>/<platform>)            env PEACHQ_INSTALL_DIR
env PEACHQ_DIST_URL   a mirror laid out as <url>/<tag>/<asset>, used instead of GitHub Releases
env PEACHQ_PLATFORM   linux-x86_64 | linux-arm64 | macos-arm64 (default: this machine)
EOF
}

version=${PEACHQ_VERSION:-}
dir=${PEACHQ_INSTALL_DIR:-}
while [ $# -gt 0 ]; do
  case $1 in
    --version) [ $# -ge 2 ] || die "--version needs a value"; version=$2; shift 2 ;;
    --dir) [ $# -ge 2 ] || die "--dir needs a value"; dir=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "unknown argument: $1" ;;
  esac
done
[ -n "$version" ] || { usage; die "no version: pin one (e.g. --version 0.92.20261115) or say latest"; }

platform() {
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64|Linux-amd64) echo linux-x86_64 ;;
    Linux-aarch64|Linux-arm64) echo linux-arm64 ;;
    Darwin-arm64) echo macos-arm64 ;;
    *) die "no peachq build for $(uname -s) $(uname -m); builds exist for linux-x86_64, linux-arm64, macos-arm64" ;;
  esac
}
plat=${PEACHQ_PLATFORM:-$(platform)}
case $plat in linux-x86_64|linux-arm64|macos-arm64) ;; *) die "unknown platform $plat" ;; esac
asset=peachq-$plat.tar.gz

if [ -n "${PEACHQ_DIST_URL:-}" ]; then bases=("${PEACHQ_DIST_URL%/}"); else bases=("$GITHUB_BASE"); fi

curl_() { curl -sSL --retry 5 --retry-connrefused --retry-delay 2 --connect-timeout 20 --max-time 600 "$@"; }

# fetch <url> <file>: 0 fetched, 1 not there (404), anything else dies
fetch() {
  local code
  code=$(curl_ -o "$2" -w '%{http_code}' "$1") || die "download failed: $1"
  case $code in
    200) return 0 ;;
    404) return 1 ;;
    *) die "$1: HTTP $code" ;;
  esac
}

exact_re='^v?([0-9]+\.[0-9]+)\.[0-9]{8}$'
tag_re='^v?[0-9]+\.[0-9]+(\.[0-9]+)?$'
want=
if [ "$version" = latest ]; then
  [ -z "${PEACHQ_DIST_URL:-}" ] || die "latest is resolved on GitHub only; pin a version when using PEACHQ_DIST_URL"
  url=$(curl_ -f -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest") ||
    die "could not resolve the latest peachq release"
  tags=("${url##*/}")
  [[ ${tags[0]} =~ $tag_re ]] || die "latest resolved to an unexpected tag: ${tags[0]}"
elif [[ $version =~ $exact_re ]]; then
  want=${version#v}
  tags=("v$want" "v${BASH_REMATCH[1]}")
elif [[ $version =~ $tag_re ]]; then
  tags=("v${version#v}")
else
  die "version '$version' is not 0.92.20261115, v0.92 or latest"
fi

[ -n "$dir" ] || dir=$HOME/.peachq/$version/$plat
mkdir -p "$(dirname "$dir")"
dir=$(cd "$(dirname "$dir")" && pwd)/$(basename "$dir")

pq_version() {
  printf '%s\n' '-1 .pq.version;' 'exit 0' > "$tmp/version.q"
  "$1" "$tmp/version.q" < /dev/null 2> /dev/null | head -1
}

tmp=$(mktemp -d "$(dirname "$dir")/.peachq.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

installed() {
  local f=$dir/.peachq-install b from=
  [ -n "$want" ] && [ -x "$dir/q" ] && grep -qx "version=$want" "$f" 2> /dev/null && grep -qx "asset=$asset" "$f" ||
    return 1
  for b in "${bases[@]}"; do grep -qx "source=$b" "$f" && from=$b; done
  [ -n "$from" ] && [ "$(pq_version "$dir/q")" = "$want" ]
}
if installed; then
  say "peachq $want already installed at $dir"
  echo "$dir/q"
  exit 0
fi
if [ -e "$dir" ] && [ ! -f "$dir/.peachq-install" ]; then
  [ -d "$dir" ] && [ -z "$(ls -A "$dir")" ] ||
    die "$dir already holds something that is not a peachq install; name a new or empty directory"
fi

sha256() { { sha256sum "$1" 2> /dev/null || shasum -a 256 "$1"; } | cut -d' ' -f1; }

attest() {
  local out
  if ! command -v gh > /dev/null || ! gh attestation --help > /dev/null 2>&1; then
    say "notice: gh attestation is not available here; checksum verified, build provenance not checked"
  elif out=$(gh api "repos/$REPO/attestations/sha256:$1" 2>&1); then
    gh attestation verify "$2" -R "$REPO" >&2 || die "$asset ($tag) failed attestation verification"
    say "build attestation verified"
  elif printf '%s' "$out" | grep -q 'HTTP 404'; then
    say "notice: no build attestation is published for $asset ($tag) - releases up to v0.92 have none; checksum verified"
  else
    say "notice: could not look up attestations ($(printf '%s' "$out" | tail -1)); checksum verified"
  fi
}

tried=() tag= base=
for t in "${tags[@]}"; do
  for b in "${bases[@]}"; do
    tried+=("$b/$t/$asset")
    if fetch "$b/$t/$asset" "$tmp/$asset"; then tag=$t base=$b; break 2; fi
  done
done
[ -n "$tag" ] || die "peachq $version: no $asset at $(printf '%s ' "${tried[@]}")"
fetch "$base/$tag/$asset.sha256" "$tmp/$asset.sha256" || die "$base/$tag/$asset.sha256 is missing; refusing an unverified download"

sum=$(sha256 "$tmp/$asset")
expected=$(cut -d' ' -f1 < "$tmp/$asset.sha256")
[[ $expected =~ ^[0-9a-f]{64}$ ]] || die "$asset.sha256 holds no sha256"
[ "$sum" = "$expected" ] || die "$asset checksum mismatch: got $sum, $asset.sha256 says $expected"
say "checksum verified: $asset ($tag) $sum"
attest "$sum" "$tmp/$asset"

mkdir "$tmp/peachq"
tar -xzf "$tmp/$asset" -C "$tmp/peachq"
[ -x "$tmp/peachq/q" ] || die "$asset holds no q"
got=$(pq_version "$tmp/peachq/q")
[ -n "$got" ] || die "the q in $asset did not start"
[ -z "$want" ] || [ "$got" = "$want" ] ||
  die "asked for peachq $want but release $tag holds $got; pin $got, or install $want from a mirror that keeps it"
printf 'version=%s\ntag=%s\nasset=%s\nsha256=%s\nsource=%s\n' "$got" "$tag" "$asset" "$sum" "$base" > "$tmp/peachq/.peachq-install"

rm -rf "$dir"
mv "$tmp/peachq" "$dir"
say "peachq $got installed at $dir"
echo "$dir/q"
