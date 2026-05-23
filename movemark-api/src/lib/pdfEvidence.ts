import { PDFDocument } from "pdf-lib";
import { env } from "./env.js";
import { supabaseAdmin } from "./supabase.js";
import type { EmbeddedPhoto } from "./pdfLayout.js";

const EVIDENCE_BUCKET = env.INSPECTION_MEDIA_BUCKET;
const MAX_PHOTOS_PER_ITEM = 6;

export type EvidenceFileRow = {
  inspection_item_id: string;
  file_path: string;
  created_at?: string | null;
  captured_at?: string | null;
};

export async function fetchEvidenceFilesForItems(
  propertyId: string,
  itemIds: string[]
): Promise<EvidenceFileRow[]> {
  if (itemIds.length === 0) return [];

  const { data, error } = await supabaseAdmin
    .from("evidence_files")
    .select("inspection_item_id,file_path,created_at,captured_at")
    .eq("property_id", propertyId)
    .in("inspection_item_id", itemIds)
    .order("created_at", { ascending: true });

  if (error) {
    console.error("[movemark-api:pdf] evidence_files query failed", error);
    return [];
  }

  return (data ?? []).filter((row) => {
    return (
      typeof row.inspection_item_id === "string" &&
      typeof row.file_path === "string" &&
      row.file_path.trim().length > 0
    );
  }) as EvidenceFileRow[];
}

async function downloadEvidenceBytes(path: string): Promise<Uint8Array | null> {
  const trimmed = path.trim();
  if (!trimmed) return null;

  const { data, error } = await supabaseAdmin.storage.from(EVIDENCE_BUCKET).download(trimmed);
  if (error || !data) {
    console.warn("[movemark-api:pdf] evidence download failed", trimmed, error?.message);
    return null;
  }

  const buf = new Uint8Array(await data.arrayBuffer());
  return buf.length > 0 ? buf : null;
}

async function embedPhoto(pdf: PDFDocument, bytes: Uint8Array): Promise<EmbeddedPhoto | null> {
  try {
    if (bytes[0] === 0xff && bytes[1] === 0xd8) {
      const image = await pdf.embedJpg(bytes);
      return { image, width: image.width, height: image.height };
    }
    const image = await pdf.embedPng(bytes);
    return { image, width: image.width, height: image.height };
  } catch (e) {
    console.warn("[movemark-api:pdf] embed photo failed", e);
    return null;
  }
}

/** Map inspection_item_id → embedded photos (best effort; skips broken files). */
export async function embedEvidencePhotosByItem(
  pdf: PDFDocument,
  evidenceRows: EvidenceFileRow[]
): Promise<Map<string, EmbeddedPhoto[]>> {
  const byItem = new Map<string, EvidenceFileRow[]>();
  for (const row of evidenceRows) {
    const list = byItem.get(row.inspection_item_id) ?? [];
    list.push(row);
    byItem.set(row.inspection_item_id, list);
  }

  const result = new Map<string, EmbeddedPhoto[]>();

  for (const [itemId, rows] of byItem) {
    const photos: EmbeddedPhoto[] = [];
    for (const row of rows.slice(0, MAX_PHOTOS_PER_ITEM)) {
      const bytes = await downloadEvidenceBytes(row.file_path);
      if (!bytes) continue;
      const embedded = await embedPhoto(pdf, bytes);
      if (embedded) photos.push(embedded);
    }
    if (photos.length > 0) result.set(itemId, photos);
  }

  return result;
}
