COMPOSE_FILES ?= -f docker-compose.yml
DEV_COMPOSE_FILES ?= $(COMPOSE_FILES) -f docker-compose.dev.yml
COMPOSE = docker compose $(COMPOSE_FILES)
DEV_COMPOSE = docker compose $(DEV_COMPOSE_FILES)
DEPLOY_ENV ?= dev
BACKUP_DIR ?= backups
OBSERVABILITY_PROFILE ?= --profile observability
MIGRATION_COMMAND ?= php bin/console doctrine:migrations:migrate --no-interaction
CORE_SERVICES ?= db redis mercure back front nginx
DEV_CORE_SERVICES ?= mailpit
POST_MIGRATION_SERVICES ?= worker_default worker_mail worker_outbox scheduler
AUTO_DOCKER_CLEANUP ?= 1
DOCKER_CLEANUP_MODE ?= dev

up:
	$(COMPOSE) up -d --build $(CORE_SERVICES) $(if $(filter dev,$(DEPLOY_ENV)),$(DEV_CORE_SERVICES))
	$(COMPOSE) run --rm back sh -lc '$(MIGRATION_COMMAND)'
	$(COMPOSE) up -d --build $(POST_MIGRATION_SERVICES)

stack-up: up

dev-up:
	$(DEV_COMPOSE) up -d --build --renew-anon-volumes $(CORE_SERVICES) $(DEV_CORE_SERVICES)
	$(DEV_COMPOSE) run --rm back sh -lc '$(MIGRATION_COMMAND)'
	$(DEV_COMPOSE) up -d --build $(POST_MIGRATION_SERVICES)
	@if [ "$(AUTO_DOCKER_CLEANUP)" = "1" ]; then ./scripts/docker-cleanup.sh $(DOCKER_CLEANUP_MODE); fi

stack-dev: dev-up

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
	$(COMPOSE) up -d --force-recreate $(CORE_SERVICES) $(if $(filter dev,$(DEPLOY_ENV)),$(DEV_CORE_SERVICES))
	$(COMPOSE) up -d --force-recreate $(POST_MIGRATION_SERVICES)

stack-restart: restart

logs:
	$(COMPOSE) logs -f

front-dev:
	$(DEV_COMPOSE) up -d --build --force-recreate --renew-anon-volumes --no-deps front nginx

front-logs:
	$(DEV_COMPOSE) logs -f front

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

docker-clean:
	./scripts/docker-cleanup.sh dev

docker-clean-safe:
	./scripts/docker-cleanup.sh safe

docker-clean-hard:
	./scripts/docker-cleanup.sh hard

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

.PHONY: init up stack-up dev-up stack-dev down stack-down build pull restart stack-restart logs front-dev front-logs ps config migrate health backup backup-offsite restore rollback docker-clean docker-clean-safe docker-clean-hard certs observability-up observability-down observability-targets observability-alerts observability-logs stack-assert
