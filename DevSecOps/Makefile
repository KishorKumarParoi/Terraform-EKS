SHELL := /bin/bash

.PHONY: init up down validate logs

init:
	@if [ ! -f .env ]; then cp .env.example .env; fi

up: init
	./deploy-oneclick.sh

down:
	docker compose down

logs:
	docker compose logs -f --tail=200

validate:
	bash -n deploy-oneclick.sh
	docker compose config > /dev/null
