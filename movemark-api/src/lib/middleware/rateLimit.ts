import type { Context } from "hono";
import { createMiddleware } from "hono/factory";
import type { AppVariables } from "./types.js";
import { safeJsonError } from "./safeError.js";

type RateLimitContext = Context<{ Variables: AppVariables }>;

type Bucket = {
  count: number;
  resetAt: number;
};

const buckets = new Map<string, Bucket>();

/** In-memory fixed window limiter. Sufficient for single Railway instance; upgrade to Redis for multi-replica. */
export function createRateLimitMiddleware(options: {
  name: string;
  windowMs: number;
  max: number;
  key: (c: RateLimitContext) => string | null;
}) {
  return createMiddleware<{ Variables: AppVariables }>(async (c, next) => {
    const limitKey = options.key(c);
    if (!limitKey) {
      await next();
      return;
    }

    const bucketKey = `${options.name}:${limitKey}`;
    const now = Date.now();
    let bucket = buckets.get(bucketKey);

    if (!bucket || now >= bucket.resetAt) {
      bucket = { count: 0, resetAt: now + options.windowMs };
      buckets.set(bucketKey, bucket);
    }

    bucket.count += 1;

    if (bucket.count > options.max) {
      const retryAfterSec = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
      c.header("Retry-After", String(retryAfterSec));
      return safeJsonError(c, 429, "Too many requests", "rate_limit", {
        limiter: options.name,
        key: limitKey,
      });
    }

    await next();
  });
}

export function clientIp(c: {
  req: {
    header: (name: string) => string | undefined;
  };
}): string {
  const forwarded = c.req.header("x-forwarded-for");
  if (forwarded) {
    const first = forwarded.split(",")[0]?.trim();
    if (first) return first;
  }
  const realIp = c.req.header("x-real-ip")?.trim();
  if (realIp) return realIp;
  return "unknown";
}

export const rateLimitHealthByIp = createRateLimitMiddleware({
  name: "health_ip",
  windowMs: 60_000,
  max: 60,
  key: (c) => clientIp(c),
});

export const rateLimitWebhookByIp = createRateLimitMiddleware({
  name: "webhook_ip",
  windowMs: 60_000,
  max: 100,
  key: (c) => clientIp(c),
});

export function rateLimitExportsListByUser() {
  return createRateLimitMiddleware({
    name: "exports_list_user",
    windowMs: 60_000,
    max: 60,
    key: (c) => c.get("userId") ?? null,
  });
}

export function rateLimitExportDownloadByUser() {
  return createRateLimitMiddleware({
    name: "export_download_user",
    windowMs: 60_000,
    max: 20,
    key: (c) => c.get("userId") ?? null,
  });
}

export function rateLimitExportCreateByUserProperty(exportKind: string) {
  return createRateLimitMiddleware({
    name: `export_create_${exportKind}`,
    windowMs: 60 * 60_000,
    max: 3,
    key: (c) => {
      const userId = c.get("userId");
      if (!userId) return null;
      const propertyId = c.req.query("propertyId")?.trim();
      if (propertyId) {
        return `${userId}:${propertyId}`;
      }
      return `${userId}:body`;
    },
  });
}

/** Call after parsing JSON body to apply per-user+property export create limits. */
export async function checkExportCreateRateLimit(
  userId: string,
  propertyId: string,
  exportKind: string
): Promise<{ allowed: true } | { allowed: false; retryAfterSec: number }> {
  const bucketKey = `export_create_${exportKind}:${userId}:${propertyId}`;
  const windowMs = 60 * 60_000;
  const max = 3;
  const now = Date.now();

  let bucket = buckets.get(bucketKey);
  if (!bucket || now >= bucket.resetAt) {
    bucket = { count: 0, resetAt: now + windowMs };
    buckets.set(bucketKey, bucket);
  }

  bucket.count += 1;
  if (bucket.count > max) {
    return {
      allowed: false,
      retryAfterSec: Math.max(1, Math.ceil((bucket.resetAt - now) / 1000)),
    };
  }
  return { allowed: true };
}

/** Test helper — clears in-memory buckets between tests. */
export function resetRateLimitsForTests(): void {
  buckets.clear();
}
