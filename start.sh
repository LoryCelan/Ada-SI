#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

DEV=false
SKIP_BUILD=false
NO_BROWSER=false
INSTALL_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --dev|-d) DEV=true ;;
    --skip-build) SKIP_BUILD=true ;;
    --no-browser) NO_BROWSER=true ;;
    --install-only) INSTALL_ONLY=true ;;
    --help|-h)
      echo "Usage: ./start.sh [--dev] [--skip-build] [--no-browser] [--install-only]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

LOG_DIR="$ROOT/logs"
PID_FILE="$ROOT/.ada-si.pids"
APP_VENV="$ROOT/.venv"
LITELLM_VENV="$ROOT/.venv-litellm"
TOOL_RUNTIME_VENV="$ROOT/chat/.tool_runtime_venv"
FRONTEND_DIR="$ROOT/chat/frontend"
STATIC_INDEX="$ROOT/chat/static/index.html"
CUSTOM_TOOLS_DIR="$ROOT/chat/custom_tools"
CONFIG_PATH="$ROOT/litellm/config.yaml"

find_python() {
  local candidates=("python3.12" "python3" "python")
  for candidate in "${candidates[@]}"; do
    if command -v "$candidate" >/dev/null 2>&1; then
      version_output=$("$candidate" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)
      if [[ "$version_output" == "3.12" ]]; then
        echo "$candidate"
        return 0
      fi
    fi
  done

  for candidate in "${candidates[@]}"; do
    if command -v "$candidate" >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

ensure_venv() {
  local venv_dir="$1"
  local py_bin="$2"
  if [[ ! -x "$venv_dir/bin/python" ]]; then
    echo "Creating venv at $venv_dir"
    "$py_bin" -m venv "$venv_dir"
  fi
}

wait_http() {
  local url="$1"
  local timeout_sec="${2:-90}"
  local deadline=$((SECONDS + timeout_sec))
  while (( SECONDS < deadline )); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

stop_services() {
  if [[ -f "$PID_FILE" ]]; then
    while IFS= read -r pid; do
      [[ -n "$pid" ]] || continue
      kill "$pid" 2>/dev/null || true
    done < "$PID_FILE"
    rm -f "$PID_FILE"
  fi

  for port in 8080 8090 4000 5173; do
    pids=$(lsof -ti tcp:"$port" 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
      echo "$pids" | tr ' ' '\n' | while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        kill "$pid" 2>/dev/null || true
      done
    fi
  done
}

start_bg() {
  local name="$1"
  local command="$2"
  local log_file="$LOG_DIR/$name.log"
  rm -f "$log_file"
  nohup bash -lc "$command" >"$log_file" 2>&1 &
  echo $! >> "$PID_FILE"
}

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Missing LiteLLM config at $CONFIG_PATH" >&2
  exit 1
fi

PY_BIN="$(find_python || true)"
if [[ -z "$PY_BIN" ]]; then
  echo "Python 3.12+ not found. Install Python and ensure python3.12 or python3 is on PATH." >&2
  exit 1
fi

if [[ ! -f "$ROOT/.env" ]]; then
  cp "$ROOT/.env.example" "$ROOT/.env"
  echo "Created .env from .env.example"
  echo "Edit .env and add your API keys before starting Ada-SI."
fi

if [[ -f "$ROOT/.env" ]]; then
  set -a
  source "$ROOT/.env"
  set +a
fi

mkdir -p "$LOG_DIR" "$CUSTOM_TOOLS_DIR" "$ROOT/chat/staging"
ensure_venv "$APP_VENV" "$PY_BIN"
ensure_venv "$LITELLM_VENV" "$PY_BIN"

APP_PY="$APP_VENV/bin/python"
LITELLM_PY="$LITELLM_VENV/bin/python"
LITELLM_EXE="$LITELLM_VENV/bin/litellm"

"$APP_PY" -m pip install --upgrade pip >/dev/null
"$APP_PY" -m pip install -r "$ROOT/chat/requirements.txt" >/dev/null
"$APP_PY" -m pip install -r "$ROOT/tool_runtime/requirements.txt" >/dev/null

"$LITELLM_PY" -m pip install --upgrade pip >/dev/null
"$LITELLM_PY" -m pip install 'litellm[proxy]' >/dev/null

if [[ "$SKIP_BUILD" != true && "$DEV" != true && ! -f "$STATIC_INDEX" ]]; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "Node.js/npm not found. Install Node.js 22+ or rerun with --skip-build." >&2
    exit 1
  fi
  echo "Installing frontend dependencies..."
  (cd "$FRONTEND_DIR" && npm ci)
  echo "Building frontend..."
  (cd "$FRONTEND_DIR" && npm run build)
fi

if [[ "$INSTALL_ONLY" == true ]]; then
  echo "Install complete. Run ./start.sh to start services."
  exit 0
fi

rm -f "$PID_FILE"

export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8
export LITELLM_URL="http://127.0.0.1:4000"
export TOOL_RUNTIME_URL="http://127.0.0.1:8090"
export LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-sk-ada-dev-key}"
export LITE_MODEL="${LITE_MODEL:-}"
export TOOL_CREATOR_MODEL="${TOOL_CREATOR_MODEL:-}"
export CHAT_MODEL="${CHAT_MODEL:-}"
export SECOND_MODEL="${SECOND_MODEL:-}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-}"
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
export GEMINI_API_KEY="${GEMINI_API_KEY:-}"
export GROQ_API_KEY="${GROQ_API_KEY:-}"
export ELEVENLABS_API_KEY="${ELEVENLABS_API_KEY:-}"
export ADA_LOG_LEVEL="${ADA_LOG_LEVEL:-INFO}"
export ADA_LOG_MAX_BODY="${ADA_LOG_MAX_BODY:-32000}"
export LITE_MODEL_REASONING_EFFORT="${LITE_MODEL_REASONING_EFFORT:-low}"
export TOOLS_DIR="$CUSTOM_TOOLS_DIR"
export VENV_PATH="$TOOL_RUNTIME_VENV"

stop_services

echo "Starting LiteLLM on http://127.0.0.1:4000"
start_bg "litellm" "$LITELLM_EXE --config='$CONFIG_PATH' --port 4000"
if ! wait_http "http://127.0.0.1:4000/health/liveliness" 90; then
  echo "LiteLLM did not become ready. Check logs/litellm.log" >&2
  exit 1
fi

echo "Starting tool runtime on http://127.0.0.1:8090"
start_bg "tool-runtime" "cd '$ROOT/tool_runtime' && $APP_PY -m uvicorn server:app --host 127.0.0.1 --port 8090"
if ! wait_http "http://127.0.0.1:8090/health" 90; then
  echo "Tool runtime did not become ready. Check logs/tool-runtime.log" >&2
  exit 1
fi

echo "Starting chat server on http://127.0.0.1:8080"
start_bg "chat" "cd '$ROOT/chat' && $APP_PY -m uvicorn app:app --host 127.0.0.1 --port 8080"
if ! wait_http "http://127.0.0.1:8080/api/config" 90; then
  echo "Chat server did not become ready. Check logs/chat.log" >&2
  exit 1
fi

APP_URL="http://127.0.0.1:8080"
if [[ "$DEV" == true ]]; then
  if ! command -v npm >/dev/null 2>&1; then
    echo "Node.js/npm not found. Install Node.js 22+ or run without --dev." >&2
    exit 1
  fi
  echo "Starting Vite dev server on http://127.0.0.1:5173"
  start_bg "frontend" "cd '$FRONTEND_DIR' && npm run dev -- --host 127.0.0.1 --port 5173"
  if ! wait_http "http://127.0.0.1:5173/" 60; then
    echo "Vite dev server did not become ready. Check logs/frontend.log" >&2
    exit 1
  fi
  APP_URL="http://127.0.0.1:5173"
fi

echo ""
echo "Ada-SI is running."
echo "  App:          $APP_URL"
echo "  Chat API:     http://127.0.0.1:8080/api/config"
echo "  LiteLLM:      http://127.0.0.1:4000"
echo "  Tool runtime: http://127.0.0.1:8090"
echo "  Logs:         $LOG_DIR"
echo ""

if [[ "$NO_BROWSER" != true ]]; then
  if command -v open >/dev/null 2>&1; then
    open "$APP_URL" >/dev/null 2>&1 || true
  fi
fi

trap 'echo "Stopping Ada-SI..."; stop_services; exit 0' INT TERM
while true; do
  sleep 2
  if [[ ! -f "$PID_FILE" ]]; then
    break
  fi
  alive=false
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    if kill -0 "$pid" 2>/dev/null; then
      alive=true
      break
    fi
  done < "$PID_FILE"
  if [[ "$alive" != true ]]; then
    echo "All service processes exited. Check logs in $LOG_DIR"
    break
  fi
done

stop_services
