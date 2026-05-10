up:
	docker-compose up -d

down:
	docker-compose down --remove-orphans

build:
	docker build -t sandbox-demo-app:latest demo-app

rebuild-api:
	docker rm -f sandbox-api || true
	docker-compose up -d --build api

status:
	docker ps

create:
	@read -p "Environment name: " name; \
	read -p "TTL in seconds [1800]: " ttl; \
	ttl=$${ttl:-1800}; \
	bash platform/create_env.sh "$$name" "$$ttl"

destroy:
	./platform/destroy_env.sh $(ENV)

cleanup-daemon:
	nohup ./platform/cleanup_daemon.sh > logs/daemon.out 2>&1 &

monitor:
	nohup python3 monitor/poller.py > logs/monitor.out 2>&1 &

outage:
	./platform/simulate_outage.sh --env $(ENV) --mode $(MODE)

logs:
	@[ -n "$(ENV)" ] || { echo "Usage: make logs ENV=<env-id>"; exit 1; }
	tail -f logs/$(ENV)/app.log

health:
	@for f in envs/*.json; do \
	  [ -f "$$f" ] || continue; \
	  ID=$$(python3 -c "import json; print(json.load(open('$$f'))['id'])"); \
	  STATUS=$$(python3 -c "import json; print(json.load(open('$$f')).get('status','?'))"); \
	  echo "$$ID [$$STATUS]"; \
	  HLOG="logs/$$ID/health.log"; \
	  [ -f "$$HLOG" ] && tail -n 5 "$$HLOG" | sed 's/^/  /' || echo "  (no data yet)"; \
	done

api-create:
	curl -X POST http://localhost:8000/envs \
	-H "Content-Type: application/json" \
	-d '{"name":"api-env","ttl":300}'

api-list:
	curl http://localhost:8000/envs
