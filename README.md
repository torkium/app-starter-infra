# starter_infra

Production-minded infrastructure starter for orchestrating a `starter_back` Symfony application and a `starter_front` Next.js application with Docker Compose, CI/CD, observability, and operational tooling.

This repo is the infrastructure and deployment layer of the starter trio:
- `starter_back`: the backend application starter
- `starter_front`: the frontend application starter

It is optional if you want to reuse only the backend or only the frontend with your own infrastructure.

## Purpose

Use `starter_infra` when you want the operational layer already in place:

- local full-stack orchestration
- reverse proxy and TLS for local environments
- workers and scheduler runtime wiring
- Mercure integration
- CI/CD workflows
- deploy and rollback automation
- observability foundations
- backup and restore scripts

The repo is intentionally generic and contains no project-specific hostnames, secrets, registries, or business assumptions.

## What Is Included

- Docker Compose stack for backend, frontend, MySQL, Redis, Mercure, Mailpit, Nginx, workers, and scheduler
- local development override using sibling repos `../starter_back` and `../starter_front`
- optional observability stack with Grafana, Prometheus, Loki, Alloy, and cAdvisor
- runtime environment templates
- local TLS certificate tooling
- GitHub Environment bootstrap scripts
- GitHub Actions workflows for CI, deploy, rollback, and multi-repo orchestration
- release state persistence outside the GitHub Actions workspace
- backup, restore, offsite backup, and rollback scripts
- edge media worker template for private bucket delivery

## Prerequisites

- Docker Engine with Docker Compose support
- GNU Make
- OpenSSL for local certificate and htpasswd generation during `make init`
- Optional: `restic` if you want to use the offsite backup flow locally

## Related Starters

- `starter_back`
  The expected backend image. It must expose an HTTP app and support Symfony CLI commands for migrations, workers, and scheduler.

- `starter_front`
  The expected frontend image. It must expose a Next.js runtime and support the runtime environment contract documented by this repo.

Typical combinations:
- `starter_back` alone: no need for this repo if you already have your own infra
- `starter_front` alone: no need for this repo if you already have your own infra
- full trio: `starter_back` + `starter_front` + `starter_infra`

## Quick Start

```bash
make init
make stack-up
```

Project bootstrap from the full trio:

```bash
./scripts/bootstrap-project.sh \
  --project-name my-app \
  --github-owner my-org \
  --back-repo my-app-back \
  --front-repo my-app-front \
  --infra-repo my-app-infra
```

This orchestrator:
- applies the known project-safe renames in the three repos
- generates the ignored local files if missing
- checks local prerequisites before bootstrapping
- optionally rewires Git remotes with `--configure-git-remotes`

Useful commands:

```bash
make ps
make config
make stack-restart
make health
make logs
make migrate
make stack-assert
```

`make health` runs the same global HTTP healthcheck logic used by the workflows:
- backend health endpoint
- frontend root page
- retries before failure

Default local entrypoints:
- App: `https://app.local`
- Mercure: `https://app.local/.well-known/mercure`
- Mailpit UI: `http://localhost:8025`
- Mailpit SMTP: `localhost:1025`
- Grafana: `https://app.local/grafana/` when observability is enabled

## Default Runtime Versions

- MySQL: `8.4.9`
- Redis: `8.6.3-alpine`
- Nginx: `1.30.0-alpine`
- Mercure: `v0.23.5`
- Grafana: `13.0.1`
- Prometheus: `v3.11.3`
- Loki: `3.7.1`
- Alloy: `v1.16.1`
- cAdvisor: `v0.55.1`

## Application Assumptions

Backend image:
- exposes HTTP on `BACK_HTTP_PORT`
- responds on `BACK_HEALTH_PATH`
- supports Symfony CLI commands for migrations, workers, and scheduler

Frontend image:
- exposes Next.js on `FRONT_HTTP_PORT`
- supports the runtime public environment contract used by the frontend starter

If your applications require extra runtime variables, add them to `env/.env.<env>`.

## Observability

Enable locally with:

```bash
make observability-up
```

The observability stack adds:
- Grafana behind Nginx on `/grafana/`
- Prometheus for metrics
- Loki for logs
- Alloy for Docker log collection
- cAdvisor for container metrics

More details:
- [docs/observability.md](./docs/observability.md)

## GitHub Bootstrap

This repo provides bootstrap helpers for GitHub Environment variables and secrets:

```bash
cp bootstrap/github/environment.env.example bootstrap/github/dev.env
./scripts/bootstrap-github-environment.sh --envs=dev --env-file=bootstrap/github/dev.env --repo=my-org/my-app-infra --mask
```

See:
- [docs/github-variables-secrets.md](./docs/github-variables-secrets.md)

## Deployment, Backup, and Ops

Deployment:
- [docs/deployment.md](./docs/deployment.md)

Backup and recovery:
- [docs/backup-pra.md](./docs/backup-pra.md)
- [docs/runbooks-ops.md](./docs/runbooks-ops.md)

Server bootstrap:
- [docs/server-installation.md](./docs/server-installation.md)
- [docs/prod-bootstrap.md](./docs/prod-bootstrap.md)
- [docs/quick-start.md](./docs/quick-start.md)

Useful operational commands:

```bash
make backup
make backup-offsite
make restore FILE=/absolute/path/to/backup.sql.gz
make rollback TARGET=back VERSION=staging
```

## Suggested Workflow With The Other Starters

If you use the full trio:

1. Initialize `starter_back`
2. Initialize `starter_front`
3. Initialize `starter_infra`
4. Start the integrated stack from `starter_infra`
5. Let `make up` run the first migrations, or use `make migrate` after manual restarts
6. Validate the stack with `make stack-assert`

`starter_infra` is the repo that ties the other two together for local full-stack work and deployment automation.
