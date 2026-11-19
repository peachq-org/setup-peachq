#!/usr/bin/env bash
# Install a peachq release and print the absolute path of its q. Usage: install.sh [--version V] [--dir D] [--duckdb]
set -euo pipefail

REPO=peachq-org/peachq
GITHUB_BASE=https://github.com/$REPO/releases/download

say() { printf 'setup-peachq: %s\n' "$*" >&2; }
die() { say "error: $*"; exit 1; }

usage() {
  cat >&2 <<'EOF'
usage: install.sh [--version V] [--dir D] [--duckdb]
  V   0.92.20261116 (exact build), v0.92 (release tag) or latest       env PEACHQ_VERSION
  D   install directory (default ~/.peachq/<V>/<platform>[-duckdb])   env PEACHQ_INSTALL_DIR
  --duckdb  the build with DuckDB bundled (s) SQL, Parquet, s3://)    env PEACHQ_DUCKDB=true
env PEACHQ_DIST_URL   download from https://peachq.org/file, or a mirror with its flat layout
                      (<url>/peachq-v<version>-<platform>.tar.gz or .zip, + .sha256), instead of GitHub Releases
env PEACHQ_PLATFORM   linux-x86_64 | linux-arm64 | macos-arm64 | windows-x86_64 (default: this machine)
EOF
}

version=${PEACHQ_VERSION:-}
dir=${PEACHQ_INSTALL_DIR:-}
duckdb=${PEACHQ_DUCKDB:-false}
while [ $# -gt 0 ]; do
  case $1 in
    --version) [ $# -ge 2 ] || die "--version needs a value"; version=$2; shift 2 ;;
    --dir) [ $# -ge 2 ] || die "--dir needs a value"; dir=$2; shift 2 ;;
    --duckdb) duckdb=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "unknown argument: $1" ;;
  esac
done
case $duckdb in true|false) ;; *) die "PEACHQ_DUCKDB is '$duckdb', not true or false" ;; esac
[ -n "$version" ] || { usage; die "no version: pin one (e.g. --version 0.92.20261116) or say latest"; }

platform() {
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64|Linux-amd64) echo linux-x86_64 ;;
    Linux-aarch64|Linux-arm64) echo linux-arm64 ;;
    Darwin-arm64) echo macos-arm64 ;;
    MINGW*-x86_64|MSYS*-x86_64|CYGWIN*-x86_64) echo windows-x86_64 ;;
    *) die "no peachq build for $(uname -s) $(uname -m); builds exist for linux-x86_64, linux-arm64, macos-arm64, windows-x86_64" ;;
  esac
}
plat=${PEACHQ_PLATFORM:-$(platform)}
case $plat in
  linux-x86_64|linux-arm64|macos-arm64) ext=tar.gz exe=q ;;
  windows-x86_64) ext=zip exe=q.exe ;;
  *) die "unknown platform $plat" ;;
esac
flavour=
[ "$duckdb" = false ] || flavour=-duckdb
asset=peachq-$plat$flavour.$ext
# peachq.org's names: darwin for macos, and its Linux DuckDB builds say -glibc, as GitHub's do not
site=${plat/macos/darwin}
[ "$duckdb" = false ] || [[ $plat != linux-* ]] || site+=-glibc
site+=$flavour
base=${PEACHQ_DIST_URL:-$GITHUB_BASE}
base=${base%/}

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

# candidates <release...>: each release's archive URL. GitHub Releases hold <tag>/<asset>; peachq.org (and a
# mirror of it) holds a flat peachq-v<version>-<platform> where a release tag vX.Y is the version X.Y.0
candidates() {
  local r
  for r; do
    if [ "$base" = "$GITHUB_BASE" ]; then echo "$base/v$r/$asset"
    elif [[ $r =~ ^[0-9]+\.[0-9]+$ ]]; then echo "$base/peachq-v$r.0-$site.$ext"
    else echo "$base/peachq-v$r-$site.$ext"
    fi
  done
}

