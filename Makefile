COMPOSE_FILES ?= -f docker-compose.yml -f docker-compose.dev.yml
COMPOSE = docker compose $(COMPOSE_FILES)
DEPLOY_ENV ?= dev
BACKUP_DIR ?= backups
OBSERVABILITY_PROFILE ?= --profile observability
MIGRATION_COMMAND ?= php bin/console doctrine:migrations:migrate --no-interaction
CORE_SERVICES ?= db redis mercure mailpit back front nginx
POST_MIGRATION_SERVICES ?= worker_default worker_mail worker_outbox scheduler

up:
	$(COMPOSE) up -d --build $(CORE_SERVICES)
	$(COMPOSE) run --rm back sh -lc '$(MIGRATION_COMMAND)'
	$(COMPOSE) up -d --build $(POST_MIGRATION_SERVICES)

stack-up: up

init:
	./scripts/init.sh $(APP_DOMAIN)

down:
	$(COMPOSE) down

stack-down: down

build:
	$(COMPOSE) build

pull:
	$(COMPOSE) pull --ignore-buildable

restart:
	$(COMPOSE) up -d --force-recreate $(CORE_SERVICES)
	$(COMPOSE) up -d --force-recreate $(POST_MIGRATION_SERVICES)

stack-restart: restart

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

config:
	$(COMPOSE) config

migrate:
	$(COMPOSE) run --rm back sh -lc '$(MIGRATION_COMMAND)'

health:
	./scripts/healthcheck.sh

backup:
	./scripts/backup.sh

backup-offsite:
	./scripts/backup-offsite.sh

restore:
	@if [ -z "$(FILE)" ]; then echo "Set FILE=/absolute/path/to/backup.sql.gz"; exit 1; fi
	./scripts/restore.sh "$(FILE)"

rollback:
	./scripts/rollback.sh $(TARGET) $(VERSION)

certs:
	./scripts/generate-dev-certs.sh $(APP_DOMAIN)

observability-up:
	$(COMPOSE) $(OBSERVABILITY_PROFILE) up -d grafana prometheus loki alloy cadvisor

observability-down:
	$(COMPOSE) $(OBSERVABILITY_PROFILE) stop grafana prometheus loki alloy cadvisor

observability-targets:
	$(COMPOSE) $(OBSERVABILITY_PROFILE) exec -T nginx wget -qO- http://prometheus:9090/api/v1/targets

observability-alerts:
	$(COMPOSE) $(OBSERVABILITY_PROFILE) exec -T nginx wget -qO- http://prometheus:9090/api/v1/rules

observability-logs:
	$(COMPOSE) $(OBSERVABILITY_PROFILE) exec -T nginx wget -qO- http://loki:3100/loki/api/v1/labels

stack-assert:
	COMPOSE_FILES="$(COMPOSE_FILES)" ./scripts/assert-stack-runtime.sh

.PHONY: init up stack-up down stack-down build pull restart stack-restart logs ps config migrate health backup backup-offsite restore rollback certs observability-up observability-down observability-targets observability-alerts observability-logs stack-assert
