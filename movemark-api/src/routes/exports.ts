import type { Context } from "hono";
import { Hono } from "hono";
import { getUserId, requireAuth } from "../lib/middleware/requireAuth.js";
import {
  checkExportCreateRateLimit,
  rateLimitExportDownloadByUser,
  rateLimitExportsListByUser,
} from "../lib/middleware/rateLimit.js";
import type { AppVariables } from "../lib/middleware/types.js";
import { isUnauthorizedError, safeJsonError } from "../lib/middleware/safeError.js";
import { requireOwnedExport } from "../lib/requireOwnedExport.js";
import { env } from "../lib/env.js";
import { assertCanEnqueueExport } from "../lib/entitlements.js";
import {
  computeMoveInProofStats,
  computeMoveOutProofStats,
  DISPUTE_PACKET_TYPE,
  isActiveExportJob,
  isUuidString,
  MOVE_IN_REPORT_TYPE,
  MOVE_OUT_REPORT_TYPE,
} from "../lib/exportGuards.js";
import { hasEnoughDisputeProof } from "../lib/disputePacketBuilder.js";
import { supabaseAdmin } from "../lib/supabase.js";
import type {
  ExportDownloadResponseBody,
  ExportListItem,
  ExportReportType,
  ExportRequestBody,
  ExportResponseBody,
} from "../types/exports.js";

function handleExportsError(c: Context<{ Variables: AppVariables }>, error: unknown, logLabel: string) {
  if (isUnauthorizedError(error)) {
    return safeJsonError(c, 401, "Unauthorized", logLabel);
  }
  return safeJsonError(c, 500, "Unexpected server error", logLabel, error);
}

function isUniqueViolation(error: { code?: string; message?: string } | null | undefined): boolean {
  if (!error) return false;
  if (error.code === "23505") return true;
  return (error.message ?? "").toLowerCase().includes("duplicate");
}

async function enqueueExport(input: {
  userId: string;
  propertyId: string;
  exportType: ExportReportType;
}): Promise<
  | { ok: true; exportId: string; requestedAt: string }
  | { ok: false; status: 409 | 500; code?: string; message: string }
> {
  const requestedAt = new Date().toISOString();
  const { data: exportRow, error: exportInsertError } = await supabaseAdmin
    .from("exports")
    .insert({
      user_id: input.userId,
      property_id: input.propertyId,
      export_type: input.exportType,
      status: "queued",
      requested_at: requestedAt,
      updated_at: requestedAt,
    })
    .select("id,requested_at,created_at")
    .single();

  if (isUniqueViolation(exportInsertError)) {
    return {
      ok: false,
      status: 409,
      code: "export_already_active",
      message: "An export is already being prepared for this property.",
    };
  }

  if (exportInsertError || !exportRow) {
    console.error("[movemark-api:exports] enqueue insert failed", exportInsertError);
    return { ok: false, status: 500, message: "Failed to create export row" };
  }

  return {
    ok: true,
    exportId: exportRow.id as string,
    requestedAt:
      (exportRow.requested_at as string | undefined) ??
      (exportRow.created_at as string | undefined) ??
      requestedAt,
  };
}

function queuedResponse(
  exportId: string,
  type: ExportReportType,
  requestedAt: string
): ExportResponseBody {
  return { exportId, status: "queued", type, requestedAt };
}

export const exportsRouter = new Hono<{ Variables: AppVariables }>();

exportsRouter.use("*", requireAuth);

