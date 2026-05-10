from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pathlib import Path
import subprocess
import json
import time

app = FastAPI(title="DevOps Sandbox Platform")

ROOT_DIR = Path("/app")
ENVS_DIR = ROOT_DIR / "envs"
LOGS_DIR = ROOT_DIR / "logs"


class CreateEnvRequest(BaseModel):
    name: str = "demo"
    ttl: int = 1800


class OutageRequest(BaseModel):
    mode: str


def run_script(script, *args):
    result = subprocess.run(
        [str(ROOT_DIR / "platform" / script), *args],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        raise HTTPException(
            status_code=500,
            detail=result.stderr or result.stdout
        )

    return result.stdout


@app.get("/")
def root():
    return {"message": "Sandbox API running"}


@app.post("/envs")
def create_env(payload: CreateEnvRequest):
    output = run_script(
        "create_env.sh",
        payload.name,
        str(payload.ttl)
    )

    return {
        "message": "environment created",
        "output": output
    }


@app.get("/envs")
def list_envs():
    envs = []
    now = int(time.time())

    for file in ENVS_DIR.glob("*.json"):
        data = json.loads(file.read_text())

        expires = data["created_at"] + data["ttl"]

        data["ttl_remaining"] = max(0, expires - now)

        envs.append(data)

    return {"envs": envs}


@app.delete("/envs/{env_id}")
def destroy_env(env_id: str):
    output = run_script("destroy_env.sh", env_id)

    return {
        "message": "environment destroyed",
        "output": output
    }


@app.get("/envs/{env_id}/logs")
def get_logs(env_id: str):
    log_file = LOGS_DIR / env_id / "app.log"
    if not log_file.exists():
        raise HTTPException(status_code=404, detail="logs not found")
    lines = log_file.read_text().splitlines()
    return {"env_id": env_id, "logs": lines[-100:]}


@app.post("/envs/{env_id}/outage")
def outage(env_id: str, payload: OutageRequest):
    output = run_script(
        "simulate_outage.sh",
        "--env",
        env_id,
        "--mode",
        payload.mode
    )

    return {
        "message": "outage simulated",
        "output": output
    }

@app.get("/envs/{env_id}/health")
def get_health(env_id: str):
    state_file = ENVS_DIR / f"{env_id}.json"
    if not state_file.exists():
        raise HTTPException(status_code=404, detail="not found")
    state = json.loads(state_file.read_text())
    health_log = LOGS_DIR / env_id / "health.log"
    if not health_log.exists():
        return {"env_id": env_id, "status": state.get("status"), "results": []}
    lines = health_log.read_text().strip().splitlines()
    return {"env_id": env_id, "status": state.get("status"), "results": lines[-10:]}