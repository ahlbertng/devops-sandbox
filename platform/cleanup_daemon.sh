#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVS_DIR="$ROOT_DIR/envs"
LOG_FILE="$ROOT_DIR/logs/cleanup.log"

mkdir -p "$(dirname "$LOG_FILE")"

echo "Cleanup daemon started"

while true; do
    NOW=$(date +%s)

    for FILE in "$ENVS_DIR"/*.json; do
        [[ -e "$FILE" ]] || continue

        ENV_ID=$(python3 -c "import json; print(json.load(open('$FILE'))['id'])")
        CREATED_AT=$(python3 -c "import json; print(json.load(open('$FILE'))['created_at'])")
        TTL=$(python3 -c "import json; print(json.load(open('$FILE'))['ttl'])")

        EXPIRES_AT=$((CREATED_AT + TTL))

        if [[ "$NOW" -gt "$EXPIRES_AT" ]]; then
            echo "$(date) Expired environment detected: $ENV_ID" | tee -a "$LOG_FILE"

            "$ROOT_DIR/platform/destroy_env.sh" "$ENV_ID" >> "$LOG_FILE" 2>&1 || true
        fi
    done

    sleep 60
done
