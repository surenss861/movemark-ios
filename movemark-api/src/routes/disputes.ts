import type { Context } from "hono";
import { Hono } from "hono";
import { requireUserIdFromBearer } from "../lib/auth.js";
import { buildDisputeEvidenceCatalog } from "../lib/disputeEvidenceCatalog.js";
import { requireOwnedProperty } from "../lib/requireOwnedProperty.js";

function handleDisputesError(c: Context, error: unknown, logLabel: string) {
  if (error instanceof Error && error.message === "Unauthorized") {
    return c.json({ error: "Unauthorized" }, 401);
  }
  console.error(`[movemark-api:disputes] ${logLabel}`, error);
  return c.json({ error: "Failed to load dispute evidence catalog" }, 500);
}

export const disputesRouter = new Hono();

disputesRouter.get("/:propertyId/evidence-catalog", async (c) => {
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

    const includeSignedUrls = c.req.query("includeSignedUrls") === "true";

    const payload = await buildDisputeEvidenceCatalog(userId, propertyId, {
      includeSignedUrls,
    });

    console.log("[disputes.evidenceCatalog] ok", {
      propertyId,
      totalMs: Date.now() - startedAt,
      photoCount: payload.summary.photoCount,
      maintenanceCount: payload.summary.maintenanceCount,
      documentCount: payload.summary.documentCount,
    });

    return c.json(payload, 200);
  } catch (error) {
    console.error("[disputes.evidenceCatalog] failed", {
      error: error instanceof Error ? error.message : String(error),
      totalMs: Date.now() - startedAt,
    });

    return handleDisputesError(
      c,
      error,
      "GET /:propertyId/evidence-catalog"
    );
  }
});
