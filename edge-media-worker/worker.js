const AUTH_CACHE_TTL_MS = 12 * 60 * 60 * 1000;

let cachedB2Auth = null;

export default {
  async fetch(request, env, ctx) {
    try {
      if (request.method !== "GET" && request.method !== "HEAD") {
        return json({ error: "method_not_allowed" }, 405);
      }

      if (!request.url.includes("/i/")) {
        return json({ error: "not_found" }, 404);
      }

      const origin = request.headers.get("Origin");
      if (origin && !isAllowedOrigin(origin, env.ALLOWED_ORIGINS)) {
        return json({ error: "origin_not_allowed" }, 403, corsHeaders(origin));
      }

      const token = new URL(request.url).searchParams.get("token");
      if (!token) {
        return json({ error: "missing_token" }, 401, corsHeaders(origin));
      }

      const payload = await verifyJwt(token, env.HMAC_SECRET);
      validatePayload(payload, request, env);

      if (payload.jti && env.USED_JTIS) {
        const key = `jti:${payload.jti}`;
        const alreadyUsed = await env.USED_JTIS.get(key);
        if (alreadyUsed) {
          return json({ error: "token_already_used" }, 410, corsHeaders(origin));
        }

        const ttl = Math.max(60, payload.exp - Math.floor(Date.now() / 1000));
        ctx.waitUntil(env.USED_JTIS.put(key, "1", { expirationTtl: ttl }));
      }

      const objectPath = normalizeObjectPath(payload.path);
      const b2Response = await fetchFromB2(objectPath, env, request.method);
      if (!b2Response.ok) {
        return json({ error: "upstream_fetch_failed" }, b2Response.status, corsHeaders(origin));
      }

      const headers = new Headers(b2Response.headers);
      headers.set("Cache-Control", buildCacheControl(payload, env));
      headers.set("X-Content-Type-Options", "nosniff");
      applyCors(headers, origin);

      return new Response(request.method === "HEAD" ? null : b2Response.body, {
        status: b2Response.status,
        headers
      });
    } catch (error) {
      const origin = request.headers.get("Origin");
      return json({ error: error.message || "invalid_request" }, error.statusCode || 401, corsHeaders(origin));
    }
  }
};

function validatePayload(payload, request, env) {
  const now = Math.floor(Date.now() / 1000);
  if (!payload.path || typeof payload.path !== "string") {
    throw httpError("invalid_path", 401);
  }

  if (!payload.exp || payload.exp < now) {
    throw httpError("expired_token", 401);
  }

  if (payload.nbf && payload.nbf > now) {
    throw httpError("token_not_active", 401);
  }

  if (payload.method && payload.method !== request.method) {
    throw httpError("invalid_method", 401);
  }

  const url = new URL(request.url);
  const requestedPath = decodeURIComponent(url.pathname.replace(/^\/i\//, ""));
  if (normalizeObjectPath(requestedPath) !== normalizeObjectPath(payload.path)) {
    throw httpError("path_mismatch", 401);
  }

  const maxTtl = clampInt(env.MAX_TTL || "300", 60, 3600);
  if (payload.exp - now > maxTtl && !isLongCacheClass(payload.cache)) {
    throw httpError("ttl_too_long", 401);
  }
}

function normalizeObjectPath(path) {
  return path.replace(/^\/+/, "").replace(/\.\./g, "");
}

function isAllowedOrigin(origin, allowedOrigins) {
  if (!allowedOrigins) {
    return true;
  }
  return allowedOrigins.split(",").map((item) => item.trim()).includes(origin);
}

function buildCacheControl(payload, env) {
  if (isLongCacheClass(payload.cache)) {
    const maxAge = clampInt(env.LONG_CACHE_MAX_AGE || "604800", 60, 604800);
    const swr = clampInt(env.LONG_CACHE_STALE_WHILE_REVALIDATE || "600", 0, 86400);
    return `private, max-age=${maxAge}, stale-while-revalidate=${swr}`;
  }

  const maxAge = clampInt(env.DEFAULT_CACHE_MAX_AGE || "300", 0, 3600);
  const swr = clampInt(env.DEFAULT_CACHE_STALE_WHILE_REVALIDATE || "60", 0, 3600);
  return `private, max-age=${maxAge}, stale-while-revalidate=${swr}`;
}

function isLongCacheClass(cacheClass) {
  return cacheClass === "avatar" || cacheClass === "public";
}

async function fetchFromB2(objectPath, env, method) {
  const auth = await getB2Authorization(env);
  const base = env.B2_ENDPOINT.replace(/\/$/, "");
  const bucket = env.B2_BUCKET;
  const prefix = env.B2_PREFIX ? `${env.B2_PREFIX.replace(/^\/|\/$/g, "")}/` : "";
  const objectName = `${prefix}${objectPath}`.replace(/\/+/g, "/");
  const target = `${base}/file/${bucket}/${encodePathSegments(objectName)}`;

  return fetch(target, {
    method,
    headers: {
      Authorization: auth.authorizationToken
    }
  });
}

async function getB2Authorization(env) {
  if (cachedB2Auth && cachedB2Auth.expiresAt > Date.now()) {
    return cachedB2Auth;
  }

  const basic = btoa(`${env.B2_KEY_ID}:${env.B2_APP_KEY}`);
  const response = await fetch("https://api.backblazeb2.com/b2api/v2/b2_authorize_account", {
    headers: {
      Authorization: `Basic ${basic}`
    }
  });

  if (!response.ok) {
    throw httpError("b2_authorization_failed", 502);
  }

  const payload = await response.json();
  cachedB2Auth = {
    authorizationToken: payload.authorizationToken,
    expiresAt: Date.now() + AUTH_CACHE_TTL_MS
  };

  return cachedB2Auth;
}

async function verifyJwt(token, secret) {
  const [encodedHeader, encodedPayload, encodedSignature] = token.split(".");
  if (!encodedHeader || !encodedPayload || !encodedSignature) {
    throw httpError("malformed_token", 401);
  }

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"]
  );

  const valid = await crypto.subtle.verify(
    "HMAC",
    key,
    base64UrlToBytes(encodedSignature),
    new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`)
  );

  if (!valid) {
    throw httpError("invalid_signature", 401);
  }

  const header = JSON.parse(bytesToText(base64UrlToBytes(encodedHeader)));
  if (header.alg !== "HS256") {
    throw httpError("unsupported_algorithm", 401);
  }

  return JSON.parse(bytesToText(base64UrlToBytes(encodedPayload)));
}

function base64UrlToBytes(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const pad = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  const binary = atob(`${normalized}${pad}`);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function bytesToText(bytes) {
  return new TextDecoder().decode(bytes);
}

function encodePathSegments(path) {
  return path.split("/").map((segment) => encodeURIComponent(segment)).join("/");
}

function clampInt(value, min, max) {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed)) {
    return min;
  }
  return Math.min(max, Math.max(min, parsed));
}

function corsHeaders(origin) {
  const headers = new Headers();
  applyCors(headers, origin);
  return headers;
}

function applyCors(headers, origin) {
  if (origin) {
    headers.set("Access-Control-Allow-Origin", origin);
    headers.set("Vary", "Origin");
  }
}

function json(payload, status, headers = new Headers()) {
  headers.set("Content-Type", "application/json; charset=utf-8");
  return new Response(JSON.stringify(payload), { status, headers });
}

function httpError(message, statusCode) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}
