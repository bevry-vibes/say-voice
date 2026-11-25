#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
"$ROOT/scripts/build.sh" >/dev/null
exec swift "$ROOT/.build/say-voice.swift" "$@"
