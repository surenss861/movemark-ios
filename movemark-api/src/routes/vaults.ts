import type { Context } from "hono";
import { Hono } from "hono";
import { requireUserIdFromBearer } from "../lib/auth.js";
import { buildVaultSummary } from "../lib/vaultSummary.js";
import { requireOwnedProperty } from "../lib/requireOwnedProperty.js";

function handleVaultError(c: Context, error: unknown, logLabel: string) {
  if (error instanceof Error && error.message === "Unauthorized") {
    return c.json({ error: "Unauthorized" }, 401);
  }
  console.error(`[movemark-api:vaults] ${logLabel}`, error);
  return c.json({ error: "Failed to load vault summary" }, 500);
}

export const vaultsRouter = new Hono();

vaultsRouter.get("/:propertyId/summary", async (c) => {
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

    const includeExports = c.req.query("includeExports") === "true";
    const includeDispute = c.req.query("includeDispute") === "true";

    const payload = await buildVaultSummary(userId, propertyId, {
      includeExports,
      includeDispute,
    });

    console.log("[vaults.summary] ok", {
      propertyId,
      totalMs: Date.now() - startedAt,
    });

    return c.json(payload, 200);
  } catch (error) {
    console.error("[vaults.summary] failed", {
      error: error instanceof Error ? error.message : String(error),
      totalMs: Date.now() - startedAt,
    });

    return handleVaultError(c, error, "GET /:propertyId/summary");
  }
});
