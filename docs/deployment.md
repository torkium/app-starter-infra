# Deployment

## Hypotheses

- Le backend expose HTTP sur `BACK_HTTP_PORT` dans son image.
- Les workers et le scheduler reutilisent la meme image backend.
- Le deploiement distant consomme des images deja publiees.

## Fichiers

- `docker-compose.yml` : stack image-first pour CI/CD et serveurs.
- `docker-compose.dev.yml` : override de build local depuis `../app-starter-back` et `../app-starter-front`.
- `env/.env.<env>` : variables runtime partagees par les containers.
- `.env` : variables Compose generees par `scripts/render-compose-env.sh`.

## Variables minimales de GitHub Environments

Variables:
- `APP_DOMAIN`
- `BACK_IMAGE`
- `FRONT_IMAGE`
- `MYSQL_DATABASE`
- `MYSQL_USER`
- `BACK_HTTP_PORT`
- `FRONT_HTTP_PORT`
- `TLS_CERT_PATH`
- `TLS_KEY_PATH`
- `APP_FRONT_BASE_URL`
- `DEFAULT_URI`
- `MAILER_FROM`
- `API_BASE_URL`
  Valeur recommandee : `http://back:<BACK_HTTP_PORT>/api` pour que le front SSR/proxy parle au back via le reseau Docker interne.
- `NEXT_PUBLIC_APP_URL`
- `NEXT_PUBLIC_MERCURE_URL`
- `NEXT_PUBLIC_MERCURE_DISABLED`
- `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_MEDIA_UPLOAD_BASE_URL`
- `ENABLE_OBSERVABILITY` si vous voulez provisionner Grafana/Prometheus/Loki
- `MEDIA_EDGE_BASE_URL` si l'application utilise le worker edge media
- `JWT_SECRET_KEY` et `JWT_PUBLIC_KEY` si vous injectez les cles JWT via secrets runtime
- `RELEASE_STATE_ROOT` si vous voulez changer l'emplacement de persistance de l'etat de release

Secrets:
- `APP_SECRET`
- `MYSQL_ROOT_PASSWORD`
- `MYSQL_PASSWORD`
- `MERCURE_JWT_SECRET`
- `MAILER_DSN` si votre DSN contient des credentials
- `JWT_PASSPHRASE`
- `JWT_PRIVATE_KEY_PEM` et `JWT_PUBLIC_KEY_PEM` pour les deploys distants sans cles embarquees
- `STRIPE_SECRET_KEY` et `STRIPE_WEBHOOK_SECRET` si Stripe est active
- `GRAFANA_ADMIN_PASSWORD` et `GRAFANA_SECRET_KEY` si observabilite active
- `GRAFANA_HTPASSWD` si auth basique Nginx activee

## Workflow type

1. Publier les images backend et frontend.
2. Renseigner l'environnement GitHub cible ou le bootstrapper via `docs/github-variables-secrets.md`.
3. Declencher `.github/workflows/deploy.yml`, soit manuellement, soit via `repository_dispatch`.
4. Le workflow genere `.env`, `env/.env.<env>` et `env/grafana.htpasswd`, valide Compose, pull les images, demarre la base + web, capture un snapshot DB pre-migration, lance les migrations, puis demarre les consumers et le scheduler.
5. Si la sante HTTP applicative est validee et que les services async sont bien demarres, l'etat de release est promu dans le repertoire persistant resolu par `RELEASE_STATE_ROOT`.

## Gate d'integration repo infra

Le workflow CI du repo infra ne se limite plus a valider la syntaxe Compose.
Il lance une integration complete avec :

- `db`
- `redis`
- `mercure`
- `back`
- `front`
- `nginx`
- `worker_default`
- `worker_mail`
- `worker_outbox`
- `scheduler`

La gate verifie :

- la montee de pile complete
- la migration Doctrine
- `GET /api/health`
- `GET /`
- `GET /api/doc.json`
- la disponibilite de Mercure
- la presence des services de fond
- quelques variables runtime critiques dans `back` et `front`

## Modes de declenchement

### 1. `workflow_dispatch`

Mode le plus simple pour un deploy manuel ou une reprise ponctuelle :

- choisir `environment`
- choisir `back_version`
- choisir `front_version`
- optionnellement activer `skip_migrations`

Ce mode continue d'utiliser `BACK_IMAGE` et `FRONT_IMAGE` definies dans les
GitHub Environment variables du repo infra.

### 2. `repository_dispatch`

Mode prevu pour une orchestration multi-repo. Les repos applicatifs peuvent
appeler l'API GitHub `repository_dispatch` vers le repo infra apres publication
de leurs images.

Type d'evenement attendu :

```json
{
  "event_type": "deploy",
  "client_payload": {
    "environment": "staging",
    "back_version": "sha-abc123",
    "front_version": "sha-def456"
  }
}
```

Payload minimal :

- `environment` : `dev`, `staging` ou `prod`

Payload optionnel :

- `back_version`
- `front_version`
- `skip_migrations`
- `back_image`
- `front_image`

Le workflow supporte aussi un payload "mono-app" pour qu'un repo backend ou
frontend puisse mettre a jour uniquement sa propre image sans avoir a repeter
les deux champs de version :

```json
{
  "event_type": "deploy",
  "client_payload": {
    "environment": "staging",
    "app": "back",
    "image": "ghcr.io/example/starter-back",
    "version": "sha-abc123",
    "repository": "owner/app-starter-back"
  }
}
```

Regles de resolution :

- `workflow_dispatch` garde le comportement historique
- `repository_dispatch` priorise les valeurs du payload
- si `app=back`, `image` et `version` alimentent le backend seulement, et le frontend conserve son tag actuellement deploie
- si `app=front`, `image` et `version` alimentent le frontend seulement, et le backend conserve son tag actuellement deploie
- si une image n'est pas fournie dans le payload, la variable GitHub Environment correspondante reste la source de verite

## Exemple d'appel depuis un repo applicatif

```bash
curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${INFRA_REPO_TOKEN}" \
  https://api.github.com/repos/owner/starter_infra/dispatches \
  -d '{
    "event_type": "deploy",
    "client_payload": {
      "environment": "staging",
      "app": "back",
      "version": "sha-abc123",
      "repository": "owner/app-starter-back"
    }
  }'
```

Le token doit avoir le droit de declencher des workflows sur le repo infra.

## Rollback

- Frontend manuel par tag : workflow `rollback.yml` avec `target=front` et `version`.
- Backend/stack vers la release precedente : `./scripts/rollback.sh both` si un snapshot precedent persiste dans `RELEASE_STATE_ROOT`.
- Les rollbacks backend explicites par tag sont refuses par defaut tant qu'aucune restauration DB coherente n'est fournie.

## Options

- observabilite : voir [observability.md](./observability.md)
- worker edge media : voir [cloudflare-worker.md](./cloudflare-worker.md)
