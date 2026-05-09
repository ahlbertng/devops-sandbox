#!/usr/bin/env bash
set -euo pipefail

NAME="${1:-demo}"
TTL="${2:-1800}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVS_DIR="$ROOT_DIR/envs"
LOGS_DIR="$ROOT_DIR/logs"
NGINX_CONF_DIR="$ROOT_DIR/nginx/conf.d"

ENV_ID="env-$(openssl rand -hex 3)"
CONTAINER_NAME="sandbox-$ENV_ID"
NETWORK_NAME="net-$ENV_ID"

mkdir -p "$ENVS_DIR" "$LOGS_DIR/$ENV_ID" "$NGINX_CONF_DIR"

docker network create "$NETWORK_NAME" >/dev/null

docker run -d \
  --name "$CONTAINER_NAME" \
  --network "$NETWORK_NAME" \
  --label "sandbox.env=$ENV_ID" \
  --label "sandbox.role=app" \
  -e "ENV_ID=$ENV_ID" \
  sandbox-demo-app:latest >/dev/null

docker network connect "$NETWORK_NAME" sandbox-nginx 2>/dev/null || true

cat > "$NGINX_CONF_DIR/$ENV_ID.conf" <<NGINX
location /$ENV_ID/ {
    proxy_pass http://$CONTAINER_NAME:5000/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
}
NGINX

docker exec sandbox-nginx nginx -t >/dev/null
docker exec sandbox-nginx nginx -s reload

docker logs -f "$CONTAINER_NAME" >> "$LOGS_DIR/$ENV_ID/app.log" 2>&1 &
LOGGER_PID=$!

CREATED_AT="$(date +%s)"
TMP_FILE="$ENVS_DIR/$ENV_ID.json.tmp"
STATE_FILE="$ENVS_DIR/$ENV_ID.json"

cat > "$TMP_FILE" <<JSON
{
  "id": "$ENV_ID",
  "name": "$NAME",
  "container": "$CONTAINER_NAME",
  "network": "$NETWORK_NAME",
  "created_at": $CREATED_AT,
  "ttl": $TTL,
  "status": "healthy",
  "logger_pid": $LOGGER_PID
}
JSON

mv "$TMP_FILE" "$STATE_FILE"

echo "Environment created successfully"
echo "ENV_ID=$ENV_ID"
echo "URL=http://localhost/$ENV_ID/"
echo "TTL=${TTL}s"