exportsRouter.get("/", rateLimitExportsListByUser(), async (c) => {
  const t0 = performance.now();
  try {
    const userId = getUserId(c);
    const authMs = Math.round(performance.now() - t0);

    const propertyIdFilter = c.req.query("propertyId")?.trim();

    if (!propertyIdFilter) {
      console.log(
        `[movemark-api:exports] GET / timing authMs=${authMs} totalMs=${Math.round(performance.now() - t0)} status=400 reason=missing_propertyId`
      );
      return c.json({ error: "propertyId query parameter is required" }, 400);
    }

    if (!isUuidString(propertyIdFilter)) {
      return c.json({ error: "Invalid propertyId" }, 400);
    }

    const { data: ownedProperty, error: propErr } = await supabaseAdmin
      .from("properties")
      .select("id")
      .eq("id", propertyIdFilter)
      .eq("user_id", userId)
      .maybeSingle();

    if (propErr) {
      console.error("[movemark-api:exports] GET / property lookup", propErr);
      return c.json({ error: "Failed to verify property" }, 500);
    }
    if (!ownedProperty) {
      return c.json({ error: "Property not found" }, 404);
    }

    let query = supabaseAdmin
      .from("exports")
      .select("id,user_id,property_id,export_type,status,requested_at,completed_at,file_path,created_at")
      .eq("user_id", userId);

    if (propertyIdFilter) {
      query = query.eq("property_id", propertyIdFilter);
    }

    const tDb = performance.now();
    const { data, error } = await query.order("created_at", { ascending: false });
    const dbMs = Math.round(performance.now() - tDb);
    const totalMs = Math.round(performance.now() - t0);

    if (error) {
      console.error("[movemark-api:exports] list query failed", {
        userId,
        message: error.message,
        code: error.code,
        details: error.details,
        hint: error.hint,
      });
      console.log(
        `[movemark-api:exports] GET / timing authMs=${authMs} dbMs=${dbMs} totalMs=${totalMs} status=500 query_error=1`
      );
      return c.json({ error: "Failed to load exports" }, 500);
    }

    const rows: ExportListItem[] = (data ?? []).map((row) => ({
      id: row.id,
      userId: row.user_id,
      propertyId: row.property_id,
      type: row.export_type,
      status: row.status,
      requestedAt: row.requested_at ?? row.created_at ?? null,
      completedAt: row.completed_at ?? null,
      filePath: row.file_path,
      createdAt: row.created_at,
    }));

    console.log(
      `[movemark-api:exports] GET / timing authMs=${authMs} dbMs=${dbMs} totalMs=${totalMs} status=200 rows=${rows.length}`
    );
    return c.json(rows, 200);
  } catch (error) {
    const totalMs = Math.round(performance.now() - t0);
    if (error instanceof Error && error.message === "Unauthorized") {
      console.log(
        `[movemark-api:exports] GET / timing totalMs=${totalMs} status=401 (auth failed before user id)`
      );
    }
    return handleExportsError(c, error, "GET /");
  }
});

exportsRouter.get("/:id/download", rateLimitExportDownloadByUser(), async (c) => {
  const t0 = performance.now();
  try {
    const userId = getUserId(c);
    const authMs = Math.round(performance.now() - t0);

    const exportId = c.req.param("id");
    if (!exportId) {
      console.log(
        `[movemark-api:exports] GET /:id/download timing authMs=${authMs} totalMs=${Math.round(performance.now() - t0)} status=400`
      );
      return c.json({ error: "Missing export id" }, 400);
    }

    const tRow = performance.now();
    const row = await requireOwnedExport(userId, exportId);
    const rowMs = Math.round(performance.now() - tRow);

    if (!row) {
      console.log(
        `[movemark-api:exports] GET /:id/download timing authMs=${authMs} rowMs=${rowMs} totalMs=${Math.round(performance.now() - t0)} status=404`
      );
      return c.json({ error: "Export not found" }, 404);
    }
    if (row.status === "failed") {
      console.log(
        `[movemark-api:exports] GET /:id/download timing authMs=${authMs} rowMs=${rowMs} totalMs=${Math.round(performance.now() - t0)} status=400 reason=failed`
      );
      return c.json({ error: "Export failed", code: "export_failed" }, 400);
    }
    if (row.status !== "completed") {
      console.log(
        `[movemark-api:exports] GET /:id/download timing authMs=${authMs} rowMs=${rowMs} totalMs=${Math.round(performance.now() - t0)} status=409`
      );
      return c.json({ error: "Export is not ready yet" }, 409);
    }
    if (!row.file_path) {
      console.log(
        `[movemark-api:exports] GET /:id/download timing authMs=${authMs} rowMs=${rowMs} totalMs=${Math.round(performance.now() - t0)} status=500 missing_path`
      );
      return c.json({ error: "Export file path missing" }, 500);
    }

    const tSign = performance.now();
    const { data: signed, error: signedError } = await supabaseAdmin.storage
      .from(env.EXPORT_BUCKET_NAME)
      .createSignedUrl(row.file_path, 60 * 15);
    const signedMs = Math.round(performance.now() - tSign);
    const totalMs = Math.round(performance.now() - t0);

    if (signedError || !signed?.signedUrl) {
      console.error("[movemark-api:exports] signed URL", signedError);
      console.log(
        `[movemark-api:exports] GET /:id/download timing authMs=${authMs} rowMs=${rowMs} signedUrlMs=${signedMs} totalMs=${totalMs} status=500 signed_url_error`
      );
      return c.json({ error: "Failed to prepare download" }, 500);
    }

    console.log(
      `[movemark-api:exports] GET /:id/download timing authMs=${authMs} rowMs=${rowMs} signedUrlMs=${signedMs} totalMs=${totalMs} status=200`
    );
    const response: ExportDownloadResponseBody = {
      exportId: row.id,
      status: row.status,
      downloadUrl: signed.signedUrl,
      expiresInSeconds: 900,
    };
    return c.json(response, 200);
  } catch (error) {
    const totalMs = Math.round(performance.now() - t0);
    if (error instanceof Error && error.message === "Unauthorized") {
      console.log(
        `[movemark-api:exports] GET /:id/download timing totalMs=${totalMs} status=401`
      );
    }
    return handleExportsError(c, error, "GET /:id/download");
  }
});

