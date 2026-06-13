import { Hono } from "hono";
import { env } from "../lib/env.js";
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
      if (env.APP_ENV === "production") {
        return safeJsonError(c, 401, "Webhook not configured", "webhook_secret_missing");
      }
    } else {
      const token = authHeader.replace("Bearer ", "").trim();
      if (!token || !constantTimeTokenEquals(token, expected)) {
        return safeJsonError(c, 401, "Invalid webhook auth", "webhook_auth_failed");
      }
    }

    const payload = await c.req.json<RevenueCatWebhookEvent>();
    const eventId = payload.event?.id ?? "unknown";
    const eventType = payload.event?.type ?? "unknown";

    console.log(
      JSON.stringify({
        level: "info",
        requestId: c.get("requestId"),
        message: "revenuecat_webhook_received",
        eventId,
        eventType,
      })
    );

    return c.json({ ok: true }, 200);
  } catch (error) {
    return safeJsonError(c, 500, "Unexpected server error", "webhook_handler", error);
  }
});
