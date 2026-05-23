import { PDFDocument } from "pdf-lib";
import {
  drawBulletList,
  drawCoverPage,
  drawDisclaimerFooter,
  drawPhotoGrid,
  drawRule,
  drawSectionHeader,
  drawTextBlock,
  embedStandardFonts,
  formatReportDate,
  newLayoutContext,
  propertyAddressLines,
  strProp,
} from "./pdfLayout.js";
import {
  embedEvidencePhotosByItem,
  fetchEvidenceFilesForItems,
  type EvidenceFileRow,
} from "./pdfEvidence.js";

function numProp(row: Record<string, unknown>, key: string): number {
  const v = row[key];
  if (typeof v === "number" && !Number.isNaN(v)) return v;
  return 0;
}

function tagsProp(row: Record<string, unknown>): string[] {
  const raw = row["pdf_issue_tag_names"];
  if (!Array.isArray(raw)) return [];
  return raw.filter((x): x is string => typeof x === "string" && x.length > 0);
}

function formatTimestamp(raw: string | undefined): string {
  if (!raw?.trim()) return "";
  try {
    return new Date(raw).toLocaleString("en-CA", {
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });
  } catch {
    return raw;
  }
}

type RoomSectionInput = {
  property: Record<string, unknown>;
  propertyId: string;
  rooms: Array<Record<string, unknown>>;
  inspectionItems: Array<Record<string, unknown>>;
  phaseLabel: string;
  missingRoomsTitle: string;
  propertyDocuments?: Array<Record<string, unknown>>;
};

