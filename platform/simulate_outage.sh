#!/usr/bin/env bash
set -euo pipefail

ENV_ID=""
MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_ID="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$ENV_ID" || -z "$MODE" ]]; then
  echo "Usage: $0 --env ENV_ID --mode crash|pause|network|recover"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="$ROOT_DIR/envs/$ENV_ID.json"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "State file not found for $ENV_ID"
  exit 1
fi

CONTAINER_NAME="$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['container'])")"
NETWORK_NAME="$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['network'])")"

if [[ "$CONTAINER_NAME" == *nginx* || "$CONTAINER_NAME" == *daemon* ]]; then
  echo "Refusing to run outage simulation against protected container: $CONTAINER_NAME"
  exit 1
fi

case "$MODE" in
  crash)
    docker kill "$CONTAINER_NAME"
    echo "Crashed $CONTAINER_NAME"
    ;;
  pause)
    docker pause "$CONTAINER_NAME"
    echo "Paused $CONTAINER_NAME"
    ;;
  network)
    docker network disconnect "$NETWORK_NAME" "$CONTAINER_NAME"
    echo "Disconnected $CONTAINER_NAME from $NETWORK_NAME"
    ;;
  recover)
    docker start "$CONTAINER_NAME" 2>/dev/null || true
    docker unpause "$CONTAINER_NAME" 2>/dev/null || true
    docker network connect "$NETWORK_NAME" "$CONTAINER_NAME" 2>/dev/null || true
    echo "Recovered $CONTAINER_NAME"
    ;;
  *)
    echo "Invalid mode: $MODE"
    exit 1
    ;;
esac
