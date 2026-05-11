# Operations

## Local

```bash
cp .env.example .env
cp env/.env.dev.example env/.env.dev
./scripts/generate-dev-certs.sh app.localhost
./scripts/render-grafana-htpasswd.sh
make up
```

## Commandes utiles

```bash
make init
make logs
make ps
make health
make stack-assert
make migrate
make backup
make backup-offsite
make restore FILE=/absolute/path/to/backup.sql.gz
make observability-up
```

## Notes

- `make up` utilise `docker-compose.yml` et `docker-compose.dev.yml`.
- Pour simuler un environnement image-only, definir `COMPOSE_FILES='-f docker-compose.yml'`.
- Les variables supplementaires propres a `starter_back` ou `starter_front` doivent etre ajoutees dans `env/.env.<env>`.
- Le profil `observability` est optionnel. Sans `make observability-up`, `/grafana/` ne servira rien.
- `make init` prepare les fichiers de base et les certificats locaux.
- `make stack-assert` rejoue les checks runtime utilises par la gate CI d'integration.
- Voir aussi [backup-pra.md](./backup-pra.md) et [runbooks-ops.md](./runbooks-ops.md).