async function drawRoomEvidenceSections(input: RoomSectionInput): Promise<Buffer> {
  const pdf = await PDFDocument.create();
  const fonts = await embedStandardFonts(pdf);
  const ctx = newLayoutContext(pdf, fonts);

  const title = strProp(input.property, "title") || "Untitled rental";
  const addressLines = propertyAddressLines(input.property);
  const generatedAt = new Date().toISOString();

  const roomNameById = new Map<string, string>();
  for (const r of input.rooms) {
    const id = r["id"] as string | undefined;
    if (id) roomNameById.set(id, ((r["name"] as string) ?? id).trim() || id);
  }

  const itemIds = input.inspectionItems
    .map((row) => row["id"] as string | undefined)
    .filter((id): id is string => Boolean(id));

  const evidenceRows = await fetchEvidenceFilesForItems(input.propertyId, itemIds);
  const photosByItem = await embedEvidencePhotosByItem(pdf, evidenceRows);

  const photoCountByItem = new Map<string, number>();
  for (const row of evidenceRows) {
    photoCountByItem.set(
      row.inspection_item_id,
      (photoCountByItem.get(row.inspection_item_id) ?? 0) + 1
    );
  }

  const byRoom = new Map<string, Array<Record<string, unknown>>>();
  for (const item of input.inspectionItems) {
    const rid = (item["room_id"] as string | undefined) ?? "";
    const list = byRoom.get(rid) ?? [];
    list.push(item);
    byRoom.set(rid, list);
  }

  const documentedRoomIds = new Set<string>();
  for (const [roomId, items] of byRoom) {
    const hasPhotos = items.some((item) => {
      const id = item["id"] as string | undefined;
      return id ? (photoCountByItem.get(id) ?? numProp(item, "pdf_photo_count")) > 0 : false;
    });
    if (hasPhotos) documentedRoomIds.add(roomId);
  }

  const totalPhotos = [...photoCountByItem.values()].reduce((a, b) => a + b, 0);
  const documentedRooms = documentedRoomIds.size;
  const totalRooms = input.rooms.length;

  await drawCoverPage(ctx, {
    reportTitle: `${input.phaseLabel} Proof Report`,
    reportType: input.phaseLabel,
    property: { title, addressLines },
    generatedAt,
    subtitle: `${documentedRooms} of ${totalRooms} room(s) documented · ${totalPhotos} photo(s) on file`,
  });

  await drawSectionHeader(ctx, "Proof summary");
  await drawTextBlock(ctx, `Report type: ${input.phaseLabel}`, 11);
  await drawTextBlock(ctx, `Rooms documented: ${documentedRooms} of ${totalRooms}`, 11);
  await drawTextBlock(ctx, `Photos on file: ${totalPhotos}`, 11);
  await drawTextBlock(ctx, `Generated: ${formatReportDate(generatedAt)}`, 10, { muted: true });
  ctx.y -= 8;

  await drawSectionHeader(ctx, "Room-by-room evidence");
  const roomOrderIds = input.rooms
    .map((r) => r["id"] as string | undefined)
    .filter((id): id is string => Boolean(id));

  for (const roomId of roomOrderIds) {
    const items = byRoom.get(roomId) ?? [];
    const roomName = roomNameById.get(roomId) ?? "Room";
    const roomPhotos = items.flatMap((item) => {
      const id = item["id"] as string | undefined;
      return id ? photosByItem.get(id) ?? [] : [];
    });

    if (roomPhotos.length === 0 && items.every((item) => numProp(item, "pdf_photo_count") === 0)) {
      continue;
    }

    ctx.y -= 4;
    await drawSectionHeader(ctx, roomName);

    for (const item of items) {
      const itemId = item["id"] as string | undefined;
      const notes = strProp(item, "notes");
      const rating = item["condition_rating"];
      const created = formatTimestamp(strProp(item, "created_at"));
      const photos = itemId ? photoCountByItem.get(itemId) ?? numProp(item, "pdf_photo_count") : 0;
      const tags = tagsProp(item);

      await drawTextBlock(ctx, `Condition: ${rating ?? "—"} · ${photos} photo(s)`, 11, { bold: true });
      const meta: string[] = [];
      if (created) meta.push(`Logged ${created}`);
      if (tags.length) meta.push(`Tags: ${tags.join(", ")}`);
      if (meta.length) await drawTextBlock(ctx, meta.join(" · "), 9, { muted: true });
      if (notes) await drawTextBlock(ctx, notes.replace(/\n/g, " "), 10);

      const embedded = itemId ? photosByItem.get(itemId) ?? [] : [];
      if (embedded.length > 0) {
        await drawPhotoGrid(ctx, embedded, { columns: 3, cellSize: 92, maxPhotos: 6 });
      }
      ctx.y -= 6;
    }
  }

  const missingRooms = input.rooms
    .filter((r) => {
      const id = r["id"] as string | undefined;
      return id && !documentedRoomIds.has(id);
    })
    .map((r) => ((r["name"] as string) ?? "Room").trim() || "Room");

  if (missingRooms.length > 0) {
    await drawSectionHeader(ctx, input.missingRoomsTitle);
    await drawBulletList(
      ctx,
      missingRooms.map((name) => `${name} — no photos on file`)
    );
  }

  ctx.y -= 8;
  await drawSectionHeader(ctx, "Final proof summary");
  await drawTextBlock(
    ctx,
    `${documentedRooms} room(s) documented with ${totalPhotos} photo(s) for this ${input.phaseLabel.toLowerCase()} report.`,
    11
  );

  if (input.propertyDocuments && input.propertyDocuments.length > 0) {
    ctx.y -= 8;
    await drawSectionHeader(ctx, "Supporting documents on file");
    const docs = input.propertyDocuments.map((d) => {
      const dt = (d["document_type"] as string | undefined) ?? "document";
      const fn = (d["file_name"] as string | undefined) ?? "";
      return `${dt}${fn ? ` — ${fn}` : ""}`;
    });
    await drawBulletList(ctx, docs);
  }

  await drawDisclaimerFooter(ctx);
  return Buffer.from(await pdf.save());
}

export async function generateMoveInPdfBuffer(input: {
  property: Record<string, unknown>;
  propertyId: string;
  rooms: Array<Record<string, unknown>>;
  inspection: Record<string, unknown> | null;
  inspectionItems: Array<Record<string, unknown>>;
  propertyDocuments: Array<Record<string, unknown>>;
}): Promise<Buffer> {
  return drawRoomEvidenceSections({
    property: input.property,
    propertyId: input.propertyId,
    rooms: input.rooms,
    inspectionItems: input.inspectionItems,
    phaseLabel: "Move-in",
    missingRoomsTitle: "Rooms without move-in photos",
    propertyDocuments: input.propertyDocuments,
  });
}

