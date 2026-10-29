# Outillage d'équipe Shop SAS
SHELL := bash
DEV  := docker compose
PROD := docker compose -f compose.yml -f compose.prod.yml

.PHONY: help secrets up watch down logs ps tools prod-config prod-up prod-down migrate test clean

help: ## liste des commandes
	@grep -E '^[a-z-]+:.*## ' Makefile | awk -F':.*## ' '{printf "  make %-12s %s\n", $$1, $$2}'

secrets: ## crée secrets/db_password.txt s'il n'existe pas
	@mkdir -p secrets
	@test -s secrets/db_password.txt || docker run --rm alpine:3.20 sh -c 'head -c 24 /dev/urandom | od -An -tx1 | tr -d " \n"' > secrets/db_password.txt
	@test -f .env || cp .env.example .env

up: secrets ## stack de dev (compose.yml + compose.override.yml)
	$(DEV) up -d --build --wait
	$(DEV) ps

watch: ## rechargement du code de l'API (compose watch)
	$(DEV) watch

down: ## arrête la stack de dev (garde les volumes)
	$(DEV) down

logs: ## logs de la stack de dev
	$(DEV) logs -f --tail=50

ps: ## état des services
	$(DEV) ps

tools: ## lance adminer sur adminer.localhost
	$(DEV) --profile tools up -d --wait adminer

prod-config: ## fichier résolu de la prod
	$(PROD) config

prod-up: secrets ## stack de prod (images du registre, 2 réplicas d'API)
	$(PROD) up -d --wait
	$(PROD) ps

prod-down: ## arrête la stack de prod (garde les volumes)
	$(PROD) down

migrate: ## applique une migration : make migrate M=002-add-sku.sql
	@test -n "$(M)" || { echo "usage: make migrate M=002-add-sku.sql"; exit 1; }
	MIGRATION=$(M) $(DEV) --profile ops run --rm migrate

test: ## smoke test sur la stack démarrée
	bash smoke-test.sh

clean: ## supprime la stack ET les volumes (données perdues)
	$(DEV) --profile tools --profile ops down -v --remove-orphans
