import { Redis } from "ioredis";
import type { Context } from "hono";
import { createMiddleware } from "hono/factory";
import type { AppVariables } from "./types.js";
import { safeJsonError } from "./safeError.js";
import { env } from "../env.js";

type RateLimitContext = Context<{ Variables: AppVariables }>;

type Bucket = {
  count: number;
  resetAt: number;
};

const memoryBuckets = new Map<string, Bucket>();
const MEMORY_MAX_KEYS = 10_000;

let redis: Redis | null = null;
let redisInitAttempted = false;

function getRedis(): Redis | null {
  if (redisInitAttempted) return redis;
  redisInitAttempted = true;
  if (!env.REDIS_URL) return null;
  try {
    redis = new Redis(env.REDIS_URL, {
      maxRetriesPerRequest: 1,
      enableReadyCheck: true,
      lazyConnect: true,
    });
    redis.on("error", (err: Error) => {
      console.error("[movemark-api:rateLimit] redis error", err.message);
    });
    void redis.connect().catch((err: unknown) => {
      console.error("[movemark-api:rateLimit] redis connect failed; using memory", err);
      redis = null;
    });
  } catch (err) {
    console.error("[movemark-api:rateLimit] redis init failed; using memory", err);
    redis = null;
  }
  return redis;
}

function pruneMemoryBuckets(now: number): void {
  for (const [key, bucket] of memoryBuckets) {
    if (now >= bucket.resetAt) memoryBuckets.delete(key);
  }
  if (memoryBuckets.size <= MEMORY_MAX_KEYS) return;
  // Drop oldest-expiring keys first when over cap.
  const sorted = [...memoryBuckets.entries()].sort((a, b) => a[1].resetAt - b[1].resetAt);
  const toDrop = sorted.slice(0, memoryBuckets.size - MEMORY_MAX_KEYS);
  for (const [key] of toDrop) memoryBuckets.delete(key);
}

async function consumeLimit(
  bucketKey: string,
  windowMs: number,
  max: number
): Promise<{ allowed: true } | { allowed: false; retryAfterSec: number }> {
  const now = Date.now();
  const client = getRedis();

  if (client && client.status === "ready") {
    try {
      const count = await client.incr(bucketKey);
      if (count === 1) {
        await client.pexpire(bucketKey, windowMs);
      }
      if (count > max) {
        const ttl = await client.pttl(bucketKey);
        const retryAfterSec = Math.max(1, Math.ceil((ttl > 0 ? ttl : windowMs) / 1000));
        return { allowed: false, retryAfterSec };
      }
      return { allowed: true };
    } catch (err) {
      console.error("[movemark-api:rateLimit] redis consume failed; memory fallback", err);
    }
  }

  pruneMemoryBuckets(now);
  let bucket = memoryBuckets.get(bucketKey);
  if (!bucket || now >= bucket.resetAt) {
    bucket = { count: 0, resetAt: now + windowMs };
    memoryBuckets.set(bucketKey, bucket);
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

    const bucketKey = `rl:${options.name}:${limitKey}`;
    const result = await consumeLimit(bucketKey, options.windowMs, options.max);
    if (!result.allowed) {
      c.header("Retry-After", String(result.retryAfterSec));
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
    // Use the rightmost IP — set by the last trusted proxy (Railway infra).
    // The leftmost value can be spoofed by the client.
    const ips = forwarded.split(",").map((s) => s.trim()).filter(Boolean);
    const last = ips[ips.length - 1];
    if (last) return last;
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
  const bucketKey = `rl:export_create_${exportKind}:${userId}:${propertyId}`;
  return consumeLimit(bucketKey, 60 * 60_000, 3);
}

/** Test helper — clears in-memory buckets between tests. */
export function resetRateLimitsForTests(): void {
  memoryBuckets.clear();
}