export async function generateMoveOutPdfBuffer(input: {
  property: Record<string, unknown>;
  propertyId: string;
  rooms: Array<Record<string, unknown>>;
  inspection: Record<string, unknown> | null;
  inspectionItems: Array<Record<string, unknown>>;
}): Promise<Buffer> {
  return drawRoomEvidenceSections({
    property: input.property,
    propertyId: input.propertyId,
    rooms: input.rooms,
    inspectionItems: input.inspectionItems,
    phaseLabel: "Move-out",
    missingRoomsTitle: "Rooms without move-out photos",
  });
}

export type DisputePacketChecklist = {
  moveInReport: string;
  moveOutReport: string;
  leaseAndDepositDocs: string[];
  damageNotes: string[];
  timeline: string[];
};

export async function generateDisputePacketPdfBuffer(input: {
  property: Record<string, unknown>;
  checklist: DisputePacketChecklist;
  moveInStats?: { documentedRooms: number; totalPhotos: number };
  moveOutStats?: { documentedRooms: number; totalPhotos: number };
}): Promise<Buffer> {
  const pdf = await PDFDocument.create();
  const fonts = await embedStandardFonts(pdf);
  const ctx = newLayoutContext(pdf, fonts);

  const title = strProp(input.property, "title") || "Untitled rental";
  const addressLines = propertyAddressLines(input.property);
  const generatedAt = new Date().toISOString();
  const moveIn = input.moveInStats ?? { documentedRooms: 0, totalPhotos: 0 };
  const moveOut = input.moveOutStats ?? { documentedRooms: 0, totalPhotos: 0 };

  await drawCoverPage(ctx, {
    reportTitle: "Dispute Proof Packet",
    reportType: "Dispute packet",
    property: { title, addressLines },
    generatedAt,
    subtitle: "Organized renter proof — not legal advice or a guaranteed outcome.",
  });

  await drawSectionHeader(ctx, "Property summary");
  await drawTextBlock(ctx, title, 12, { bold: true });
  for (const line of addressLines) {
    await drawTextBlock(ctx, line, 11);
  }
  ctx.y -= 6;

  await drawSectionHeader(ctx, "Proof status");
  await drawTextBlock(ctx, `Move-in proof: ${moveIn.documentedRooms} room(s), ${moveIn.totalPhotos} photo(s)`, 11);
  await drawTextBlock(ctx, `Move-out proof: ${moveOut.documentedRooms} room(s), ${moveOut.totalPhotos} photo(s)`, 11);
  ctx.y -= 6;

  await drawSectionHeader(ctx, "Reports included");
  await drawTextBlock(ctx, `Move-in report: ${input.checklist.moveInReport}`, 11);
  await drawTextBlock(ctx, `Move-out report: ${input.checklist.moveOutReport}`, 11);
  ctx.y -= 6;

  await drawSectionHeader(ctx, "Lease & deposit documents");
  await drawBulletList(ctx, input.checklist.leaseAndDepositDocs);
  ctx.y -= 4;

  await drawSectionHeader(ctx, "Room issues & damage tags");
  await drawBulletList(ctx, input.checklist.damageNotes);
  ctx.y -= 4;

  await drawSectionHeader(ctx, "Timeline summary");
  await drawBulletList(ctx, input.checklist.timeline);
  ctx.y -= 8;

  await drawSectionHeader(ctx, "Important notice");
  await drawTextBlock(
    ctx,
    "This packet organizes your renter proof for your records. MoveMark does not provide legal advice and does not guarantee any dispute outcome.",
    10,
    { muted: true }
  );

  await drawDisclaimerFooter(ctx);
  return Buffer.from(await pdf.save());
}

export type { EvidenceFileRow };
