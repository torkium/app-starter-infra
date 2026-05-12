# Operations

## Local

```bash
cp .env.example .env
cp env/.env.dev.example env/.env.dev
./scripts/generate-dev-certs.sh app.local
./scripts/render-grafana-htpasswd.sh
make dev-up
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
make docker-clean
make docker-clean-safe
make backup
make backup-offsite
make restore FILE=/absolute/path/to/backup.sql.gz
make observability-up
```

## Notes

- `make dev-up` utilise `docker-compose.yml` + `docker-compose.dev.yml` pour lancer la stack locale avec Next.js en hot reload derriere Nginx.
- `make up` utilise seulement `docker-compose.yml` et garde le front en mode image-only, utile pour tester un runtime plus proche de la prod.
- `make front-dev` sert a recreer uniquement le front dev et Nginx sans relancer toute la stack.
- `make dev-up` et `make up` lancent d'abord le coeur du stack, appliquent les migrations, puis demarrent workers et scheduler.
- `make dev-up` lance aussi un nettoyage Docker dev des ressources inutilisees de plus de 24h. Desactivez-le ponctuellement avec `AUTO_DOCKER_CLEANUP=0 make dev-up`.
- `make docker-clean` nettoie en dev les conteneurs, reseaux, images inutilisees et cache build de plus de 24h, sans supprimer les volumes.
- `make docker-clean-safe` garde une retention de 7 jours et ne supprime que les images dangling cote images Docker, adaptee a staging/prod.
- `make docker-clean-hard` ajoute un prune des volumes inutilises. A reserver au dev local, jamais a lancer machinalement en prod.
- Les workflows deploy/rollback lancent `scripts/docker-cleanup.sh deploy` en fin de job avec `DOCKER_CLEANUP_UNTIL=168h` par defaut; ce mode ne supprime pas les images taguees de rollback.
- Pour forcer un autre jeu de fichiers Compose, definir `COMPOSE_FILES`.
- Les variables supplementaires propres a `starter_back` ou `starter_front` doivent etre ajoutees dans `env/.env.<env>`.
- Le profil `observability` est optionnel. Sans `make observability-up`, `/grafana/` ne servira rien.
- `make init` prepare les fichiers de base et les certificats locaux.
- `make stack-assert` rejoue les checks runtime utilises par la gate CI d'integration.
- Voir aussi [backup-pra.md](./backup-pra.md) et [runbooks-ops.md](./runbooks-ops.md).
