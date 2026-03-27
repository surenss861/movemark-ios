import { Hono } from "hono";
import { env } from "../lib/env.js";
import type { RevenueCatWebhookEvent } from "../types/revenuecat.js";

export const webhooksRouter = new Hono();

webhooksRouter.post("/revenuecat", async (c) => {
  try {
    const authHeader = c.req.header("Authorization") ?? "";
    const expected = env.REVENUECAT_WEBHOOK_SECRET;

    if (expected) {
      const token = authHeader.replace("Bearer ", "").trim();
      if (!token || token !== expected) {
        return c.json({ error: "Invalid webhook auth" }, 401);
      }
    }

    const payload = await c.req.json<RevenueCatWebhookEvent>();
    console.log("RevenueCat webhook received", JSON.stringify(payload));

    return c.json({ ok: true }, 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected webhook error";
    return c.json({ error: message }, 500);
  }
});
