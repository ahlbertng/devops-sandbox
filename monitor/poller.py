import json
import time
from pathlib import Path
from urllib.request import urlopen
from urllib.error import URLError

ROOT_DIR = Path(__file__).resolve().parent.parent
ENVS_DIR = ROOT_DIR / "envs"
LOGS_DIR = ROOT_DIR / "logs"

CHECK_INTERVAL = 30
FAILURE_THRESHOLD = 3
failure_counts = {}

print("Health monitor started")

while True:
    for state_file in ENVS_DIR.glob("*.json"):
        try:
            data = json.loads(state_file.read_text())

            env_id = data["id"]
            url = f"http://localhost/{env_id}/health"

            health_log = LOGS_DIR / env_id / "health.log"
            health_log.parent.mkdir(parents=True, exist_ok=True)

            timestamp = time.strftime("%Y-%m-%d %H:%M:%S")

            try:
                response = urlopen(url, timeout=5)
                status = response.status
                failure_counts[env_id] = 0

                line = f"[{timestamp}] HEALTHY status={status}"

            except URLError as e:
                failure_counts[env_id] = failure_counts.get(env_id, 0) + 1
                consecutive = failure_counts[env_id]
                line = f"[{timestamp}] UNHEALTHY error={str(e)} consecutive={consecutive}"
                print(f"⚠ FAIL {env_id} — {consecutive} consecutive failures", flush=True)

                if consecutive >= FAILURE_THRESHOLD and data.get("status") != "degraded":
                    print(f"⚠ DEGRADED {env_id} — marking degraded!", flush=True)
                    data["status"] = "degraded"
                    tmp = state_file.with_suffix(".tmp")
                    tmp.write_text(json.dumps(data, indent=2))
                    tmp.rename(state_file)

            with open(health_log, "a") as f:
                f.write(line + "\n")

        except Exception as e:
            print(f"Monitor error: {e}")

    time.sleep(CHECK_INTERVAL)
