#!/usr/bin/env bash
# install.sh on its own: it installs then reuses an exact build, never replaces a foreign directory, names a missing
# version, and takes a mirror in peachq.org's layout but refuses one with a bad checksum.
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

q=$(./install.sh --version 0.92.20261115 --dir "$work/pq")
case $q in "$work/pq/q"|"$work/pq/q.exe") ;; *) exit 1 ;; esac
./install.sh --version 0.92.20261115 --dir "$work/pq" 2>&1 > /dev/null | grep 'already installed'

mkdir "$work/mine" && touch "$work/mine/keep"
if ./install.sh --version 0.92.20261115 --dir "$work/mine"; then exit 1; fi
[ -f "$work/mine/keep" ]

if out=$(./install.sh --version 0.0.20000101 --dir "$work/none" 2>&1); then exit 1; fi
echo "$out" | grep -F 'peachq 0.0.20000101: no '

case "$(uname -s)" in Darwin) plat=macos-arm64 ;; MINGW*|MSYS*|CYGWIN*) plat=windows-x86_64 ;; *) plat=linux-x86_64 ;; esac
test/mirror.sh 0.92.20261115 v0.92 "$plat"
echo "install.sh: all ok"
