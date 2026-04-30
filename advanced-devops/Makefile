SHELL := /bin/bash

.PHONY: init up down restart logs validate bootstrap

init:
	@if [ ! -f .env ]; then cp .env.example .env; fi

up: init
	docker compose up -d --build

bootstrap: up
	./scripts/bootstrap.sh

down:
	docker compose down

restart: down up

logs:
	docker compose logs -f --tail=200

validate:
	bash -n deploy-oneclick.sh
	bash -n scripts/bootstrap.sh
	docker compose config > /dev/null
