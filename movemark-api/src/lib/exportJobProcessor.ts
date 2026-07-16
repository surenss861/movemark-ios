import { mapWithConcurrency } from "./concurrency.js";
import { buildDisputeEvidenceCatalog } from "./disputeEvidenceCatalog.js";
import {
  buildDisputePacketChecklist,
  hasEnoughDisputeProof,
} from "./disputePacketBuilder.js";
import {
  computeMoveInProofStats,
  DISPUTE_PACKET_TYPE,
  MOVE_IN_REPORT_TYPE,
  MOVE_OUT_REPORT_TYPE,
} from "./exportGuards.js";
import {
  generateDisputePacketPdfBuffer,
  generateMoveInPdfBuffer,
  generateMoveOutPdfBuffer,
} from "./pdf.js";
import { loadInspectionEvidencePhotos } from "./pdfEvidence.js";
import { uploadExportToSupabaseStorage } from "./storage.js";
import { supabaseAdmin } from "./supabase.js";

export type ExportJobRow = {
  id: string;
  user_id: string;
  property_id: string;
  export_type: string;
  attempts: number;
};

async function markFailed(exportId: string, reason: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from("exports")
    .update({
      status: "failed",
      error_message: reason.slice(0, 2000),
      updated_at: new Date().toISOString(),
      locked_at: null,
    })
    .eq("id", exportId);
  if (error) {
    console.error(`[movemark-api:exportJob] markFailed id=${exportId}`, error);
  }
}

async function markCompleted(exportId: string, filePath: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from("exports")
    .update({
      status: "completed",
      file_path: filePath,
      completed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      locked_at: null,
      error_message: null,
    })
    .eq("id", exportId);
  if (error) {
    throw new Error(`finalize_failed:${error.message}`);
  }
}

async function loadTagNamesByItem(itemIds: string[]): Promise<Map<string, string[]>> {
  const tagNamesByItem = new Map<string, string[]>();
  if (itemIds.length === 0) return tagNamesByItem;

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
  return tagNamesByItem;
}

async function processMoveIn(job: ExportJobRow): Promise<void> {
  const { data: property, error: propertyError } = await supabaseAdmin
    .from("properties")
    .select("*")
    .eq("id", job.property_id)
    .eq("user_id", job.user_id)
    .single();
  if (propertyError || !property) throw new Error("property_not_found");

  const { data: rooms } = await supabaseAdmin
    .from("rooms")
    .select("*")
    .eq("property_id", job.property_id)
    .order("created_at", { ascending: true });

  const { data: inspection } = await supabaseAdmin
    .from("inspections")
    .select("*")
    .eq("property_id", job.property_id)
    .eq("user_id", job.user_id)
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
  if (itemIds.length > 0) {
    const { data: evidenceRows } = await supabaseAdmin
      .from("evidence_files")
      .select("inspection_item_id")
      .eq("property_id", job.property_id)
      .in("inspection_item_id", itemIds);
    for (const er of evidenceRows ?? []) {
      const iid = er.inspection_item_id as string | undefined;
      if (!iid) continue;
      photoCountByItem.set(iid, (photoCountByItem.get(iid) ?? 0) + 1);
    }
  }

  const tagNamesByItem = await loadTagNamesByItem(itemIds);
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
    .eq("property_id", job.property_id)
    .eq("user_id", job.user_id)
    .order("uploaded_at", { ascending: true });

  const evidencePhotos = await loadInspectionEvidencePhotos(
    job.property_id,
    inspectionItems,
    tagNamesByItem
  );

  const pdfBuffer = await generateMoveInPdfBuffer({
    property,
    rooms: rooms ?? [],
    inspection: inspection ?? null,
    inspectionItems: inspectionItemsForPdf,
    propertyDocuments: propertyDocuments ?? [],
    evidencePhotos,
  });

  const upload = await uploadExportToSupabaseStorage({
    userId: job.user_id,
    exportId: job.id,
    fileBuffer: pdfBuffer,
  });
  await markCompleted(job.id, upload.path);
}

