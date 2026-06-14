import { supabaseAdmin } from "./supabase.js";

const EVIDENCE_BUCKET = process.env.EVIDENCE_BUCKET_NAME ?? "inspection-media";

export type PdfEvidencePhotoInput = {
  inspectionItemId: string;
  roomId: string | null;
  filePath: string;
  capturedAt: string | null;
  createdAt: string | null;
  notes: string | null;
  conditionRating: number | null;
  tags: string[];
  imageBytes: Uint8Array | null;
};

type EvidenceFileRow = {
  inspection_item_id: string | null;
  file_path: string | null;
  created_at?: string | null;
  captured_at?: string | null;
  file_type?: string | null;
};

export async function downloadStorageObject(path: string): Promise<Uint8Array | null> {
  const trimmed = path.trim();
  if (!trimmed) return null;

  const { data, error } = await supabaseAdmin.storage.from(EVIDENCE_BUCKET).download(trimmed);
  if (error || !data) {
    console.warn(`[movemark-api:pdf] evidence download failed path=${trimmed}`, error?.message);
    return null;
  }

  return new Uint8Array(await data.arrayBuffer());
}

function isImageFileType(fileType: string | null | undefined): boolean {
  if (!fileType) return true;
  const t = fileType.toLowerCase();
  return t === "image" || t.startsWith("image/");
}

export async function buildPdfEvidencePhotos(
  rows: EvidenceFileRow[],
  options: {
    itemRoomId: (inspectionItemId: string) => string | null | undefined;
    itemNotes: (inspectionItemId: string) => string | null | undefined;
    itemRating: (inspectionItemId: string) => number | null | undefined;
    itemTags: (inspectionItemId: string) => string[];
    maxTotal?: number;
    maxPerRoom?: number;
  }
): Promise<PdfEvidencePhotoInput[]> {
  const maxTotal = options.maxTotal ?? 48;
  const maxPerRoom = options.maxPerRoom ?? 8;
  const perRoomCount = new Map<string, number>();
  const results: PdfEvidencePhotoInput[] = [];

  for (const row of rows) {
    if (results.length >= maxTotal) break;

    const itemId = row.inspection_item_id?.trim();
    const filePath = row.file_path?.trim();
    if (!itemId || !filePath) continue;
    if (!isImageFileType(row.file_type)) continue;

    const roomId = options.itemRoomId(itemId) ?? null;
    const roomKey = roomId ?? "__unassigned__";
    const roomCount = perRoomCount.get(roomKey) ?? 0;
    if (roomCount >= maxPerRoom) continue;

    const imageBytes = await downloadStorageObject(filePath);
    perRoomCount.set(roomKey, roomCount + 1);

    results.push({
      inspectionItemId: itemId,
      roomId,
      filePath,
      capturedAt: row.captured_at ?? null,
      createdAt: row.created_at ?? null,
      notes: options.itemNotes(itemId) ?? null,
      conditionRating: options.itemRating(itemId) ?? null,
      tags: options.itemTags(itemId),
      imageBytes,
    });
  }

  return results;
}

export async function loadInspectionEvidencePhotos(
  propertyId: string,
  inspectionItems: Array<Record<string, unknown>>,
  tagNamesByItem: Map<string, string[]>
): Promise<PdfEvidencePhotoInput[]> {
  const itemIds = inspectionItems
    .map((row) => row["id"] as string | undefined)
    .filter((id): id is string => Boolean(id));

  if (itemIds.length === 0) return [];

  const { data: evidenceFiles, error } = await supabaseAdmin
    .from("evidence_files")
    .select("inspection_item_id, file_path, created_at, captured_at, file_type")
    .eq("property_id", propertyId)
    .in("inspection_item_id", itemIds)
    .order("created_at", { ascending: true });

  if (error) {
    console.warn(`[movemark-api:pdf] evidence_files query failed property=${propertyId}`, error.message);
    return [];
  }

  const itemById = new Map(inspectionItems.map((item) => [(item["id"] as string), item]));

  return buildPdfEvidencePhotos(evidenceFiles ?? [], {
    itemRoomId: (id) => itemById.get(id)?.["room_id"] as string | null | undefined,
    itemNotes: (id) => {
      const notes = itemById.get(id)?.["notes"] as string | undefined;
      return notes?.trim() || null;
    },
    itemRating: (id) => itemById.get(id)?.["condition_rating"] as number | null | undefined,
    itemTags: (id) => tagNamesByItem.get(id) ?? [],
  });
}
