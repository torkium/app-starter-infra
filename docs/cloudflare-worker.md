# Worker edge media

Ce starter inclut un worker Cloudflare generique pour exposer en lecture un
bucket Backblaze B2 prive via des URLs signees HS256.

Fichiers :

- [edge-media-worker/worker.js](../edge-media-worker/worker.js)
- [edge-media-worker/wrangler.toml.example](../edge-media-worker/wrangler.toml.example)

## Capacites fournies

- verification JWT HS256
- verification du chemin demande
- limitation de TTL
- restriction d'origine CORS
- URLs one-shot optionnelles via KV `USED_JTIS`
- proxy direct vers `b2_download_file_by_name`

## Payload JWT attendu

```json
{
  "path": "folder/file.jpg",
  "exp": 1760000000,
  "nbf": 1759999700,
  "method": "GET",
  "cache": "default",
  "jti": "optional-once-token-id"
}
```

`cache` accepte :

- `default`
- `avatar`
- `public`

Les classes `avatar` et `public` activent des headers cache plus longs.

## Variables du worker

- `HMAC_SECRET`
- `ALLOWED_ORIGINS`
- `B2_ENDPOINT`
- `B2_BUCKET`
- `B2_PREFIX`
- `B2_KEY_ID`
- `B2_APP_KEY`
- `MAX_TTL`
- `DEFAULT_CACHE_MAX_AGE`
- `DEFAULT_CACHE_STALE_WHILE_REVALIDATE`
- `LONG_CACHE_MAX_AGE`
- `LONG_CACHE_STALE_WHILE_REVALIDATE`

## Mise en place rapide

1. Copier `wrangler.toml.example` vers `wrangler.toml`.
2. Declarer les vars non sensibles.
3. Injecter `HMAC_SECRET`, `B2_KEY_ID` et `B2_APP_KEY` comme secrets Cloudflare.
4. Creer un namespace KV `USED_JTIS` si vous voulez des liens one-shot.
5. Publier le worker avec `npx wrangler deploy`.
6. Reporter l'URL publiee dans `MEDIA_EDGE_BASE_URL` et `NEXT_PUBLIC_MEDIA_BASE_URL`.

## Exemple de signature cote application

Le backend doit signer un JWT HS256 contenant au minimum :

- `path`
- `exp`
- eventuellement `method=GET`
- eventuellement `cache`
- eventuellement `jti`

L'URL finale attendue par le worker suit ce format :

```text
https://media.example.test/i/folder/file.jpg?token=<jwt>
```

## Limites connues

- le worker ne gere ici que `GET` et `HEAD`
- la lecture B2 repose sur l'API native Backblaze, pas sur une signature S3
- aucune ecriture n'est exposee depuis ce starter
