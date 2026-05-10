up:
	docker-compose up -d

down:
	docker-compose down --remove-orphans

build:
	docker build -t sandbox-demo-app:latest demo-app

create:
	./platform/create_env.sh demo 1800

destroy:
	./platform/destroy_env.sh $(ENV)

cleanup-daemon:
	nohup ./platform/cleanup_daemon.sh > logs/daemon.out 2>&1 &

monitor:
	nohup python3 monitor/poller.py > logs/monitor.out 2>&1 &

outage:
	./platform/simulate_outage.sh --env $(ENV) --mode $(MODE)

logs:
	cat logs/env-$(ENV)/health.log

status:
	docker ps
