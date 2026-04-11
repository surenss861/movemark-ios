import type {
  DisputeDocumentItem,
  DisputeEvidenceCatalogResponse,
  DisputeMaintenanceIssueItem,
  DisputeRoomPhotoItem,
} from "../types/disputes.js";
import { supabaseAdmin } from "./supabase.js";

export async function buildDisputeEvidenceCatalog(
  userId: string,
  propertyId: string,
  options?: {
    includeSignedUrls?: boolean;
  }
): Promise<DisputeEvidenceCatalogResponse> {
  const includeSignedUrls = options?.includeSignedUrls ?? false;

  const [
    evidenceFilesRes,
    inspectionsRes,
    roomsRes,
    maintenanceRes,
    documentsRes,
  ] = await Promise.all([
    supabaseAdmin
      .from("evidence_files")
      .select(
        "id,inspection_item_id,maintenance_issue_id,file_path,created_at,captured_at"
      )
      .eq("property_id", propertyId),

    supabaseAdmin
      .from("inspections")
      .select("id,inspection_type")
      .eq("property_id", propertyId)
      .eq("user_id", userId),

    supabaseAdmin
      .from("rooms")
      .select("id,name")
      .eq("property_id", propertyId),

    supabaseAdmin
      .from("maintenance_issues")
      .select("id,title,category,status,created_at")
      .eq("property_id", propertyId)
      .eq("user_id", userId),

    supabaseAdmin
      .from("property_documents")
      .select("id,document_type,created_at,file_path")
      .eq("property_id", propertyId)
      .eq("user_id", userId),
  ]);

  for (const res of [
    evidenceFilesRes,
    inspectionsRes,
    roomsRes,
    maintenanceRes,
    documentsRes,
  ]) {
    if (res.error) throw new Error(res.error.message);
  }

  const inspections = inspectionsRes.data ?? [];
  const inspectionIds = inspections.map((i) => i.id);

  let items: Array<{
    id: string;
    inspection_id: string;
    room_id: string | null;
    notes: string | null;
    condition_rating: number | null;
  }> = [];

  if (inspectionIds.length > 0) {
    const { data: itemRows, error: itemsError } = await supabaseAdmin
      .from("inspection_items")
      .select("id,inspection_id,room_id,notes,condition_rating")
      .in("inspection_id", inspectionIds);

    if (itemsError) throw new Error(itemsError.message);
    items = itemRows ?? [];
  }

  let tagRows: Array<{
    inspection_item_id: string;
    issue_tags: { name?: string } | null;
  }> = [];

  const itemIdsForTags = items.map((i) => i.id);
  if (itemIdsForTags.length > 0) {
    const { data: tags, error: tagErr } = await supabaseAdmin
      .from("inspection_item_tags")
      .select("inspection_item_id, issue_tags(name)")
      .in("inspection_item_id", itemIdsForTags);

    if (tagErr) throw new Error(tagErr.message);
    tagRows = (tags ?? []) as typeof tagRows;
  }

  const rooms = roomsRes.data ?? [];
  const evidenceFiles = evidenceFilesRes.data ?? [];
  const maintenance = maintenanceRes.data ?? [];
  const documents = documentsRes.data ?? [];

  const itemById = new Map(items.map((i) => [i.id, i]));
  const roomById = new Map(rooms.map((r) => [r.id, r]));
  const inspectionById = new Map(
    inspections.map((i) => [i.id, i])
  );

  const stageByInspectionItemId = new Map<string, DisputeRoomPhotoItem["stage"]>();
  for (const item of items) {
    const inspection = inspectionById.get(item.inspection_id);
    const stage =
      inspection?.inspection_type === "move_in"
        ? "move_in"
        : inspection?.inspection_type === "move_out"
          ? "move_out"
          : "unknown";
    stageByInspectionItemId.set(item.id, stage);
  }

  const tagMap = new Map<string, string[]>();
  for (const row of tagRows) {
    const itemId = row.inspection_item_id;
    const rel = row.issue_tags;
    const tagName =
      rel && typeof rel === "object" && "name" in rel
        ? (rel as { name?: string }).name?.trim()
        : undefined;
    if (!itemId || !tagName) continue;
    const existing = tagMap.get(itemId) ?? [];
    existing.push(tagName);
    tagMap.set(itemId, existing);
  }

  const roomPhotos: DisputeRoomPhotoItem[] = [];
  for (const file of evidenceFiles) {
    if (!file.inspection_item_id) continue;

    const item = itemById.get(file.inspection_item_id);
    const room = item?.room_id ? roomById.get(item.room_id) : null;
    const stage =
      stageByInspectionItemId.get(file.inspection_item_id) ?? "unknown";

    const capturedAt =
      (file as { captured_at?: string | null }).captured_at ??
      file.created_at ??
      null;

    const label = buildEvidenceLabel({
      roomName: room?.name ?? null,
      entryTitle: item?.notes?.trim() || null,
      stage,
      capturedAt,
    });

    roomPhotos.push({
      evidenceFileId: file.id,
      inspectionItemId: file.inspection_item_id,
      roomId: item?.room_id ?? null,
      roomName: room?.name ?? null,
      entryTitle: item?.notes?.trim() || null,
      stage,
      capturedAt,
      label,
      thumbnailUrl: includeSignedUrls ? null : undefined,
      tagNames: tagMap.get(file.inspection_item_id) ?? [],
      conditionRating: item?.condition_rating ?? null,
    });
  }

  const maintenanceIssues: DisputeMaintenanceIssueItem[] = maintenance.map(
    (m) => ({
      issueId: m.id,
      title: m.title,
      category: m.category ?? null,
      status: normalizeMaintenanceStatus(m.status),
      createdAt: m.created_at ?? null,
      label: `${m.title} · ${humanizeStatus(m.status)}`,
      attachmentCount: evidenceFiles.filter(
        (f) => f.maintenance_issue_id === m.id
      ).length,
    })
  );

  const documentItems: DisputeDocumentItem[] = documents.map((d) => ({
    documentId: d.id,
    type: d.document_type,
    label: humanizeDocType(d.document_type),
    uploadedAt: d.created_at ?? null,
    previewUrl: includeSignedUrls ? null : undefined,
  }));

  return {
    propertyId,
    roomPhotos,
    maintenanceIssues,
    documents: documentItems,
    summary: {
      photoCount: roomPhotos.length,
      maintenanceCount: maintenanceIssues.length,
      documentCount: documentItems.length,
    },
    updatedAt: new Date().toISOString(),
  };
}

