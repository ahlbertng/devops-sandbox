# DevOps Sandbox Platform

A lightweight self-service DevOps sandbox platform for creating short-lived isolated environments on a single Linux VM.

Users can create temporary app environments, route traffic through Nginx, monitor health, simulate outages, inspect logs, and destroy environments manually or automatically after TTL expiry.

---

## Architecture

```text
                    ┌──────────────────────┐
                    │      User / API       │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │   FastAPI Control    │
                    │        API           │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │   Bash Lifecycle     │
                    │ create/destroy/etc.  │
                    └──────────┬───────────┘
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
 ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
 │ env-abc123 app  │  │ env-def456 app  │  │ env-xyz789 app  │
 │ Docker network  │  │ Docker network  │  │ Docker network  │
 └────────┬────────┘  └────────┬────────┘  └────────┬────────┘
          │                    │                    │
          └────────────────────┼────────────────────┘
                               ▼
                    ┌──────────────────────┐
                    │      Nginx Proxy     │
                    │  Dynamic routes      │
                    └──────────────────────┘

Other background components:
- cleanup_daemon.sh destroys expired environments.
- monitor/poller.py checks /health every 30 seconds.
- simulate_outage.sh supports crash, pause, network, and recover modes.
````

---

## Stack

* Docker
* Docker Compose
* Nginx
* Bash
* Python 3
* FastAPI
* Flask demo app

---

## Repository Structure

```text
devops-sandbox/
├── platform/
│   ├── create_env.sh
│   ├── destroy_env.sh
│   ├── cleanup_daemon.sh
│   ├── simulate_outage.sh
│   └── api.py
├── nginx/
│   ├── nginx.conf
│   └── conf.d/
├── monitor/
│   └── poller.py
├── demo-app/
│   ├── app.py
│   └── Dockerfile
├── envs/
├── logs/
├── docker-compose.yml
├── Makefile
└── README.md
```

---

## Prerequisites

Install:

* Docker
* Docker Compose
* Make
* Python 3

The project runs on a single Linux VM.

---

## Quick Start

From zero to first running environment:

```bash
make build
make up
make cleanup-daemon
make monitor
make create
```

The `make create` command prints an environment URL like:

```text
http://localhost/env-abc123/
```

Test it:

```bash
curl http://localhost/env-abc123/
curl http://localhost/env-abc123/health
```

---

## API Usage

Start platform:

```bash
make up
```

Create environment:

```bash
curl -X POST http://localhost:8000/envs \
  -H "Content-Type: application/json" \
  -d '{"name":"api-test","ttl":300}'
```

List environments:

```bash
curl http://localhost:8000/envs
```

Destroy environment:

```bash
curl -X DELETE http://localhost:8000/envs/env-abc123
```

Read environment logs:

```bash
curl http://localhost:8000/envs/env-abc123/logs
```

Trigger outage:

```bash
curl -X POST http://localhost:8000/envs/env-abc123/outage \
  -H "Content-Type: application/json" \
  -d '{"mode":"pause"}'
```

Recover:

```bash
curl -X POST http://localhost:8000/envs/env-abc123/outage \
  -H "Content-Type: application/json" \
  -d '{"mode":"recover"}'
```

---

## Makefile Commands

```bash
make up
make down
make build
make create
make destroy ENV=env-abc123
make cleanup-daemon
make monitor
make outage ENV=env-abc123 MODE=pause
make logs ENV=env-abc123
make api-create
make api-list
make status
```

---

## Demo Walkthrough

### Start platform

```bash
make build
make up
```

### Start background services

```bash
make cleanup-daemon
make monitor
```

### Create environment

```bash
make create
```

Example output:

```text
Environment created successfully
ENV_ID=env-abc123
URL=http://localhost/env-abc123/
TTL=1800s
```

### Test environment

```bash
curl http://localhost/env-abc123/
curl http://localhost/env-abc123/health
```

### Observe health logs

```bash
cat logs/env-abc123/health.log
```

### Simulate outage

```bash
make outage ENV=env-abc123 MODE=pause
```

The health endpoint may hang or return:

```text
504 Gateway Time-out
```

### Recover

```bash
make outage ENV=env-abc123 MODE=recover
```

Then verify:

```bash
curl http://localhost/env-abc123/health
```

### Destroy

```bash
make destroy ENV=env-abc123
```

---

## Environment Lifecycle

Each environment gets:

* unique env ID
* isolated Docker network
* app container labeled with `sandbox.env=$ENV_ID`
* Nginx route file
* JSON state file in `envs/`
* app logs in `logs/$ENV_ID/app.log`
* archived logs after destroy

---

## Log Shipping Approach

This project uses the simple log shipping approach.

On environment creation:

```bash
docker logs -f $CONTAINER_NAME >> logs/$ENV_ID/app.log &
```

The logger PID is stored in the environment state file.

On destroy:

* logger process is killed
* logs are archived to `logs/archived/$ENV_ID/`
* runtime log directory is removed

---

## Health Monitoring

The monitor checks every active environment every 30 seconds:

```bash
python3 monitor/poller.py
```

It calls:

```text
http://localhost/$ENV_ID/health
```

and writes results to:

```text
logs/$ENV_ID/health.log
```

---

## Outage Simulation

Supported modes:

```bash
crash
pause
network
recover
```

Examples:

```bash
make outage ENV=env-abc123 MODE=crash
make outage ENV=env-abc123 MODE=pause
make outage ENV=env-abc123 MODE=network
make outage ENV=env-abc123 MODE=recover
```

The script has a guard to avoid running simulations against protected containers like Nginx or daemon containers.

---

## Cleanup Daemon

Run with:

```bash
make cleanup-daemon
```

The daemon checks `envs/*.json` every 60 seconds.

If:

```text
now > created_at + ttl
```

it calls:

```bash
platform/destroy_env.sh ENV_ID
```

Actions are logged to:

```text
logs/cleanup.log
```

---

## Known Limitations

* Uses Docker Compose v1 on some systems, which may require removing stale containers manually if `ContainerConfig` errors occur.
* Demo app is a simple Flask app.
* No authentication on the API.
* No persistent database; state is stored as JSON files.
* Nginx routes are path-based, not subdomain-based.
* Prometheus and Grafana are not included.
