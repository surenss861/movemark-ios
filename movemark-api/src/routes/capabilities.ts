import type { Context } from "hono";
import { Hono } from "hono";
import { requireUserIdFromBearer } from "../lib/auth.js";
import { buildPropertyCapabilities } from "../lib/capabilities.js";
import { requireOwnedProperty } from "../lib/requireOwnedProperty.js";

function handleCapabilitiesError(c: Context, error: unknown, logLabel: string) {
  if (error instanceof Error && error.message === "Unauthorized") {
    return c.json({ error: "Unauthorized" }, 401);
  }
  console.error(`[movemark-api:capabilities] ${logLabel}`, error);
  return c.json({ error: "Failed to load property capabilities" }, 500);
}

export const propertyCapabilitiesRouter = new Hono();

propertyCapabilitiesRouter.get("/:propertyId/capabilities", async (c) => {
  const startedAt = Date.now();

  try {
    const userId = await requireUserIdFromBearer(c);
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
