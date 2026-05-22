import type { Context } from "hono";
import { Hono } from "hono";
import { requireUserIdFromBearer } from "../lib/auth.js";
import { env } from "../lib/env.js";
import {
  computeMoveOutProofStats,
  isActiveExportJob,
  isUuidString,
  MOVE_IN_REPORT_TYPE,
  MOVE_OUT_REPORT_TYPE,
} from "../lib/exportGuards.js";
import { generateMoveInPdfBuffer, generateMoveOutPdfBuffer } from "../lib/pdf.js";
import { uploadExportToSupabaseStorage } from "../lib/storage.js";
import { supabaseAdmin } from "../lib/supabase.js";
import type {
  ExportDownloadResponseBody,
  ExportListItem,
  ExportRequestBody,
  ExportResponseBody,
} from "../types/exports.js";

async function markExportFailed(exportId: string, reason: string): Promise<void> {
  try {
    const { error } = await supabaseAdmin
      .from("exports")
      .update({ status: "failed" })
      .eq("id", exportId);
    if (error) {
      console.error(`[movemark-api:exports] markExportFailed update error id=${exportId}`, error);
    } else {
      console.log(`[movemark-api:exports] export status=failed id=${exportId} reason=${reason}`);
    }
  } catch (e) {
    console.error(`[movemark-api:exports] markExportFailed exception id=${exportId}`, e);
  }
}

function handleExportsError(c: Context, error: unknown, logLabel: string) {
  if (error instanceof Error && error.message === "Unauthorized") {
    return c.json({ error: "Unauthorized" }, 401);
  }
  console.error(`[movemark-api:exports] ${logLabel}`, error);
  return c.json({ error: "Unexpected server error" }, 500);
}

export const exportsRouter = new Hono();

