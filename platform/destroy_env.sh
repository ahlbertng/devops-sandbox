#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 ENV_ID"
  exit 1
fi

ENV_ID="$1"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVS_DIR="$ROOT_DIR/envs"
LOGS_DIR="$ROOT_DIR/logs"
NGINX_CONF_DIR="$ROOT_DIR/nginx/conf.d"
STATE_FILE="$ENVS_DIR/$ENV_ID.json"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "State file not found for $ENV_ID"
  exit 1
fi

CONTAINER_NAME="$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['container'])")"
NETWORK_NAME="$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['network'])")"
LOGGER_PID="$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('logger_pid', ''))")"

echo "Destroying $ENV_ID"

if [[ -n "$LOGGER_PID" ]]; then
  kill "$LOGGER_PID" 2>/dev/null || true
fi

mkdir -p "$LOGS_DIR/archived/$ENV_ID"

if [[ -d "$LOGS_DIR/$ENV_ID" ]]; then
  cp -a "$LOGS_DIR/$ENV_ID/." "$LOGS_DIR/archived/$ENV_ID/" 2>/dev/null || true
  rm -rf "$LOGS_DIR/$ENV_ID"
fi

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker network disconnect "$NETWORK_NAME" sandbox-nginx 2>/dev/null || true
docker network rm "$NETWORK_NAME" >/dev/null 2>&1 || true

rm -f "$NGINX_CONF_DIR/$ENV_ID.conf"

docker exec sandbox-nginx nginx -t >/dev/null
docker exec sandbox-nginx nginx -s reload

rm -f "$STATE_FILE"

echo "Environment $ENV_ID destroyed successfully"
