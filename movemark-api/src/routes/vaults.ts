import type { Context } from "hono";
import { Hono } from "hono";
import { getUserId, requireAuth } from "../lib/middleware/requireAuth.js";
import type { AppVariables } from "../lib/middleware/types.js";
import { isUnauthorizedError, safeJsonError } from "../lib/middleware/safeError.js";
import { buildVaultSummary } from "../lib/vaultSummary.js";
import { requireOwnedProperty } from "../lib/requireOwnedProperty.js";

function handleVaultError(c: Context<{ Variables: AppVariables }>, error: unknown, logLabel: string) {
  if (isUnauthorizedError(error)) {
    return safeJsonError(c, 401, "Unauthorized", logLabel);
  }
  return safeJsonError(c, 500, "Failed to load vault summary", logLabel, error);
}

export const vaultsRouter = new Hono<{ Variables: AppVariables }>();

vaultsRouter.use("*", requireAuth);

vaultsRouter.get("/:propertyId/summary", async (c) => {
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
