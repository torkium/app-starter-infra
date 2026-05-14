# Quick Start complet

## 0. Bootstrap recommande

Depuis `app-starter-infra`, le chemin le plus fiable est l'orchestrateur :

```bash
./scripts/bootstrap-project.sh \
  --project-name my-app \
  --github-owner my-org \
  --back-repo my-app-back \
  --front-repo my-app-front \
  --infra-repo my-app-infra
```

Le script :
- applique les remplacements connus dans les trois repos
- genere les fichiers locaux ignores s'ils sont absents
- verifie les prerequis utiles au bootstrap
- laisse uniquement les actions GitHub reelles a faire a la main

Par defaut, l'orchestrateur sait partir d'un trio clone avec les noms de dossiers
locaux `app-starter-back`, `app-starter-front`, `app-starter-infra`.

Ce guide sert de fil directeur pour repartir du trio `app-starter-back`,
`app-starter-front`, `app-starter-infra` et obtenir un projet utilisable sans chasse aux
variables.

Convention de lecture du guide :

- avant bootstrap ou renommage local, les chemins ci-dessous sont `starter_*`
- apres bootstrap et renommage local des dossiers, remplacez-les par vos noms de repos reels

## 1. Choisir le mode d'usage

Tu peux utiliser les starters de deux manieres :

- `app-starter-back` seul, avec ton propre front et ta propre infra
- `app-starter-front` seul, avec ton propre backend compatible
- les trois repos ensemble, avec `app-starter-infra` comme orchestrateur global

Le reste de ce guide couvre le mode complet a trois repos.

## 2. Preparer les trois repos

Dans chaque repo :

```bash
make init
```

Ordre recommande :

1. `app-starter-back`
2. `app-starter-front`
3. `app-starter-infra`

## 3. Configurer le backend

Fichier principal : `app-starter-back/.env`

Variables a verifier en premier :

- `APP_FRONT_BASE_URL`
- `MAILER_DSN`
- `MAILER_FROM`
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`

Pour les cles JWT :

- `make init` cree deja `config/jwt/private.pem` et `config/jwt/public.pem`
- pour la prod, remplacez-les par des cles durables generees hors machine de dev

## 4. Configurer le frontend

Fichier principal : `app-starter-front/.env`

Variables a verifier :

- `API_BASE_URL`
- `NEXT_PUBLIC_APP_URL`
- `NEXT_PUBLIC_MERCURE_URL`
- `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_MEDIA_BASE_URL`
- `NEXT_PUBLIC_MEDIA_UPLOAD_BASE_URL`
- `NEXT_PUBLIC_VAPID_PUBLIC_KEY`

## 5. Configurer l'infra

Fichiers principaux :

- `app-starter-infra/.env`
- `app-starter-infra/env/.env.dev`
- `app-starter-infra/bootstrap/github/dev.env` ou equivalent

Variables/secrets les plus structurants :

- `APP_DOMAIN`
- `BACK_IMAGE`, `FRONT_IMAGE`
- `APP_SECRET`
- `MYSQL_PASSWORD`, `MYSQL_ROOT_PASSWORD`
- `MERCURE_JWT_SECRET`
- `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
- `MEDIA_EDGE_BASE_URL`
- `B2_ENDPOINT`, `B2_BUCKET`, `B2_PREFIX`
- `NEXT_PUBLIC_VAPID_PUBLIC_KEY`

En mode dev pack complet, le comportement par defaut est :

- `MAILER_DSN=smtp://mailpit:1025`
- interface Mailpit sur `http://localhost:8025`

## 6. Stripe

Creer les cles dans le dashboard Stripe :

1. Developers -> API keys
2. recuperer `Publishable key` et `Secret key`
3. Developers -> Webhooks
4. creer un endpoint de webhook vers `https://<app-domain>/api/stripe/webhook`
5. recuperer le `Signing secret`

Ou les mettre :

- `app-starter-back/.env`
  - `STRIPE_SECRET_KEY`
  - `STRIPE_WEBHOOK_SECRET`
- `app-starter-front/.env`
  - `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
- `app-starter-infra/env/.env.<env>`
  - `STRIPE_SECRET_KEY`
  - `STRIPE_WEBHOOK_SECRET`
  - `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`

## 7. Backblaze B2 / media edge

Si vous servez des medias prives :

1. creer un bucket prive B2
2. creer une application key B2 avec acces limite au bucket
3. deployer le worker Cloudflare fourni dans `edge-media-worker/`
4. reporter l'URL publiee dans `MEDIA_EDGE_BASE_URL`

Ou mettre les valeurs :

- `app-starter-infra/env/.env.<env>`
  - `B2_ENDPOINT`
  - `B2_BUCKET`
  - `B2_PREFIX`
  - `MEDIA_EDGE_BASE_URL`
- `app-starter-infra/bootstrap/github/*.env`
  - memes cles cote GitHub Environment

Voir aussi [cloudflare-worker.md](./cloudflare-worker.md).

## 8. GitHub variables et secrets

Le point d'entree est :

- [github-variables-secrets.md](./github-variables-secrets.md)

Bootstrap recommande :

```bash
cd app-starter-infra
cp bootstrap/github/environment.env.example bootstrap/github/dev.env
./scripts/bootstrap-github-environment.sh --envs=dev --env-file=bootstrap/github/dev.env --repo=my-org/my-app-infra --mask
```

Pour les repos applicatifs, ajouter aussi :

- `INFRA_REPOSITORY`
- `INFRA_REPOSITORY_DISPATCH_TOKEN`

## 9. Premier demarrage local

Infra complete recommande :

```bash
cd app-starter-infra
make dev-up
make stack-assert
```

Ce mode devient la reference pour le dev pack complet :

- front + back + workers + scheduler + proxy TLS
- Mercure
- Mailpit sur `http://localhost:8025`
- migrations executees automatiquement pendant `make dev-up` ou `make up` en `DEPLOY_ENV=dev`

## 10. Verification finale minimale

Backend :

```bash
cd app-starter-back
make test
```

Frontend :

```bash
cd app-starter-front
make check
```

Infra :

```bash
cd app-starter-infra
make config
make health
make stack-assert
```
