# Operations

## Local

```bash
cp .env.example .env
cp env/.env.dev.example env/.env.dev
./scripts/generate-dev-certs.sh app.local
./scripts/render-grafana-htpasswd.sh
make up
make front-dev
```

Pour tester les fonctionnalités PWA en local sur un domaine custom, installez `mkcert` avant de générer les certificats. Un certificat OpenSSL auto-signé permet de charger la page après exception navigateur, mais les service workers exigent un certificat approuvé.
Ne copiez jamais `rootCA-key.pem` dans `certs/dev`: seule la CA publique `rootCA.pem` peut être partagée avec une machine cliente pour faire confiance au certificat local.

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

- `make up` utilise `docker-compose.yml` et garde le front en mode image-only.
- `make front-dev` ajoute `docker-compose.dev.yml` pour lancer le serveur Next.js en hot reload derriere Nginx.
- `make up` lance d'abord le coeur du stack, applique les migrations, puis demarre workers et scheduler.
- Pour forcer un autre jeu de fichiers Compose, definir `COMPOSE_FILES`.
- Les variables supplementaires propres a `starter_back` ou `starter_front` doivent etre ajoutees dans `env/.env.<env>`.
- Le profil `observability` est optionnel. Sans `make observability-up`, `/grafana/` ne servira rien.
- `make init` prepare les fichiers de base et les certificats locaux.
- `make stack-assert` rejoue les checks runtime utilises par la gate CI d'integration.
- Voir aussi [backup-pra.md](./backup-pra.md) et [runbooks-ops.md](./runbooks-ops.md).
