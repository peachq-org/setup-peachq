#!/usr/bin/env bash
# After the action with args "-classic it's": plain q is a shim appending them after the caller's arguments; QCMD is not.
set -euxo pipefail
cd "$(dirname "$0")"
[ "$(command -v q)" != "$PEACHQ_Q" ] && [ "$QCMD" = "$PEACHQ_Q" ]
diff <(printf '%s\n' '"xx"' '"-y"' "\"it's\"" a - 1 2) <(q args.q xx -y < /dev/null)
"$QCMD" args.q < /dev/null | grep -F '| a'
echo 'show ([] a:1 2)' | q | grep -x -- -
