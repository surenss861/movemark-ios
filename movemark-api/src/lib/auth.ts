import { createRemoteJWKSet, jwtVerify } from "jose";
import type { Context } from "hono";
import { env } from "./env.js";
import { supabaseAdmin } from "./supabase.js";

let jwks: ReturnType<typeof createRemoteJWKSet> | null = null;
let jwksUrl: string | null = null;

function getJwks() {
  const url = `${env.SUPABASE_URL.replace(/\/$/, "")}/auth/v1/.well-known/jwks.json`;
  if (!jwks || jwksUrl !== url) {
    jwks = createRemoteJWKSet(new URL(url));
    jwksUrl = url;
  }
  return jwks;
}

function bearerToken(c: Context): string {
  const authHeader = c.req.header("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    throw new Error("Unauthorized");
  }
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) throw new Error("Unauthorized");
  return token;
}

/**
 * Prefer local JWT verification (HS256 secret or JWKS). Falls back to
 * supabaseAdmin.auth.getUser when local verify is unavailable or fails.
 */
export async function requireUserIdFromBearer(c: Context): Promise<string> {
  const token = bearerToken(c);

  if (env.SUPABASE_JWT_SECRET) {
    try {
      const { payload } = await jwtVerify(token, new TextEncoder().encode(env.SUPABASE_JWT_SECRET), {
        algorithms: ["HS256"],
      });
      const sub = typeof payload.sub === "string" ? payload.sub : null;
      if (sub) return sub;
    } catch (error) {
      // Expected for non-HS256 tokens; logged so an unexpectedly 100%-failing
      // secret (misconfig) is visible in logs instead of silently degrading
      // every request to the slower JWKS/Auth-API fallbacks.
      console.warn("[movemark-api:auth] HS256 verify failed, falling back to JWKS", error);
    }
  }

  if (env.SUPABASE_URL) {
    try {
      const { payload } = await jwtVerify(token, getJwks(), {
        algorithms: ["ES256", "RS256", "HS256"],
      });
      const sub = typeof payload.sub === "string" ? payload.sub : null;
      if (sub) return sub;
    } catch (error) {
      console.warn("[movemark-api:auth] JWKS verify failed, falling back to Auth API", error);
    }
  }

  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data.user) {
    console.error("[movemark-api:auth] Auth API fallback failed; rejecting request", error);
    throw new Error("Unauthorized");
  }
  return data.user.id;
}
