#!/usr/bin/env bash
# After the action with classic: plain q is a shim that appends -classic after the caller's arguments; QCMD is not.
set -euxo pipefail
cd "$(dirname "$0")"
[ "$(command -v q)" != "$PEACHQ_Q" ] && [ "$QCMD" = "$PEACHQ_Q" ]
diff <(printf '%s\n' '"xx"' '"-y"' a - 1 2) <(q classic.q xx -y < /dev/null)
"$QCMD" classic.q < /dev/null | grep -F '| a'
echo 'show ([] a:1 2)' | q | grep -x -- -
