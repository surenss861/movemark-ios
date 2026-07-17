import { Hono } from "hono";
import { env } from "../lib/env.js";
import {
  entitlementStatusFromEvent,
  primaryEntitlementId,
  resolveRevenueCatUserId,
  upsertUserEntitlement,
} from "../lib/entitlements.js";
import { rateLimitWebhookByIp } from "../lib/middleware/rateLimit.js";
import { safeJsonError } from "../lib/middleware/safeError.js";
import type { AppVariables } from "../lib/middleware/types.js";
import { constantTimeTokenEquals } from "../lib/webhookAuth.js";
import type { RevenueCatWebhookEvent } from "../types/revenuecat.js";

export const webhooksRouter = new Hono<{ Variables: AppVariables }>();

webhooksRouter.post("/revenuecat", rateLimitWebhookByIp, async (c) => {
  try {
    const authHeader = c.req.header("Authorization") ?? "";
    const expected = env.REVENUECAT_WEBHOOK_SECRET;

    if (!expected) {
      return safeJsonError(c, 401, "Webhook not configured", "webhook_secret_missing");
    } else {
      const token = authHeader.replace("Bearer ", "").trim();
      if (!token || !constantTimeTokenEquals(token, expected)) {
        return safeJsonError(c, 401, "Invalid webhook auth", "webhook_auth_failed");
      }
    }

    const payload = await c.req.json<RevenueCatWebhookEvent>();
    const event = payload.event ?? {};
    const eventId = event.id ?? "unknown";
    const eventType = event.type ?? "unknown";

    const userId = resolveRevenueCatUserId(event);
    if (!userId) {
      console.log(
        JSON.stringify({
          level: "warn",
          requestId: c.get("requestId"),
          message: "revenuecat_webhook_unmapped_user",
          eventId,
          eventType,
          appUserId: event.app_user_id ?? null,
        })
      );
      // Still 200 so RevenueCat does not retry forever for anonymous ids.
      return c.json({ ok: true, mapped: false }, 200);
    }

    const entitlementId = primaryEntitlementId(event.entitlement_ids);
    const status = entitlementStatusFromEvent(event.type, event.expiration_at_ms ?? null);
    const expiresAt =
      event.expiration_at_ms != null
        ? new Date(event.expiration_at_ms).toISOString()
        : null;

    await upsertUserEntitlement({
      userId,
      entitlementId,
      productId: event.product_id ?? null,
      status,
      expiresAt,
      environment: event.environment ?? null,
      revenueCatAppUserId: event.app_user_id ?? null,
      lastEventId: event.id ?? null,
      lastEventType: event.type ?? null,
    });

    console.log(
      JSON.stringify({
        level: "info",
        requestId: c.get("requestId"),
        message: "revenuecat_webhook_entitlement_upserted",
        eventId,
        eventType,
        userId,
        entitlementId,
        status,
      })
    );

    return c.json({ ok: true, mapped: true }, 200);
  } catch (error) {
    return safeJsonError(c, 500, "Unexpected server error", "webhook_handler", error);
  }
});