exportsRouter.post("/move-in", async (c) => {
  try {
    const userId = getUserId(c);
    const body = await c.req.json<ExportRequestBody>();

    if (!body.propertyId || body.format !== "pdf") {
      return c.json({ error: "Invalid request body" }, 400);
    }
    if (!isUuidString(body.propertyId)) {
      return c.json({ error: "Invalid propertyId" }, 400);
    }

    const entitlement = await assertCanEnqueueExport(userId, MOVE_IN_REPORT_TYPE);
    if (!entitlement.ok) {
      return c.json(
        { error: entitlement.message, code: entitlement.code },
        entitlement.status
      );
    }

    const createLimit = await checkExportCreateRateLimit(userId, body.propertyId, "move_in");
    if (!createLimit.allowed) {
      c.header("Retry-After", String(createLimit.retryAfterSec));
      return c.json({ error: "Too many export requests for this property" }, 429);
    }

    const { data: property, error: propertyError } = await supabaseAdmin
      .from("properties")
      .select("id")
      .eq("id", body.propertyId)
      .eq("user_id", userId)
      .maybeSingle();

    if (propertyError || !property) {
      return c.json({ error: "Property not found" }, 404);
    }

    const { data: existingExports } = await supabaseAdmin
      .from("exports")
      .select("id,status,file_path")
      .eq("user_id", userId)
      .eq("property_id", body.propertyId)
      .eq("export_type", MOVE_IN_REPORT_TYPE)
      .order("created_at", { ascending: false })
      .limit(5);

    const active = (existingExports ?? []).find((row) =>
      isActiveExportJob({ status: row.status as string, file_path: row.file_path as string | null })
    );
    if (active) {
      return c.json(
        {
          error: "A move-in report is already being prepared.",
          code: "export_already_active",
        },
        409
      );
    }

    const enqueued = await enqueueExport({
      userId,
      propertyId: body.propertyId,
      exportType: MOVE_IN_REPORT_TYPE,
    });
    if (!enqueued.ok) {
      return c.json(
        { error: enqueued.message, code: enqueued.code },
        enqueued.status
      );
    }

    return c.json(queuedResponse(enqueued.exportId, MOVE_IN_REPORT_TYPE, enqueued.requestedAt), 202);
  } catch (error) {
    return handleExportsError(c, error, "POST /move-in");
  }
});

