#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [[ ! -f .env.example ]]; then
  echo "Missing .env.example" >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example"
  echo "Edit .env and add your API keys before starting Ada-SI."
else
  echo ".env already exists"
fi

mkdir -p chat/staging chat/custom_tools logs

echo ""
echo "Ada-SI native install (macOS/Linux)"
echo ""

if ! command -v python3.12 >/dev/null 2>&1; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "Python 3.12 or Python 3 is required. Install Python 3.12 first." >&2
    exit 1
  fi
fi

bash "$ROOT/start.sh" --install-only

echo ""
echo "Native install complete."
echo "Next: edit .env if needed, then run ./start.sh"
echo ""
