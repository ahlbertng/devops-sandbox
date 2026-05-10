import json
import time
from pathlib import Path
from urllib.request import urlopen
from urllib.error import URLError

ROOT_DIR = Path(__file__).resolve().parent.parent
ENVS_DIR = ROOT_DIR / "envs"
LOGS_DIR = ROOT_DIR / "logs"

CHECK_INTERVAL = 30

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

                line = f"[{timestamp}] HEALTHY status={status}"

            except URLError as e:
                line = f"[{timestamp}] UNHEALTHY error={str(e)}"

            with open(health_log, "a") as f:
                f.write(line + "\n")

        except Exception as e:
            print(f"Monitor error: {e}")

    time.sleep(CHECK_INTERVAL)
