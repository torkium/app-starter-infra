# AGENTS.md - starter_infra

Starter infra generique pour une application Symfony + Next.js dockerisee.

## Perimetre

- Ce repo orchestre uniquement l'infra et le runtime local/deploiement.
- Les repos applicatifs attendus sont `../starter_back` et `../starter_front` en local.
- Ne pas introduire de dependance a un contexte metier specifique.

## Standards

- Docker Compose est le mode standard pour le dev et le deploiement.
- Le fichier principal `docker-compose.yml` est image-first pour les environnements distants.
- Le fichier `docker-compose.dev.yml` ajoute les builds locaux depuis les repos freres.
- Les variables runtime partagables entre Symfony et Next.js vivent dans `env/.env.<env>`.

## Hypotheses structurelles

- L'image backend expose une application HTTP sur `BACK_HTTP_PORT` et supporte les commandes CLI Symfony.
- L'image frontend expose Next.js sur `FRONT_HTTP_PORT`.
- Le backend fournit un endpoint de sante sur `BACK_HEALTH_PATH`.
- Les workers et le scheduler reutilisent l'image backend avec des commandes surchargees.

## Regles d'edition

- Si une hypothese d'image ou de variable est ajoutee, la documenter dans `README.md`.
- Garder les scripts shell POSIX/bash simples et idempotents.
- Ne pas referencer d'hostname, registry, runner ou secret propres a un projet reel.