exportsRouter.post("/move-out", async (c) => {
  try {
    const userId = getUserId(c);
    const body = await c.req.json<ExportRequestBody>();

    if (!body.propertyId || body.format !== "pdf") {
      return c.json({ error: "Invalid request body" }, 400);
    }
    if (!isUuidString(body.propertyId)) {
      return c.json({ error: "Invalid propertyId" }, 400);
    }

    const entitlement = await assertCanEnqueueExport(userId, MOVE_OUT_REPORT_TYPE);
    if (!entitlement.ok) {
      return c.json(
        { error: entitlement.message, code: entitlement.code },
        entitlement.status
      );
    }

    const createLimit = await checkExportCreateRateLimit(userId, body.propertyId, "move_out");
    if (!createLimit.allowed) {
      c.header("Retry-After", String(createLimit.retryAfterSec));
      return c.json({ error: "Too many export requests for this property" }, 429);
    }

    const { data: property, error: propertyError } = await supabaseAdmin
      .from("properties")
      .select("id")
      .eq("id", body.propertyId)
      .eq("user_id", userId)
      .maybeSingle();

    if (propertyError || !property) {
      return c.json({ error: "Property not found" }, 404);
    }

    const { data: existingExports } = await supabaseAdmin
      .from("exports")
      .select("id,status,file_path,export_type")
      .eq("user_id", userId)
      .eq("property_id", body.propertyId)
      .eq("export_type", MOVE_OUT_REPORT_TYPE)
      .order("created_at", { ascending: false })
      .limit(5);

    const activeMoveOut = (existingExports ?? []).find((row) =>
      isActiveExportJob({ status: row.status as string, file_path: row.file_path as string | null })
    );
    if (activeMoveOut) {
      return c.json(
        {
          error: "A move-out report is already being built.",
          code: "export_already_active",
        },
        409
      );
    }

    const { data: inspection } = await supabaseAdmin
      .from("inspections")
      .select("id")
      .eq("property_id", body.propertyId)
      .eq("user_id", userId)
      .eq("inspection_type", "move_out")
      .maybeSingle();

    let inspectionItems: Array<Record<string, unknown>> = [];
    if (inspection?.id) {
      const { data } = await supabaseAdmin
        .from("inspection_items")
        .select("id,room_id")
        .eq("inspection_id", inspection.id);
      inspectionItems = data ?? [];
    }

    const itemIds = inspectionItems
      .map((row) => row["id"] as string | undefined)
      .filter((id): id is string => Boolean(id));
    const photoCountByItem = new Map<string, number>();
    if (itemIds.length > 0) {
      const { data: evidenceRows } = await supabaseAdmin
        .from("evidence_files")
        .select("inspection_item_id")
        .eq("property_id", body.propertyId)
        .in("inspection_item_id", itemIds);
      for (const er of evidenceRows ?? []) {
        const iid = er.inspection_item_id as string | undefined;
        if (!iid) continue;
        photoCountByItem.set(iid, (photoCountByItem.get(iid) ?? 0) + 1);
      }
    }

    const proofStats = computeMoveOutProofStats(inspectionItems, photoCountByItem);
    if (proofStats.documentedRooms === 0 || proofStats.totalPhotos === 0) {
      return c.json(
        {
          error: "Capture move-out proof for at least one room before making a report.",
          code: "not_enough_move_out_proof",
        },
        400
      );
    }

    const enqueued = await enqueueExport({
      userId,
      propertyId: body.propertyId,
      exportType: MOVE_OUT_REPORT_TYPE,
    });
    if (!enqueued.ok) {
      return c.json(
        { error: enqueued.message, code: enqueued.code },
        enqueued.status
      );
    }

    return c.json(queuedResponse(enqueued.exportId, MOVE_OUT_REPORT_TYPE, enqueued.requestedAt), 202);
  } catch (error) {
    return handleExportsError(c, error, "POST /move-out");
  }
});

