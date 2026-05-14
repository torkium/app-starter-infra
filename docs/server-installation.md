# Server installation

Ce guide couvre l'installation generique d'un serveur cible pour `app-starter-infra`.

## Prerequis

- Ubuntu ou Debian recente
- acces sudo
- DNS ou certificat deja prepare
- acces au registre d'images utilise par `app-starter-back` et `app-starter-front`

## Installer Docker et Compose

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"
```

## Recuperer le repo

```bash
git clone git@github.com:owner/app-starter-infra.git
cd app-starter-infra
```

## Initialiser la configuration

```bash
make init
```

Ensuite :

1. adapter `.env`
2. adapter `env/.env.<env>`
3. renseigner les certificats TLS attendus par `TLS_CERT_PATH` et `TLS_KEY_PATH`

## Installer un runner GitHub self-hosted

Utiliser un runner uniquement si ce serveur execute directement les workflows de
deploiement.

1. GitHub repository -> Settings -> Actions -> Runners
2. ajouter un runner Linux
3. installer le service systemd fourni par GitHub

## Verifications

```bash
docker --version
docker compose version
DEPLOY_ENV=prod make config
DEPLOY_ENV=prod make up
make health
```
