/** RFC 4122 UUID (case-insensitive). */
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isUuidString(value: string): boolean {
  return UUID_RE.test(value.trim());
}

export const MOVE_IN_REPORT_TYPE = "move_in_report";
export const MOVE_OUT_REPORT_TYPE = "move_out_report";

export type ExportRowLike = {
  status: string;
  file_path?: string | null;
};

/** Queued/processing, or completed but file not written yet (verifying). */
export function isActiveExportJob(row: ExportRowLike): boolean {
  const status = row.status?.toLowerCase() ?? "";
  if (status === "queued" || status === "processing") return true;
  if (status === "completed") {
    const path = row.file_path?.trim() ?? "";
    return path.length === 0;
  }
  return false;
}

export type MoveOutProofStats = {
  documentedRooms: number;
  totalPhotos: number;
};

/** Rooms with ≥1 move-out photo and total photo count (move-out inspection only). */
export function computeMoveOutProofStats(
  inspectionItems: Array<Record<string, unknown>>,
  photoCountByItem: Map<string, number>
): MoveOutProofStats {
  const roomsWithPhotos = new Set<string>();
  let totalPhotos = 0;

  for (const item of inspectionItems) {
    const itemId = item["id"] as string | undefined;
    const roomId = item["room_id"] as string | undefined;
    if (!itemId || !roomId) continue;
    const count = photoCountByItem.get(itemId) ?? 0;
    if (count > 0) {
      roomsWithPhotos.add(roomId);
      totalPhotos += count;
    }
  }

  return {
    documentedRooms: roomsWithPhotos.size,
    totalPhotos,
  };
}
