# Observabilite

Cette stack ajoute une observabilite self-hosted minimale mais exploitable.

Services :

- `grafana`
- `prometheus`
- `loki`
- `alloy`
- `cadvisor`

## Activation

Local :

```bash
./scripts/render-grafana-htpasswd.sh
make observability-up
```

Serveur :

- positionner `ENABLE_OBSERVABILITY=1`
- renseigner `GRAFANA_ADMIN_PASSWORD`, `GRAFANA_SECRET_KEY`
- si besoin, fournir `GRAFANA_HTPASSWD`
- les valeurs faibles ou par defaut sont refusees par les workflows de deploy/rollback

Contraintes minimales :

- `GRAFANA_ADMIN_PASSWORD` : au moins 16 caracteres
- `GRAFANA_SECRET_KEY` : au moins 24 caracteres
- pas de valeur type `change-me`, `password`, `secret`, `admin`

## Acces

- Grafana est proxifie via `https://<app-domain>/grafana/`
- les autres briques restent sur le reseau Docker interne
- `GRAFANA_AUTH_BASIC_REALM=off` desactive l'auth basique Nginx

## Verifications utiles

```bash
docker compose --profile observability config
docker compose --profile observability up -d grafana prometheus loki alloy cadvisor
docker compose --profile observability exec -T nginx nginx -t
docker compose --profile observability exec -T nginx wget -qO- http://prometheus:9090/api/v1/targets
docker compose --profile observability exec -T nginx wget -qO- http://loki:3100/loki/api/v1/labels
```

## Limites

- pas de tracing distribue
- pas de notification channel Grafana provisionne
- pas de dashboards applicatifs metier : seulement une base containers/logs
