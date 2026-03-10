#!/usr/bin/env bash
set -euo pipefail

export CAP4D_PATH="${CAP4D_PATH:-/workspace/cap4d}"
export CAP4D_RUNTIME_ROOT="${CAP4D_RUNTIME_ROOT:-/workspace/runtime}"
export PIXEL3DMM_PATH="${PIXEL3DMM_PATH:-$CAP4D_RUNTIME_ROOT/pixel3dmm}"
export PYTHONPATH="${CAP4D_PATH}:${PYTHONPATH:-}"

mkdir -p "$CAP4D_RUNTIME_ROOT"

cd "$CAP4D_PATH"

exec jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --allow-root \
  --ServerApp.root_dir="$CAP4D_PATH" \
  --ServerApp.token="${JUPYTER_TOKEN:-cap4d}"