function normalizeMaintenanceStatus(
  raw: string
): DisputeMaintenanceIssueItem["status"] {
  if (raw === "follow_up") return "follow_up";
  if (raw === "resolved") return "resolved";
  return "open";
}

function buildEvidenceLabel(args: {
  roomName: string | null;
  entryTitle: string | null;
  stage: DisputeRoomPhotoItem["stage"];
  capturedAt: string | null;
}) {
  const stageLabel =
    args.stage === "move_in"
      ? "Move-in"
      : args.stage === "move_out"
        ? "Move-out"
        : "Photo";

  if (args.roomName && args.entryTitle) {
    return `${args.roomName} · ${args.entryTitle} · ${stageLabel}`;
  }

  if (args.roomName) {
    return `${args.roomName} · Photo · ${stageLabel}`;
  }

  if (args.capturedAt) {
    const date = new Date(args.capturedAt).toLocaleDateString("en-CA", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
    return `Uncategorized photo · ${date}`;
  }

  return "Uncategorized photo";
}

function humanizeDocType(type: string) {
  return type.replace(/_/g, " ").replace(/\b\w/g, (m) => m.toUpperCase());
}

function humanizeStatus(status: string) {
  if (status === "follow_up") return "Follow-up";
  return status.charAt(0).toUpperCase() + status.slice(1);
}
