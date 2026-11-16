#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
"$QCMD" smoke.q < /dev/null
"$QCMD" smoke.q -classic < /dev/null