exportsRouter.get("/", async (c) => {
  const t0 = performance.now();
  try {
    const userId = await requireUserIdFromBearer(c);
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

exportsRouter.get("/:id/download", async (c) => {
  const t0 = performance.now();
  try {
    const userId = await requireUserIdFromBearer(c);
    const authMs = Math.round(performance.now() - t0);

    const exportId = c.req.param("id");
    if (!exportId) {
      console.log(
        `[movemark-api:exports] GET /:id/download timing authMs=${authMs} totalMs=${Math.round(performance.now() - t0)} status=400`
      );
      return c.json({ error: "Missing export id" }, 400);
    }

    const tRow = performance.now();
    const { data: row, error } = await supabaseAdmin
      .from("exports")
      .select("id,user_id,status,file_path")
      .eq("id", exportId)
      .eq("user_id", userId)
      .single();
    const rowMs = Math.round(performance.now() - tRow);

    if (error || !row) {
      console.log(
        `[movemark-api:exports] GET /:id/download timing authMs=${authMs} rowMs=${rowMs} totalMs=${Math.round(performance.now() - t0)} status=404`
      );
      return c.json({ error: "Export not found" }, 404);
    }
    if (row.status === "failed") {
      console.log(
        `[movemark-api:exports] GET /:id/download timing authMs=${authMs} rowMs=${rowMs} totalMs=${Math.round(performance.now() - t0)} status=400 reason=failed`
      );
      // 400 (not 409) so clients don’t treat this as “still processing” like a queued export.
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
    const userId = await requireUserIdFromBearer(c);
    const body = await c.req.json<ExportRequestBody>();

    if (!body.propertyId || body.format !== "pdf") {
      return c.json({ error: "Invalid request body" }, 400);
    }

    if (!isUuidString(body.propertyId)) {
      return c.json({ error: "Invalid propertyId" }, 400);
    }

    const { data: property, error: propertyError } = await supabaseAdmin
      .from("properties")
      .select("*")
      .eq("id", body.propertyId)
      .eq("user_id", userId)
      .single();

    if (propertyError || !property) {
      return c.json({ error: "Property not found" }, 404);
    }

    const { data: rooms } = await supabaseAdmin
      .from("rooms")
      .select("*")
      .eq("property_id", body.propertyId)
      .order("created_at", { ascending: true });

    const { data: inspection } = await supabaseAdmin
      .from("inspections")
      .select("*")
      .eq("property_id", body.propertyId)
      .eq("user_id", userId)
      .eq("inspection_type", "move_in")
      .maybeSingle();

    let inspectionItems: Array<Record<string, unknown>> = [];
    if (inspection?.id) {
      const { data } = await supabaseAdmin
        .from("inspection_items")
        .select("*")
        .eq("inspection_id", inspection.id)
        .order("created_at", { ascending: true });

      inspectionItems = data ?? [];
    }

    const itemIds = inspectionItems
      .map((row) => row["id"] as string | undefined)
      .filter((id): id is string => Boolean(id));

    const photoCountByItem = new Map<string, number>();
    const tagNamesByItem = new Map<string, string[]>();

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

      const { data: tagLinks } = await supabaseAdmin
        .from("inspection_item_tags")
        .select("inspection_item_id, issue_tags(name)")
        .in("inspection_item_id", itemIds);

      for (const link of tagLinks ?? []) {
        const iid = link.inspection_item_id as string | undefined;
        if (!iid) continue;
        const rel = link.issue_tags as { name?: string } | null;
        const name = rel?.name?.trim();
        if (!name) continue;
        const list = tagNamesByItem.get(iid) ?? [];
        list.push(name);
        tagNamesByItem.set(iid, list);
      }
    }

    const inspectionItemsForPdf = inspectionItems.map((row) => {
      const id = row["id"] as string | undefined;
      if (!id) return row;
      return {
        ...row,
        pdf_photo_count: photoCountByItem.get(id) ?? 0,
        pdf_issue_tag_names: tagNamesByItem.get(id) ?? [],
      };
    });

    const { data: propertyDocuments } = await supabaseAdmin
      .from("property_documents")
      .select("*")
      .eq("property_id", body.propertyId)
      .eq("user_id", userId)
      .order("uploaded_at", { ascending: true });

    const requestedAt = new Date().toISOString();

    const { data: exportRow, error: exportInsertError } = await supabaseAdmin
      .from("exports")
      .insert({
        user_id: userId,
        property_id: body.propertyId,
        export_type: MOVE_IN_REPORT_TYPE,
        status: "queued",
        requested_at: requestedAt,
      })
      .select("*")
      .single();

    if (exportInsertError || !exportRow) {
      return c.json({ error: "Failed to create export row" }, 500);
    }

    try {
      const pdfBuffer = await generateMoveInPdfBuffer({
        property,
        rooms: rooms ?? [],
        inspection: inspection ?? null,
        inspectionItems: inspectionItemsForPdf,
        propertyDocuments: propertyDocuments ?? [],
      });

      const upload = await uploadExportToSupabaseStorage({
        userId,
        exportId: exportRow.id,
        fileBuffer: pdfBuffer,
      });

      const { error: updateError } = await supabaseAdmin
        .from("exports")
        .update({
          status: "completed",
          file_path: upload.path,
          completed_at: new Date().toISOString(),
        })
        .eq("id", exportRow.id);

      if (updateError) {
        console.error("[movemark-api:exports] move-in finalize", updateError);
        throw new Error(`finalize: ${updateError.message}`);
      }

      const response: ExportResponseBody = {
        exportId: exportRow.id,
        status: "completed",
        type: MOVE_IN_REPORT_TYPE,
        requestedAt:
          (exportRow.requested_at as string | undefined) ??
          (exportRow.created_at as string | undefined) ??
          requestedAt,
      };

      return c.json(response, 200);
    } catch (pipelineError) {
      const msg = pipelineError instanceof Error ? pipelineError.message : String(pipelineError);
      console.error("[movemark-api:exports] POST /move-in pipeline failed", pipelineError);
      await markExportFailed(exportRow.id, msg);
      return c.json(
        { error: "Export generation failed", code: "export_generation_failed" },
        500
      );
    }
  } catch (error) {
    return handleExportsError(c, error, "POST /move-in");
  }
});

exportsRouter.post("/move-out", async (c) => {
  try {
    const userId = await requireUserIdFromBearer(c);
    const body = await c.req.json<ExportRequestBody>();

    if (!body.propertyId || body.format !== "pdf") {
      return c.json({ error: "Invalid request body" }, 400);
    }

    if (!isUuidString(body.propertyId)) {
      return c.json({ error: "Invalid propertyId" }, 400);
    }

    const { data: property, error: propertyError } = await supabaseAdmin
      .from("properties")
      .select("*")
      .eq("id", body.propertyId)
      .eq("user_id", userId)
      .single();

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
        { error: "A move-out report is already being built.", code: "export_already_processing" },
        409
      );
    }

    const { data: rooms } = await supabaseAdmin
      .from("rooms")
      .select("*")
      .eq("property_id", body.propertyId)
      .order("created_at", { ascending: true });

    const { data: inspection } = await supabaseAdmin
      .from("inspections")
      .select("*")
      .eq("property_id", body.propertyId)
      .eq("user_id", userId)
      .eq("inspection_type", "move_out")
      .maybeSingle();

    let inspectionItems: Array<Record<string, unknown>> = [];
    if (inspection?.id) {
      const { data } = await supabaseAdmin
        .from("inspection_items")
        .select("*")
        .eq("inspection_id", inspection.id)
        .order("created_at", { ascending: true });

      inspectionItems = data ?? [];
    }

    const itemIds = inspectionItems
      .map((row) => row["id"] as string | undefined)
      .filter((id): id is string => Boolean(id));

    const photoCountByItem = new Map<string, number>();
    const tagNamesByItem = new Map<string, string[]>();

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

      const { data: tagLinks } = await supabaseAdmin
        .from("inspection_item_tags")
        .select("inspection_item_id, issue_tags(name)")
        .in("inspection_item_id", itemIds);

      for (const link of tagLinks ?? []) {
        const iid = link.inspection_item_id as string | undefined;
        if (!iid) continue;
        const rel = link.issue_tags as { name?: string } | null;
        const name = rel?.name?.trim();
        if (!name) continue;
        const list = tagNamesByItem.get(iid) ?? [];
        list.push(name);
        tagNamesByItem.set(iid, list);
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

    const inspectionItemsForPdf = inspectionItems.map((row) => {
      const id = row["id"] as string | undefined;
      if (!id) return row;
      return {
        ...row,
        pdf_photo_count: photoCountByItem.get(id) ?? 0,
        pdf_issue_tag_names: tagNamesByItem.get(id) ?? [],
      };
    });

    const requestedAt = new Date().toISOString();

    const { data: exportRow, error: exportInsertError } = await supabaseAdmin
      .from("exports")
      .insert({
        user_id: userId,
        property_id: body.propertyId,
        export_type: MOVE_OUT_REPORT_TYPE,
        status: "queued",
        requested_at: requestedAt,
      })
      .select("*")
      .single();

    if (exportInsertError || !exportRow) {
      return c.json({ error: "Failed to create export row" }, 500);
    }

    try {
      const pdfBuffer = await generateMoveOutPdfBuffer({
        property,
        rooms: rooms ?? [],
        inspection: inspection ?? null,
        inspectionItems: inspectionItemsForPdf,
      });

      const upload = await uploadExportToSupabaseStorage({
        userId,
        exportId: exportRow.id,
        fileBuffer: pdfBuffer,
      });

      const { error: updateError } = await supabaseAdmin
        .from("exports")
        .update({
          status: "completed",
          file_path: upload.path,
          completed_at: new Date().toISOString(),
        })
        .eq("id", exportRow.id);

      if (updateError) {
        console.error("[movemark-api:exports] move-out finalize", updateError);
        throw new Error(`finalize: ${updateError.message}`);
      }

      const response: ExportResponseBody = {
        exportId: exportRow.id,
        status: "completed",
        type: MOVE_OUT_REPORT_TYPE,
        requestedAt:
          (exportRow.requested_at as string | undefined) ??
          (exportRow.created_at as string | undefined) ??
          requestedAt,
      };

      return c.json(response, 200);
    } catch (pipelineError) {
      const msg = pipelineError instanceof Error ? pipelineError.message : String(pipelineError);
      console.error("[movemark-api:exports] POST /move-out pipeline failed", pipelineError);
      await markExportFailed(exportRow.id, msg);
      return c.json(
        { error: "Move-out report generation failed", code: "export_generation_failed" },
        500
      );
    }
  } catch (error) {
    return handleExportsError(c, error, "POST /move-out");
  }
});
