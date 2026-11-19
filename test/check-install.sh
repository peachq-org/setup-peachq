#!/usr/bin/env bash
# After the action: its exports agree, q is not this binary on PATH, and q reports the version asked for. Env: REQUESTED Q_PATH Q_VERSION
set -euxo pipefail
cd "$(dirname "$0")"
[ "$QCMD" = "$Q_PATH" ] && [ "$PEACHQ_Q" = "$Q_PATH" ]
if [ "${RUNNER_OS:-}" = Windows ]; then
  case $Q_PATH in [A-Za-z]:\\*\\q.exe) ;; *) exit 1 ;; esac
  [ "$(command -v q)" != "$(cygpath -u "${Q_PATH%.exe}")" ]
else
  case $Q_PATH in /*) ;; *) exit 1 ;; esac
  [ "$(command -v q)" != "$Q_PATH" ]
fi
want=${REQUESTED#v}
[ "$REQUESTED" != latest ] || want=
case $Q_VERSION in "$want"*) ;; *) exit 1 ;; esac
WANT=$want "$QCMD" version.q < /dev/null
