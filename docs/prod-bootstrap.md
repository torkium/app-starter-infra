# Production bootstrap

Ce document sert de checklist de premiere mise en service.

## 1. Configuration GitHub

- creer les GitHub Environments `dev`, `staging`, `prod`
- renseigner variables et secrets via [github-variables-secrets.md](./github-variables-secrets.md)
- verifier `BACK_IMAGE` et `FRONT_IMAGE`
- verifier les secrets d'observabilite si `ENABLE_OBSERVABILITY=1`

## 2. Configuration serveur

- suivre [server-installation.md](./server-installation.md)
- preparer les certificats TLS
- verifier l'acces au registre

## 3. Initialisation locale sur le serveur

```bash
make init
```

Puis ajuster :

- `.env`
- `env/.env.prod`
- `env/grafana.htpasswd` si auth basique Grafana requise

## 4. Validation avant premier deploy

```bash
make config
docker compose -f docker-compose.yml config >/dev/null
```

## 5. Premier deploy

- soit via `workflow_dispatch` du repo infra
- soit via `repository_dispatch` depuis les repos applicatifs

## 6. Verification post-deploy

```bash
make health
make stack-assert
```
