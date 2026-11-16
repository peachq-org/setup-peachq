#!/usr/bin/env bash
# After the action: its exports agree, q is off PATH, and q reports the version asked for. Env: REQUESTED Q_PATH Q_VERSION
set -euxo pipefail
cd "$(dirname "$0")"
[ "$QCMD" = "$Q_PATH" ] && [ "$PEACHQ_Q" = "$Q_PATH" ]
case $Q_PATH in /*) ;; *) exit 1 ;; esac
[ "$(command -v q)" != "$Q_PATH" ]
want=${REQUESTED#v}
[ "$REQUESTED" != latest ] || want=
case $Q_VERSION in "$want"*) ;; *) exit 1 ;; esac
WANT=$want "$QCMD" version.q < /dev/null
