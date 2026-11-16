#!/usr/bin/env bash
# Serves a local mirror of one release and checks install.sh against it: a good copy installs, a tampered one is refused.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$1 tag=$2 asset=$3
work=$(mktemp -d)
trap 'kill "$server" 2> /dev/null; rm -rf "$work"' EXIT

mkdir -p "$work/good/$tag" "$work/bad/$tag"
for f in "$asset" "$asset.sha256"; do
  curl -fsSL --retry 5 -o "$work/good/$tag/$f" "https://github.com/peachq-org/peachq/releases/download/$tag/$f"
done
cp "$work/good/$tag/$asset" "$work/bad/$tag/"
printf '%064d  %s\n' 0 "$asset" > "$work/bad/$tag/$asset.sha256"

port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$work" > /dev/null 2>&1 & server=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do curl -fs -o /dev/null "http://127.0.0.1:$port/" && break; sleep 1; done

q=$(PEACHQ_DIST_URL=http://127.0.0.1:$port/good ./install.sh --version "$version" --dir "$work/out-good")
grep -qx "source=http://127.0.0.1:$port/good" "$work/out-good/.peachq-install"
echo "mirror install ok: $q"

if PEACHQ_DIST_URL=http://127.0.0.1:$port/bad ./install.sh --version "$version" --dir "$work/out-bad" 2> "$work/err"; then
  echo "a tampered checksum installed"; exit 1
fi
grep -q 'checksum mismatch' "$work/err"
[ ! -e "$work/out-bad" ]
echo "tampered mirror refused: $(tail -1 "$work/err")"