exact_re='^v?([0-9]+\.[0-9]+)\.[0-9]{8}$'
tag_re='^v?([0-9]+\.[0-9]+(\.[0-9]+)?)$'
want=
if [ "$version" = latest ] && [ "$base" = "$GITHUB_BASE" ]; then
  url=$(curl_ -f -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest") ||
    die "could not resolve the latest peachq release"
  [[ ${url##*/} =~ $tag_re ]] || die "latest resolved to an unexpected tag: ${url##*/}"
  urls=$(candidates "${BASH_REMATCH[1]}")
elif [ "$version" = latest ]; then
  name=$(curl_ -f "$base/latest.json" | grep -o "\"peachq-v[^\"]*-$site\.${ext/./\\.}\"" | tr -d '"') ||
    die "$base/latest.json names no versioned $site build"
  urls=$base/$name
elif [[ $version =~ $exact_re ]]; then
  want=${version#v}
  urls=$(candidates "$want" "${BASH_REMATCH[1]}")
elif [[ $version =~ $tag_re ]]; then
  urls=$(candidates "${BASH_REMATCH[1]}")
else
  die "version '$version' is not 0.92.20261116, v0.92 or latest"
fi

[ -n "$dir" ] || dir=$HOME/.peachq/$version/$plat$flavour
mkdir -p "$(dirname "$dir")"
dir=$(cd "$(dirname "$dir")" && pwd)/$(basename "$dir")

pq_version() {
  printf '%s\n' '-1 .pq.version;' 'exit 0' > "$tmp/version.q"
  # Not < /dev/null: Windows q takes NUL for a console and prints its banner first.
  : | "$1" "$tmp/version.q" 2> /dev/null | tr -d '\r' | head -1
}

tmp=$(mktemp -d "$(dirname "$dir")/.peachq.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

installed() {
  local f=$dir/.peachq-install
  [ -n "$want" ] && [ -x "$dir/$exe" ] && grep -qx "version=$want" "$f" 2> /dev/null && grep -qx "platform=$plat" "$f" &&
    grep -qx "duckdb=$duckdb" "$f" &&
    grep -qx "source=$base" "$f" && [ "$(pq_version "$dir/$exe")" = "$want" ]
}
if installed; then
  say "peachq $want already installed at $dir"
  echo "$dir/$exe"
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
  elif ! gh auth status > /dev/null 2>&1; then
    say "notice: gh is not signed in (set GH_TOKEN to check build provenance); checksum verified"
  elif out=$(gh api "repos/$REPO/attestations/sha256:$1" 2>&1); then
    gh attestation verify "$2" -R "$REPO" >&2 || die "$from failed attestation verification"
    say "build attestation verified"
  elif printf '%s' "$out" | grep -q 'HTTP 404'; then
    say "notice: no build attestation is published for $from - releases up to v0.92 have none; checksum verified"
  else
    say "notice: could not look up attestations ($(printf '%s' "$out" | tail -1)); checksum verified"
  fi
}

from=
for u in $urls; do
  if fetch "$u" "$tmp/peachq.$ext"; then from=$u; break; fi
done
hint=
[ -z "$flavour" ] || [ "$base" = "$GITHUB_BASE" ] || hint="; peachq.org keeps no pinned DuckDB builds, so leave dist-url unset for GitHub Releases"
[ -n "$from" ] || die "peachq $version: no $plat$flavour build at $(printf '%s ' $urls)$hint"
fetch "$from.sha256" "$tmp/peachq.$ext.sha256" || die "$from.sha256 is missing; refusing an unverified download"

sum=$(sha256 "$tmp/peachq.$ext")
expected=$(cut -d' ' -f1 < "$tmp/peachq.$ext.sha256")
[[ $expected =~ ^[0-9a-f]{64}$ ]] || die "$from.sha256 holds no sha256"
[ "$sum" = "$expected" ] || die "checksum mismatch for $from: got $sum, its .sha256 says $expected"
say "checksum verified: $from $sum"
attest "$sum" "$tmp/peachq.$ext"

mkdir "$tmp/peachq"
if [ "$ext" = zip ]; then unzip -q "$tmp/peachq.zip" -d "$tmp/peachq"; else tar -xzf "$tmp/peachq.$ext" -C "$tmp/peachq"; fi
[ -x "$tmp/peachq/$exe" ] || die "$from holds no $exe"
[ "$duckdb" = false ] || ls "$tmp/peachq" | grep -Eqx '(lib)?duckdb\.(so|dylib|dll)' || die "$from holds no DuckDB library"
got=$(pq_version "$tmp/peachq/$exe") || got=
[ -n "$got" ] || die "the q in $from did not start"
[ -z "$want" ] || [ "$got" = "$want" ] ||
  die "asked for peachq $want but $from holds $got; pin $got, or install $want from a mirror that keeps it"
printf 'version=%s\nplatform=%s\nduckdb=%s\nsource=%s\nfrom=%s\nsha256=%s\n' "$got" "$plat" "$duckdb" "$base" "$from" "$sum" \
  > "$tmp/peachq/.peachq-install"

rm -rf "$dir"
mv "$tmp/peachq" "$dir"
say "peachq $got installed at $dir"
echo "$dir/$exe"
