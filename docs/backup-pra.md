# Sauvegarde et PRA

Ce starter fournit une base simple mais exploitable pour la sauvegarde MySQL et
la reprise d'activite.

## Perimetre

- base MySQL via les scripts fournis
- volume media local `media_uploads` quand la stack utilise encore le stockage disque du starter
- procedure documentee pour reconstituer la configuration runtime (`.env`,
  `env/.env.<env>`) et les secrets GitHub Environments a partir de votre coffre
  de secrets / gestionnaire de mots de passe
- procedure documentee pour rebrancher l'acces au registre d'images

Les medias distants servent generalement depuis un bucket objet externe. Ils ne
font donc pas partie du backup local du repo infra. En revanche, si vous restez
sur le stockage local du starter, le volume `media_uploads` est archive en meme
temps que la base.

## Scripts fournis

- [scripts/backup.sh](../scripts/backup.sh)
- [scripts/backup-offsite.sh](../scripts/backup-offsite.sh)
- [scripts/restore.sh](../scripts/restore.sh)

Ces scripts sauvegardent la base MySQL et, si present, l'archive media locale
associee. Les fichiers runtime et les secrets doivent etre geres dans un coffre
separe.

## Strategie recommandee

- backup local quotidien de la base
- retention locale glissante de quelques jours
- replication offsite hebdomadaire via `restic`
- test de restauration au moins une fois par mois

## Variables utiles pour l'offsite

- `RESTIC_REPOSITORY`
- `RESTIC_PASSWORD`
- `RESTIC_KEEP_DAILY`
- `RESTIC_KEEP_WEEKLY`
- `RESTIC_KEEP_MONTHLY`
- `B2_KEY_ID` / `B2_APP_KEY` si le repo restic est sur Backblaze B2

## Exemples

Backup local :

```bash
make backup
```

Backup offsite :

```bash
RESTIC_REPOSITORY=b2:starter-backups:mysql \
RESTIC_PASSWORD='replace-me' \
make backup-offsite
```

Restore :

```bash
make restore FILE=/absolute/path/to/mysql-20260510T020000Z.sql.gz
```

## PRA court

Scenario : perte totale de la machine

1. Reprovisionner un serveur propre.
2. Reinstaller Docker, Compose et le runner GitHub si necessaire.
3. Recréer `.env` et `env/.env.<env>`.
4. Rehydrater `.env`, `env/.env.<env>` et les GitHub Environments depuis votre
   coffre de secrets.
5. Relancer la stack infra.
6. Restaurer le dernier dump MySQL, avec son archive media si elle existe.
7. Verifier front, API, workers et scheduler.

La checklist operationnelle est dans [runbooks-ops.md](./runbooks-ops.md).
