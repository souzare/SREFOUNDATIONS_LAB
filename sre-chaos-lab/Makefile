.PHONY: help lab1-up lab1-up-gremlin lab1-down lab1-aws-up lab1-aws-dashboard lab1-aws-destroy lab2-deploy lab2-load lab2-fault-config lab2-fault-iam lab2-restore lab2-destroy

L1=lab1-gremlin-blast-radius
L2=lab2-cloudwatch-investigations

help:
	@echo "Lab 1 (local):  make lab1-up | lab1-up-gremlin | lab1-down"
	@echo "Lab 1 (AWS):    make lab1-aws-up | lab1-aws-dashboard | lab1-aws-destroy"
	@echo "                (exporte GREMLIN_TEAM_ID, GREMLIN_TEAM_SECRET e REPO_URL antes)"
	@echo "Lab 2:          make lab2-deploy | lab2-load | lab2-fault-config | lab2-fault-iam | lab2-restore | lab2-destroy"

lab1-up:
	cd $(L1) && docker compose up -d --build

lab1-up-gremlin:
	cd $(L1) && docker compose --env-file .env -f docker-compose.yml -f docker-compose.gremlin.yml up -d --build

lab1-down:
	cd $(L1) && docker compose -f docker-compose.yml -f docker-compose.gremlin.yml down

lab1-aws-up:
	cd $(L1) && ./scripts/deploy.sh

lab1-aws-dashboard:
	cd $(L1) && ./scripts/port-forward.sh 8081

lab1-aws-destroy:
	cd $(L1) && ./scripts/destroy.sh

lab2-deploy:
	cd $(L2) && ./scripts/deploy.sh

lab2-load:
	cd $(L2) && ./scripts/load.sh 120

lab2-fault-config:
	cd $(L2) && ./scripts/inject-fault.sh bad-config

lab2-fault-iam:
	cd $(L2) && ./scripts/inject-fault.sh iam-deny

lab2-restore:
	cd $(L2) && ./scripts/restore.sh

lab2-destroy:
	cd $(L2) && ./scripts/destroy.sh
