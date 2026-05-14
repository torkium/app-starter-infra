# Runbooks operations

## Checks rapides

```bash
make ps
make health
make stack-assert
```

## Backup local

```bash
make backup
```

## Backup offsite

```bash
RESTIC_REPOSITORY=b2:app-starter-backups:mysql \
RESTIC_PASSWORD='replace-me' \
make backup-offsite
```

## Restore rapide

```bash
make restore FILE=/absolute/path/to/mysql-YYYYMMDDTHHMMSSZ.sql.gz
```

## Incident app

1. verifier les containers : `make ps`
2. verifier les logs : `make logs`
3. verifier la sante HTTP : `make health`
4. rollback si necessaire via le workflow GitHub ou `make rollback`

## Incident workers / scheduler

```bash
docker compose ps worker_default worker_mail worker_outbox scheduler
docker compose logs --tail=100 worker_default worker_mail worker_outbox scheduler
./scripts/check-background-services.sh
```

## Incident observabilite

```bash
docker compose --profile observability ps
docker compose --profile observability logs --tail=100 grafana prometheus loki alloy cadvisor
docker compose --profile observability exec -T nginx nginx -t
```

## PRA complet

1. Reinstaller le serveur avec [server-installation.md](./server-installation.md).
2. Rejouer le bootstrap de configuration.
3. Restaurer le dernier backup de base.
4. Valider le trafic HTTP et les services de fond.
