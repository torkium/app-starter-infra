# Variables et secrets GitHub

Ce starter utilise les GitHub Environments pour isoler la configuration de
`dev`, `staging` et `prod`.

## Principe

- les valeurs publiques ou peu sensibles vont dans `Variables`
- les credentials, mots de passe et secrets de signature vont dans `Secrets`
- chaque environnement GitHub porte les memes noms de cles

## Variables attendues

- `COMPOSE_PROJECT_NAME`
- `APP_DOMAIN`
- `BACK_IMAGE`
- `FRONT_IMAGE`
- `MYSQL_VERSION`
- `REDIS_VERSION`
- `NGINX_VERSION`
- `MERCURE_VERSION`
- `GRAFANA_VERSION`
- `PROMETHEUS_VERSION`
- `LOKI_VERSION`
- `ALLOY_VERSION`
- `CADVISOR_VERSION`
- `MYSQL_DATABASE`
- `MYSQL_USER`
- `HOST_HTTP_PORT`
- `HOST_HTTPS_PORT`
- `TLS_CERT_PATH`
- `TLS_KEY_PATH`
- `BACK_HTTP_PORT`
- `BACK_HEALTH_PATH`
- `FRONT_HTTP_PORT`
- `MIGRATION_COMMAND`
- `WORKER_DEFAULT_COMMAND`
- `WORKER_MAIL_COMMAND`
- `WORKER_OUTBOX_COMMAND`
- `SCHEDULER_COMMAND`
- `SCHEDULER_TICK_COMMAND`
- `MERCURE_CORS_ALLOWED_ORIGINS`
- `MERCURE_PUBLISH_ALLOWED_ORIGINS`
- `ENABLE_OBSERVABILITY`
- `GRAFANA_AUTH_BASIC_REALM`
- `PROMETHEUS_RETENTION`
- `LOKI_RETENTION`
- `ENABLE_MEDIA_EDGE`
- `MEDIA_EDGE_BASE_URL`
- `APP_ENV`
- `APP_DEBUG`
- `APP_FRONT_BASE_URL`
- `DEFAULT_URI`
- `REDIS_URL`
- `MESSENGER_TRANSPORT_DSN`
- `MESSENGER_MAIL_TRANSPORT_DSN`
- `MESSENGER_OUTBOX_TRANSPORT_DSN`
- `MESSENGER_FAILED_TRANSPORT_DSN`
- `MAILER_FROM`
- `API_BASE_URL`
  Recommandation : `http://back:<BACK_HTTP_PORT>/api` plutot qu'une URL publique, pour garder un chemin serveur interne stable entre `front` et `back`.
- `NEXT_PUBLIC_APP_URL`
- `NEXT_PUBLIC_MERCURE_URL`
- `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_MEDIA_BASE_URL`
- `NEXT_PUBLIC_MEDIA_UPLOAD_BASE_URL`
- `NEXT_PUBLIC_VAPID_PUBLIC_KEY`
- `B2_ENDPOINT`
- `B2_BUCKET`
- `B2_PREFIX`
- `JWT_SECRET_KEY`
- `JWT_PUBLIC_KEY`
- `GRAFANA_ADMIN_USER`
- `BACK_SOURCE_REPOSITORY`
- `FRONT_SOURCE_REPOSITORY`
- `RELEASE_STATE_ROOT`

## Secrets attendus

- `APP_SECRET`
- `MYSQL_ROOT_PASSWORD`
- `MYSQL_PASSWORD`
- `MERCURE_JWT_SECRET`
- `MAILER_DSN`
- `JWT_PASSPHRASE`
- `JWT_PRIVATE_KEY_PEM`
- `JWT_PUBLIC_KEY_PEM`
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `GRAFANA_ADMIN_PASSWORD`
- `GRAFANA_SECRET_KEY`
- `GRAFANA_HTPASSWD`
- `CI_READ_REPOSITORIES_TOKEN` si le repo infra doit checkout des repos applicatifs prives pendant sa gate CI d'integration

## Bootstrap

1. Copier [bootstrap/github/environment.env.example](../bootstrap/github/environment.env.example) vers un fichier local non versionne.
2. Adapter les valeurs de l'environnement cible.
3. Authentifier `gh`.
4. Lancer le bootstrap.

Exemples :

```bash
cp bootstrap/github/environment.env.example bootstrap/github/dev.env
./scripts/bootstrap-github-environment.sh \
  --envs=dev \
  --env-file=bootstrap/github/dev.env \
  --repo=my-org/my-app-infra \
  --mask
```

```bash
./scripts/bootstrap-github-environment.sh \
  --apply \
  --envs=prod \
  --env-file=bootstrap/github/prod.env \
  --repo=my-org/my-app-infra
```

## Notes

- `ENABLE_OBSERVABILITY=1` renseigne automatiquement `COMPOSE_PROFILES=observability` au moment du rendu de `.env`.
- `GRAFANA_HTPASSWD` est optionnel tant que `GRAFANA_AUTH_BASIC_REALM=off`.
- `ENABLE_MEDIA_EDGE=1` n'active pas un container. Cette variable documente que l'application consomme un worker edge externe.
- `BACK_SOURCE_REPOSITORY` et `FRONT_SOURCE_REPOSITORY` permettent a la gate CI du repo infra de savoir quels repos checkout pour lancer l'integration complete.
- `RELEASE_STATE_ROOT` permet de persister l'etat de release et les snapshots pre-migration hors workspace GitHub Actions.
- pour un deploy distant propre du backend, fournissez `JWT_PRIVATE_KEY_PEM`, `JWT_PUBLIC_KEY_PEM` et `JWT_PASSPHRASE`, avec `JWT_SECRET_KEY` / `JWT_PUBLIC_KEY` pointant vers un chemin runtime ecrivable dans le container.
- pour les PEM injectes via `bootstrap/github/*.env`, stockez-les sur une seule ligne avec des `\n` echappes.
- si `ENABLE_OBSERVABILITY=1`, les workflows refusent les mots de passe et secret keys Grafana trop faibles ou laisses sur des placeholders.

## Variables et secrets utiles cote repos applicatifs

Si vous voulez declencher le deploy infra automatiquement depuis les repos
backend ou frontend, prevoyez aussi des secrets dans ces repos applicatifs :

- `INFRA_REPOSITORY`
  Exemple : `my-org/my-app-infra`
- `INFRA_REPOSITORY_DISPATCH_TOKEN`
  Token GitHub ou GitHub App token avec droits suffisants pour appeler `repository_dispatch` sur le repo infra

Le repo infra n'utilise pas directement ces secrets. Ils servent uniquement aux
workflows des repos applicatifs pour emettre un `repository_dispatch`.

Contrat recommande :

- `develop` publie l'image `dev-*` et peut declencher `environment=dev`
- `main` publie l'image `staging-*` et peut declencher `environment=staging`
- `prod` passe par `workflow_dispatch` sur le repo applicatif, puis `workflow_dispatch` ou `repository_dispatch` vers l'infra