async function processMoveOut(job: ExportJobRow): Promise<void> {
  const { data: property, error: propertyError } = await supabaseAdmin
    .from("properties")
    .select("*")
    .eq("id", job.property_id)
    .eq("user_id", job.user_id)
    .single();
  if (propertyError || !property) throw new Error("property_not_found");

  const { data: rooms } = await supabaseAdmin
    .from("rooms")
    .select("*")
    .eq("property_id", job.property_id)
    .order("created_at", { ascending: true });

  const { data: inspection } = await supabaseAdmin
    .from("inspections")
    .select("*")
    .eq("property_id", job.property_id)
    .eq("user_id", job.user_id)
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
  if (itemIds.length > 0) {
    const { data: evidenceRows } = await supabaseAdmin
      .from("evidence_files")
      .select("inspection_item_id")
      .eq("property_id", job.property_id)
      .in("inspection_item_id", itemIds);
    for (const er of evidenceRows ?? []) {
      const iid = er.inspection_item_id as string | undefined;
      if (!iid) continue;
      photoCountByItem.set(iid, (photoCountByItem.get(iid) ?? 0) + 1);
    }
  }

  const tagNamesByItem = await loadTagNamesByItem(itemIds);
  const inspectionItemsForPdf = inspectionItems.map((row) => {
    const id = row["id"] as string | undefined;
    if (!id) return row;
    return {
      ...row,
      pdf_photo_count: photoCountByItem.get(id) ?? 0,
      pdf_issue_tag_names: tagNamesByItem.get(id) ?? [],
    };
  });

  const evidencePhotos = await loadInspectionEvidencePhotos(
    job.property_id,
    inspectionItems,
    tagNamesByItem
  );

  const pdfBuffer = await generateMoveOutPdfBuffer({
    property,
    rooms: rooms ?? [],
    inspection: inspection ?? null,
    inspectionItems: inspectionItemsForPdf,
    evidencePhotos,
  });

  const upload = await uploadExportToSupabaseStorage({
    userId: job.user_id,
    exportId: job.id,
    fileBuffer: pdfBuffer,
  });
  await markCompleted(job.id, upload.path);
}

async function processDisputePacket(job: ExportJobRow): Promise<void> {
  const { data: property, error: propertyError } = await supabaseAdmin
    .from("properties")
    .select("*")
    .eq("id", job.property_id)
    .eq("user_id", job.user_id)
    .single();
  if (propertyError || !property) throw new Error("property_not_found");

  const { data: propertyExports } = await supabaseAdmin
    .from("exports")
    .select("id,status,file_path,export_type,completed_at,requested_at,created_at")
    .eq("user_id", job.user_id)
    .eq("property_id", job.property_id)
    .order("created_at", { ascending: false })
    .limit(20);

  const exportRows = propertyExports ?? [];

  const { data: moveInInspection } = await supabaseAdmin
    .from("inspections")
    .select("id")
    .eq("property_id", job.property_id)
    .eq("user_id", job.user_id)
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
        .eq("property_id", job.property_id)
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
    throw new Error("not_enough_dispute_proof");
  }

  const catalog = await buildDisputeEvidenceCatalog(job.user_id, job.property_id);
  const checklist = buildDisputePacketChecklist(
    catalog,
    exportRows as Array<{
      export_type: string;
      status: string;
      file_path?: string | null;
      completed_at?: string | null;
      requested_at?: string | null;
      created_at?: string | null;
    }>,
    moveInStats.documentedRooms
  );

  const pdfBuffer = await generateDisputePacketPdfBuffer({ property, checklist });
  const upload = await uploadExportToSupabaseStorage({
    userId: job.user_id,
    exportId: job.id,
    fileBuffer: pdfBuffer,
  });
  await markCompleted(job.id, upload.path);
}

/** Run PDF pipeline for a claimed export job. Marks failed on error. */
export async function processExportJob(job: ExportJobRow): Promise<void> {
  const t0 = performance.now();
  console.log(
    `[movemark-api:exportJob] start id=${job.id} type=${job.export_type} attempt=${job.attempts}`
  );
  try {
    switch (job.export_type) {
      case MOVE_IN_REPORT_TYPE:
        await processMoveIn(job);
        break;
      case MOVE_OUT_REPORT_TYPE:
        await processMoveOut(job);
        break;
      case DISPUTE_PACKET_TYPE:
        await processDisputePacket(job);
        break;
      default:
        throw new Error(`unknown_export_type:${job.export_type}`);
    }
    console.log(
      `[movemark-api:exportJob] completed id=${job.id} ms=${Math.round(performance.now() - t0)}`
    );
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error(`[movemark-api:exportJob] failed id=${job.id}`, error);
    await markFailed(job.id, msg);
  }
}

/** Claim up to `limit` queued jobs (sequential claims for SKIP LOCKED safety). */
export async function claimExportJobs(limit: number): Promise<ExportJobRow[]> {
  const claimed: ExportJobRow[] = [];
  for (let i = 0; i < limit; i++) {
    const { data, error } = await supabaseAdmin.rpc("claim_next_export_job");
    if (error) {
      console.error("[movemark-api:exportJob] claim_next_export_job", error);
      break;
    }
    const rows = (Array.isArray(data) ? data : data ? [data] : []) as ExportJobRow[];
    if (rows.length === 0) break;
    claimed.push(...rows);
  }
  return claimed;
}

export async function reapStuckExportJobs(): Promise<number> {
  const { data, error } = await supabaseAdmin.rpc("reap_stuck_export_jobs");
  if (error) {
    console.error("[movemark-api:exportJob] reap_stuck_export_jobs", error);
    return 0;
  }
  return typeof data === "number" ? data : 0;
}

/** Process claimed jobs with bounded concurrency. */
export async function processClaimedJobs(
  jobs: ExportJobRow[],
  concurrency: number
): Promise<void> {
  await mapWithConcurrency(jobs, concurrency, async (job) => {
    await processExportJob(job);
  });
}
