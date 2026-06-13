import type { Context } from "hono";
import { Hono } from "hono";
import { getUserId, requireAuth } from "../lib/middleware/requireAuth.js";
import type { AppVariables } from "../lib/middleware/types.js";
import { isUnauthorizedError, safeJsonError } from "../lib/middleware/safeError.js";
import { buildPropertyCapabilities } from "../lib/capabilities.js";
import { requireOwnedProperty } from "../lib/requireOwnedProperty.js";

function handleCapabilitiesError(c: Context<{ Variables: AppVariables }>, error: unknown, logLabel: string) {
  if (isUnauthorizedError(error)) {
    return safeJsonError(c, 401, "Unauthorized", logLabel);
  }
  return safeJsonError(c, 500, "Failed to load property capabilities", logLabel, error);
}

export const propertyCapabilitiesRouter = new Hono<{ Variables: AppVariables }>();

propertyCapabilitiesRouter.use("*", requireAuth);

propertyCapabilitiesRouter.get("/:propertyId/capabilities", async (c) => {
  const startedAt = Date.now();

  try {
    const userId = getUserId(c);
    const propertyId = c.req.param("propertyId")?.trim();

    if (!propertyId) {
      return c.json({ error: "Missing propertyId" }, 400);
    }

    const owned = await requireOwnedProperty(userId, propertyId);
    if (!owned) {
      return c.json({ error: "Property not found" }, 404);
    }

    const payload = await buildPropertyCapabilities(userId, propertyId);

    console.log("[properties.capabilities] ok", {
      propertyId,
      totalMs: Date.now() - startedAt,
    });

    return c.json(payload, 200);
  } catch (error) {
    console.error("[properties.capabilities] failed", {
      error: error instanceof Error ? error.message : String(error),
      totalMs: Date.now() - startedAt,
    });

    return handleCapabilitiesError(
      c,
      error,
      "GET /:propertyId/capabilities"
    );
  }
});
