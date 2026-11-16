#!/usr/bin/env bash
# Serves a local mirror in peachq.org's flat layout and checks install.sh against it: a good copy installs, a
# tampered one is refused. Usage: test/mirror.sh <version> <release tag> <platform>
set -euo pipefail
cd "$(dirname "$0")/.."
version=$1 tag=$2 plat=$3
name=peachq-v${tag#v}.0-${plat/macos/darwin}.tar.gz
work=$(mktemp -d)
trap 'kill "$server" 2> /dev/null; rm -rf "$work"' EXIT

mkdir -p "$work/good" "$work/bad"
curl -fsSL --retry 5 -o "$work/good/$name" "https://github.com/peachq-org/peachq/releases/download/$tag/peachq-$plat.tar.gz"
curl -fsSL --retry 5 "https://github.com/peachq-org/peachq/releases/download/$tag/peachq-$plat.tar.gz.sha256" |
  cut -d' ' -f1 > "$work/good/$name.sha256"
cp "$work/good/$name" "$work/bad/"
printf '%064d  %s\n' 0 "$name" > "$work/bad/$name.sha256"

port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$work" > /dev/null 2>&1 & server=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do curl -fs -o /dev/null "http://127.0.0.1:$port/" && break; sleep 1; done

q=$(PEACHQ_DIST_URL=http://127.0.0.1:$port/good ./install.sh --version "$version" --dir "$work/out-good")
grep -qx "from=http://127.0.0.1:$port/good/$name" "$work/out-good/.peachq-install"
echo "mirror install ok: $q"

if PEACHQ_DIST_URL=http://127.0.0.1:$port/bad ./install.sh --version "$version" --dir "$work/out-bad" 2> "$work/err"; then
  echo "a tampered checksum installed"; exit 1
fi
grep -q 'checksum mismatch' "$work/err"
[ ! -e "$work/out-bad" ]
echo "tampered mirror refused: $(tail -1 "$work/err")"
