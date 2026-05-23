import type { DisputeEvidenceCatalogResponse } from "../types/disputes.js";
import type { DisputePacketChecklist } from "./pdf.js";
import { MOVE_IN_REPORT_TYPE, MOVE_OUT_REPORT_TYPE } from "./exportGuards.js";

type ExportRow = {
  export_type: string;
  status: string;
  file_path?: string | null;
  completed_at?: string | null;
  requested_at?: string | null;
  created_at?: string | null;
};

function isReadyExport(row: ExportRow): boolean {
  return (
    row.status === "completed" &&
    Boolean(row.file_path?.trim())
  );
}

function formatExportDate(row: ExportRow): string {
  const raw = row.completed_at ?? row.requested_at ?? row.created_at;
  if (!raw) return "on file";
  try {
    return new Date(raw).toLocaleDateString("en-CA", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  } catch {
    return raw;
  }
}

function formatEventDate(iso: string | null): number {
  if (!iso) return 0;
  const t = Date.parse(iso);
  return Number.isNaN(t) ? 0 : t;
}

export function buildDisputePacketChecklist(
  catalog: DisputeEvidenceCatalogResponse,
  exports: ExportRow[],
  moveInProofRooms: number
): DisputePacketChecklist {
  const moveInReport = exports.find(
    (e) => e.export_type === MOVE_IN_REPORT_TYPE && isReadyExport(e)
  );
  const moveOutReport = exports.find(
    (e) => e.export_type === MOVE_OUT_REPORT_TYPE && isReadyExport(e)
  );

  const moveInMoveInPhotos = catalog.roomPhotos.filter((p) => p.stage === "move_in").length;
  const moveOutPhotos = catalog.roomPhotos.filter((p) => p.stage === "move_out").length;

  const moveInReportLine = moveInReport
    ? `Included (PDF ready · ${formatExportDate(moveInReport)})`
    : moveInProofRooms > 0 || moveInMoveInPhotos > 0
      ? `Room proof on file (${moveInProofRooms || "some"} room(s), ${moveInMoveInPhotos} photo(s)) — generate move-in report to attach PDF`
      : "Not available";

  const moveOutReportLine = moveOutReport
    ? `Included (PDF ready · ${formatExportDate(moveOutReport)})`
    : moveOutPhotos > 0
      ? `Move-out proof on file (${moveOutPhotos} photo(s)) — generate move-out report to attach PDF`
      : "Not available";

  const leaseAndDepositDocs =
    catalog.documents.length > 0
      ? catalog.documents.map((d) => d.label)
      : [];

  const damageTagSet = new Set<string>();
  for (const photo of catalog.roomPhotos) {
    for (const tag of photo.tagNames) {
      if (tag.trim()) damageTagSet.add(tag.trim());
    }
  }
  const damageNotes = [
    ...Array.from(damageTagSet).map((t) => `Tagged issue: ${t}`),
    ...catalog.maintenanceIssues.map((m) => m.label),
  ].slice(0, 40);

  type TimelineEntry = { at: number; line: string };
  const timeline: TimelineEntry[] = [];

  for (const photo of catalog.roomPhotos) {
    if (!photo.capturedAt) continue;
    const stage = photo.stage === "move_out" ? "Move-out" : "Move-in";
    timeline.push({
      at: formatEventDate(photo.capturedAt),
      line: `${stage} photo · ${photo.label}`,
    });
  }

  for (const doc of catalog.documents) {
    if (!doc.uploadedAt) continue;
    timeline.push({
      at: formatEventDate(doc.uploadedAt),
      line: `Document uploaded · ${doc.label}`,
    });
  }

  if (moveInReport) {
    timeline.push({
      at: formatEventDate(moveInReport.completed_at ?? moveInReport.requested_at ?? null),
      line: `Move-in report ready · ${formatExportDate(moveInReport)}`,
    });
  }

  if (moveOutReport) {
    timeline.push({
      at: formatEventDate(moveOutReport.completed_at ?? moveOutReport.requested_at ?? null),
      line: `Move-out report ready · ${formatExportDate(moveOutReport)}`,
    });
  }

  timeline.sort((a, b) => a.at - b.at);

  return {
    moveInReport: moveInReportLine,
    moveOutReport: moveOutReportLine,
    leaseAndDepositDocs,
    damageNotes,
    timeline: timeline.map((t) => t.line),
  };
}

export function hasEnoughDisputeProof(
  moveInProofRooms: number,
  moveInPhotos: number,
  exports: ExportRow[]
): boolean {
  if (moveInProofRooms > 0 || moveInPhotos > 0) return true;
  return exports.some((e) => e.export_type === MOVE_IN_REPORT_TYPE && isReadyExport(e));
}