exportsRouter.post("/dispute-packet", async (c) => {
  try {
    const userId = getUserId(c);
    const body = await c.req.json<ExportRequestBody>();

    if (!body.propertyId || body.format !== "pdf") {
      return c.json({ error: "Invalid request body" }, 400);
    }
    if (!isUuidString(body.propertyId)) {
      return c.json({ error: "Invalid propertyId" }, 400);
    }

    const entitlement = await assertCanEnqueueExport(userId, DISPUTE_PACKET_TYPE);
    if (!entitlement.ok) {
      return c.json(
        { error: entitlement.message, code: entitlement.code },
        entitlement.status
      );
    }

    const createLimit = await checkExportCreateRateLimit(
      userId,
      body.propertyId,
      "dispute_packet"
    );
    if (!createLimit.allowed) {
      c.header("Retry-After", String(createLimit.retryAfterSec));
      return c.json({ error: "Too many export requests for this property" }, 429);
    }

    const { data: property, error: propertyError } = await supabaseAdmin
      .from("properties")
      .select("id")
      .eq("id", body.propertyId)
      .eq("user_id", userId)
      .maybeSingle();

    if (propertyError || !property) {
      return c.json({ error: "Property not found" }, 404);
    }

    const { data: propertyExports } = await supabaseAdmin
      .from("exports")
      .select("id,status,file_path,export_type,completed_at,requested_at,created_at")
      .eq("user_id", userId)
      .eq("property_id", body.propertyId)
      .order("created_at", { ascending: false })
      .limit(20);

    const exportRows = propertyExports ?? [];

    const activeDispute = exportRows
      .filter((row) => row.export_type === DISPUTE_PACKET_TYPE)
      .find((row) =>
        isActiveExportJob({
          status: row.status as string,
          file_path: row.file_path as string | null,
        })
      );
    if (activeDispute) {
      return c.json(
        {
          error: "A dispute packet is already being built.",
          code: "export_already_active",
        },
        409
      );
    }

    const { data: moveInInspection } = await supabaseAdmin
      .from("inspections")
      .select("id")
      .eq("property_id", body.propertyId)
      .eq("user_id", userId)
      .eq("inspection_type", "move_in")
      .maybeSingle();

    let moveInItems: Array<Record<string, unknown>> = [];
    const photoCountByMoveInItem = new Map<string, number>();

    if (moveInInspection?.id) {
      const { data: items } = await supabaseAdmin
        .from("inspection_items")
        .select("id,room_id")
        .eq("inspection_id", moveInInspection.id);

      moveInItems = items ?? [];
      const itemIds = moveInItems
        .map((row) => row["id"] as string | undefined)
        .filter((id): id is string => Boolean(id));

      if (itemIds.length > 0) {
        const { data: evidenceRows } = await supabaseAdmin
          .from("evidence_files")
          .select("inspection_item_id")
          .eq("property_id", body.propertyId)
          .in("inspection_item_id", itemIds);

        for (const er of evidenceRows ?? []) {
          const iid = er.inspection_item_id as string | undefined;
          if (!iid) continue;
          photoCountByMoveInItem.set(iid, (photoCountByMoveInItem.get(iid) ?? 0) + 1);
        }
      }
    }

    const moveInStats = computeMoveInProofStats(moveInItems, photoCountByMoveInItem);

    if (
      !hasEnoughDisputeProof(
        moveInStats.documentedRooms,
        moveInStats.totalPhotos,
        exportRows as Array<{
          export_type: string;
          status: string;
          file_path?: string | null;
          completed_at?: string | null;
          requested_at?: string | null;
          created_at?: string | null;
        }>
      )
    ) {
      return c.json(
        {
          error: "Add move-in room proof or a move-in report before building a dispute packet.",
          code: "not_enough_dispute_proof",
        },
        400
      );
    }

    const enqueued = await enqueueExport({
      userId,
      propertyId: body.propertyId,
      exportType: DISPUTE_PACKET_TYPE,
    });
    if (!enqueued.ok) {
      return c.json(
        { error: enqueued.message, code: enqueued.code },
        enqueued.status
      );
    }

    return c.json(queuedResponse(enqueued.exportId, DISPUTE_PACKET_TYPE, enqueued.requestedAt), 202);
  } catch (error) {
    return handleExportsError(c, error, "POST /dispute-packet");
  }
});
