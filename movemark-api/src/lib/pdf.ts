import { PDFDocument, PDFImage, StandardFonts, rgb, type PDFFont, type PDFPage } from "pdf-lib";
import type { PdfEvidencePhotoInput } from "./pdfEvidence.js";

const PAGE_W = 612;
const PAGE_H = 792;
const MARGIN = 48;
const FOOTER_RESERVE = 54;
const LINE = 14;
const BODY = 11;
const TITLE = 26;
const SUBTITLE = 14;
const HEAD = 13;
const META = 9;
const PHOTO_COLS = 2;
const PHOTO_GAP = 12;
const PHOTO_CELL_H = 210;
const PHOTO_CAPTION_H = 44;

const COLOR_PRIMARY = rgb(0.16, 0.45, 0.4);
const COLOR_CARD_BG = rgb(0.96, 0.97, 0.97);
const COLOR_CARD_BORDER = rgb(0.86, 0.88, 0.9);
const COLOR_MUTED = rgb(0.42, 0.44, 0.48);
const COLOR_TEXT = rgb(0.1, 0.11, 0.13);
const PHOTO_UNAVAILABLE = "Photo on file, preview unavailable in this export.";

function longestFittingPrefix(
  font: { widthOfTextAtSize: (t: string, s: number) => number },
  s: string,
  size: number,
  maxW: number
): string {
  if (!s) return "";
  if (font.widthOfTextAtSize(s, size) <= maxW) return s;
  let lo = 1;
  let hi = s.length;
  let best = "";
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    const sub = s.slice(0, mid);
    if (font.widthOfTextAtSize(sub, size) <= maxW) {
      best = sub;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return best || s.slice(0, 1);
}

function wrapLine(font: { widthOfTextAtSize: (t: string, s: number) => number }, text: string, size: number, maxW: number): string[] {
  const t = text.trim() || " ";
  const words = t.split(/\s+/).filter(Boolean);
  const lines: string[] = [];
  let cur = "";
  for (const w of words) {
    const test = cur ? `${cur} ${w}` : w;
    if (font.widthOfTextAtSize(test, size) <= maxW) {
      cur = test;
    } else {
      if (cur) lines.push(cur);
      cur = "";
      let rest = w;
      while (rest.length > 0) {
        const chunk = longestFittingPrefix(font, rest, size, maxW);
        lines.push(chunk);
        rest = rest.slice(chunk.length);
      }
    }
  }
  if (cur) lines.push(cur);
  return lines.length ? lines : [" "];
}

type DrawCtx = {
  pdf: PDFDocument;
  page: PDFPage;
  y: number;
  font: PDFFont;
  fontBold: PDFFont;
};

const PAGE_BOTTOM = MARGIN + FOOTER_RESERVE;

async function ensureSpace(ctx: DrawCtx, need: number): Promise<void> {
  if (ctx.y - need < PAGE_BOTTOM) {
    ctx.page = ctx.pdf.addPage([PAGE_W, PAGE_H]);
    ctx.y = PAGE_H - MARGIN;
  }
}

async function drawTextBlock(
  ctx: DrawCtx,
  text: string,
  size: number,
  options?: { bold?: boolean; muted?: boolean; x?: number; maxWidth?: number }
): Promise<void> {
  const bold = options?.bold ?? false;
  const muted = options?.muted ?? false;
  const x = options?.x ?? MARGIN;
  const maxW = options?.maxWidth ?? PAGE_W - 2 * MARGIN;
  const font = bold ? ctx.fontBold : ctx.font;
  const color = muted ? COLOR_MUTED : COLOR_TEXT;
  for (const line of wrapLine(font, text, size, maxW)) {
    await ensureSpace(ctx, LINE);
    ctx.page.drawText(line, { x, y: ctx.y, size, font, color });
    ctx.y -= LINE;
  }
}

function strProp(row: Record<string, unknown>, snake: string, camel?: string): string {
  const v = (row[snake] ?? (camel ? row[camel] : undefined)) as string | undefined;
  return (v ?? "").trim();
}

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

function formatHumanDate(iso?: string | null): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  const datePart = d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
  const timePart = d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit", hour12: true });
  return `${datePart} · ${timePart}`;
}

function formatAddressUnit(line2: string): string | null {
  const trimmed = line2.trim();
  if (!trimmed) return null;
  if (/^(unit|suite|apt|ste|#)\b/i.test(trimmed)) return trimmed;
  if (/^\d+[a-zA-Z]?$/.test(trimmed)) return `Unit ${trimmed}`;
  if (trimmed.length > 3) return trimmed;
  return null;
}

function formatLocation(property: Record<string, unknown>): string {
  const line1 = strProp(property, "address_line_1", "address_line1");
  const line2 = strProp(property, "address_line_2", "address_line2");
  const city = strProp(property, "city");
  const region = strProp(property, "province_state");
  const postal = strProp(property, "postal_code");

  const parts: string[] = [];
  if (line1) parts.push(line1);
  const unit = formatAddressUnit(line2);
  if (unit) parts.push(unit);

  const cityRegion = [city, region].filter(Boolean).join(", ");
  if (cityRegion && postal) parts.push(`${cityRegion} ${postal}`);
  else if (cityRegion) parts.push(cityRegion);
  else if (postal) parts.push(postal);

  return parts.length > 0 ? parts.join(" · ") : "Address not on file";
}

function conditionLabel(rating: unknown): string {
  if (typeof rating !== "number" || Number.isNaN(rating)) return "Not rated";
  const labels: Record<number, string> = {
    1: "Poor",
    2: "Below fair",
    3: "Fair",
    4: "Good",
    5: "Excellent",
  };
  return labels[rating] ?? `Rated ${rating}`;
}

function documentTypeLabel(raw: string): string {
  return raw
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function drawCardBackground(ctx: DrawCtx, topY: number, height: number): void {
  ctx.page.drawRectangle({
    x: MARGIN,
    y: topY - height,
    width: PAGE_W - 2 * MARGIN,
    height,
    color: COLOR_CARD_BG,
    borderColor: COLOR_CARD_BORDER,
    borderWidth: 0.75,
  });
}

async function drawSectionHeader(ctx: DrawCtx, title: string): Promise<void> {
  ctx.y -= 8;
  await drawTextBlock(ctx, title, HEAD, { bold: true });
  ctx.page.drawLine({
    start: { x: MARGIN, y: ctx.y + 4 },
    end: { x: PAGE_W - MARGIN, y: ctx.y + 4 },
    thickness: 0.75,
    color: COLOR_CARD_BORDER,
  });
  ctx.y -= 10;
}

function addFootersToAllPages(pdf: PDFDocument, font: PDFFont, generatedLabel: string): void {
  const pages = pdf.getPages();
  const total = pages.length;

  for (let i = 0; i < pages.length; i++) {
    const page = pages[i];
    page.drawText(`Generated by MoveMark · ${generatedLabel}`, {
      x: MARGIN,
      y: 34,
      size: 8,
      font,
      color: COLOR_MUTED,
    });
    page.drawText(`Page ${i + 1} of ${total}`, {
      x: PAGE_W - MARGIN - 52,
      y: 34,
      size: 8,
      font,
      color: COLOR_MUTED,
    });
    page.drawText("MoveMark organizes user-submitted proof and does not provide legal advice.", {
      x: MARGIN,
      y: 20,
      size: 7,
      font,
      color: COLOR_MUTED,
    });
  }
}

async function embedPhotoImage(pdf: PDFDocument, bytes: Uint8Array): Promise<PDFImage | null> {
  try {
    if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xd8) {
      return await pdf.embedJpg(bytes);
    }
    return await pdf.embedPng(bytes);
  } catch {
    return null;
  }
}

type RoomPhotoGroup = {
  roomId: string;
  roomName: string;
  photos: PdfEvidencePhotoInput[];
  items: Array<Record<string, unknown>>;
};

function buildRoomPhotoGroups(
  rooms: Array<Record<string, unknown>>,
  inspectionItems: Array<Record<string, unknown>>,
  evidencePhotos: PdfEvidencePhotoInput[]
): { groups: RoomPhotoGroup[]; missingRoomNames: string[] } {
  const roomNameById = new Map<string, string>();
  for (const r of rooms) {
    const id = r["id"] as string | undefined;
    if (id) roomNameById.set(id, ((r["name"] as string) ?? id).trim() || id);
  }

  const itemsByRoom = new Map<string, Array<Record<string, unknown>>>();
  for (const item of inspectionItems) {
    const rid = (item["room_id"] as string | undefined) ?? "";
    if (!rid) continue;
    const list = itemsByRoom.get(rid) ?? [];
    list.push(item);
    itemsByRoom.set(rid, list);
  }

  const photosByRoom = new Map<string, PdfEvidencePhotoInput[]>();
  for (const photo of evidencePhotos) {
    const rid = photo.roomId ?? "";
    const list = photosByRoom.get(rid) ?? [];
    list.push(photo);
    photosByRoom.set(rid, list);
  }

  const groups: RoomPhotoGroup[] = [];
  const documentedRoomIds = new Set<string>();

  for (const r of rooms) {
    const id = r["id"] as string | undefined;
    if (!id) continue;
    const photos = photosByRoom.get(id) ?? [];
    const items = itemsByRoom.get(id) ?? [];
    if (photos.length > 0 || items.length > 0) {
      documentedRoomIds.add(id);
      groups.push({
        roomId: id,
        roomName: roomNameById.get(id) ?? "Room",
        photos,
        items,
      });
    }
  }

  for (const [rid, photos] of photosByRoom) {
    if (!rid || documentedRoomIds.has(rid)) continue;
    groups.push({
      roomId: rid,
      roomName: roomNameById.get(rid) ?? "Unassigned room",
      photos,
      items: itemsByRoom.get(rid) ?? [],
    });
  }

  const missingRoomNames = rooms
    .map((r) => {
      const id = r["id"] as string | undefined;
      if (!id || documentedRoomIds.has(id)) return null;
      return roomNameById.get(id) ?? "Room";
    })
    .filter((n): n is string => Boolean(n));

  return { groups, missingRoomNames };
}

function photoCountForGroup(group: RoomPhotoGroup): number {
  if (group.photos.length > 0) return group.photos.length;
  return group.items.reduce((sum, item) => sum + numProp(item, "pdf_photo_count"), 0);
}

async function drawPhotoPlaceholder(ctx: DrawCtx, x: number, width: number, message: string): Promise<void> {
  const imgH = PHOTO_CELL_H - PHOTO_CAPTION_H;
  const top = ctx.y;
  ctx.page.drawRectangle({
    x,
    y: top - imgH,
    width,
    height: imgH,
    borderColor: COLOR_CARD_BORDER,
    borderWidth: 0.75,
    color: rgb(0.99, 0.99, 0.99),
  });
  const lines = wrapLine(ctx.font, message, META, width - 12);
  let textY = top - imgH / 2 + 6;
  for (const line of lines.slice(0, 3)) {
    ctx.page.drawText(line, { x: x + 8, y: textY, size: META, font: ctx.font, color: COLOR_MUTED });
    textY -= 10;
  }
}

async function drawPhotoCell(ctx: DrawCtx, photo: PdfEvidencePhotoInput, x: number, cellW: number): Promise<number> {
  const imgTop = ctx.y;
  const imgH = PHOTO_CELL_H - PHOTO_CAPTION_H;
  let drawnH = imgH;

  if (photo.imageBytes) {
    const embedded = await embedPhotoImage(ctx.pdf, photo.imageBytes);
    if (embedded) {
      const scale = Math.min(cellW / embedded.width, imgH / embedded.height);
      const w = embedded.width * scale;
      const h = embedded.height * scale;
      ctx.page.drawImage(embedded, {
        x: x + (cellW - w) / 2,
        y: imgTop - h,
        width: w,
        height: h,
      });
      drawnH = h;
    } else {
      await drawPhotoPlaceholder(ctx, x, cellW, PHOTO_UNAVAILABLE);
    }
  } else {
    await drawPhotoPlaceholder(ctx, x, cellW, PHOTO_UNAVAILABLE);
  }

  const captionY = imgTop - drawnH - 8;
  ctx.page.drawText(formatHumanDate(photo.capturedAt ?? photo.createdAt), {
    x,
    y: captionY,
    size: META,
    font: ctx.font,
    color: COLOR_MUTED,
  });

  let capY = captionY - 10;
  if (photo.tags.length > 0) {
    for (const line of wrapLine(ctx.font, `Issues: ${photo.tags.join(", ")}`, META, cellW).slice(0, 2)) {
      ctx.page.drawText(line, { x, y: capY, size: META, font: ctx.font, color: COLOR_MUTED });
      capY -= 9;
    }
  }
  const notes = photo.notes?.trim();
  if (notes) {
    for (const line of wrapLine(ctx.font, notes.replace(/\n/g, " "), META, cellW).slice(0, 2)) {
      ctx.page.drawText(line, { x, y: capY, size: META, font: ctx.font, color: COLOR_MUTED });
      capY -= 9;
    }
  }

  return PHOTO_CELL_H;
}

async function drawPhotoGrid(ctx: DrawCtx, photos: PdfEvidencePhotoInput[], expectedCount = 0): Promise<void> {
  if (photos.length === 0) {
    if (expectedCount > 0) {
      await drawTextBlock(ctx, PHOTO_UNAVAILABLE, BODY, { muted: true });
    } else {
      await drawTextBlock(ctx, "No photos added for this room.", BODY, { muted: true });
    }
    return;
  }

  const cellW = (PAGE_W - 2 * MARGIN - PHOTO_GAP * (PHOTO_COLS - 1)) / PHOTO_COLS;
  for (let i = 0; i < photos.length; i += PHOTO_COLS) {
    await ensureSpace(ctx, PHOTO_CELL_H + 8);
    const rowPhotos = photos.slice(i, i + PHOTO_COLS);
    const rowStartY = ctx.y;
    for (let col = 0; col < rowPhotos.length; col++) {
      const x = MARGIN + col * (cellW + PHOTO_GAP);
      ctx.y = rowStartY;
      await drawPhotoCell(ctx, rowPhotos[col], x, cellW);
    }
    ctx.y = rowStartY - PHOTO_CELL_H - 8;
  }
}

async function drawRoomEvidenceSection(ctx: DrawCtx, group: RoomPhotoGroup): Promise<void> {
  await ensureSpace(ctx, 120);
  const cardTop = ctx.y;
  drawCardBackground(ctx, cardTop, 18);
  ctx.y = cardTop - 14;
  await drawTextBlock(ctx, group.roomName, HEAD, { bold: true, x: MARGIN + 12, maxWidth: PAGE_W - 2 * MARGIN - 24 });
  ctx.y = cardTop - 28;

  const photoCount = photoCountForGroup(group);
  await drawTextBlock(ctx, `${photoCount} photo${photoCount === 1 ? "" : "s"} attached`, META, { muted: true });

  for (const item of group.items) {
    await ensureSpace(ctx, 56);
    const rating = item["condition_rating"];
    await drawTextBlock(ctx, `Condition: ${conditionLabel(rating)}`, BODY, { bold: true });
    const loggedAt = formatHumanDate(strProp(item, "created_at") || null);
    await drawTextBlock(ctx, `Logged ${loggedAt}`, META, { muted: true });
    const tags = tagsProp(item);
    if (tags.length > 0) {
      await drawTextBlock(ctx, `Issues tagged: ${tags.join(", ")}`, BODY);
    }
    const notes = strProp(item, "notes");
    if (notes) {
      await drawTextBlock(ctx, `Notes: ${notes.replace(/\n/g, " ")}`, BODY);
    }
    ctx.y -= 4;
  }

  ctx.y -= 4;
  await drawPhotoGrid(ctx, group.photos, photoCount);
  ctx.y -= 12;
}

async function drawMoveInCoverAndSummary(
  ctx: DrawCtx,
  property: Record<string, unknown>,
  generatedAt: string,
  stats: {
    documentedRooms: number;
    totalRooms: number;
    totalPhotos: number;
    totalTags: number;
    docCount: number;
  }
): Promise<void> {
  ctx.page.drawRectangle({
    x: 0,
    y: PAGE_H - 88,
    width: PAGE_W,
    height: 88,
    color: COLOR_PRIMARY,
  });
  ctx.page.drawText("MoveMark", {
    x: MARGIN,
    y: PAGE_H - 42,
    size: TITLE,
    font: ctx.fontBold,
    color: rgb(1, 1, 1),
  });
  ctx.page.drawText("Move-in Proof Report", {
    x: MARGIN,
    y: PAGE_H - 62,
    size: SUBTITLE,
    font: ctx.font,
    color: rgb(0.92, 0.97, 0.96),
  });

  ctx.y = PAGE_H - 108;
  const propertyName = strProp(property, "title") || "Untitled property";
  const location = formatLocation(property);
  const generatedLabel = formatHumanDate(generatedAt);

  const summaryTop = ctx.y;
  drawCardBackground(ctx, summaryTop, 148);
  ctx.y = summaryTop - 16;
  await drawTextBlock(ctx, "Property", META, { bold: true, muted: true, x: MARGIN + 12, maxWidth: PAGE_W - 2 * MARGIN - 24 });
  await drawTextBlock(ctx, propertyName, HEAD, { bold: true, x: MARGIN + 12, maxWidth: PAGE_W - 2 * MARGIN - 24 });
  await drawTextBlock(ctx, `Location: ${location}`, BODY, { x: MARGIN + 12, maxWidth: PAGE_W - 2 * MARGIN - 24 });
  await drawTextBlock(ctx, `Generated: ${generatedLabel}`, BODY, { muted: true, x: MARGIN + 12, maxWidth: PAGE_W - 2 * MARGIN - 24 });
  ctx.y = summaryTop - 148 - 14;

  const proofTop = ctx.y;
  drawCardBackground(ctx, proofTop, 132);
  ctx.y = proofTop - 16;
  await drawTextBlock(ctx, "Proof summary", META, { bold: true, muted: true, x: MARGIN + 12, maxWidth: PAGE_W - 2 * MARGIN - 24 });
  await drawTextBlock(ctx, `Rooms documented: ${stats.documentedRooms} / ${stats.totalRooms}`, BODY, { x: MARGIN + 12, maxWidth: PAGE_W - 2 * MARGIN - 24 });
  await drawTextBlock(ctx, `Photos attached: ${stats.totalPhotos}`, BODY, { x: MARGIN + 12, maxWidth: PAGE_W - 2 * MARGIN - 24 });
  await drawTextBlock(ctx, `Issues tagged: ${stats.totalTags}`, BODY, { x: MARGIN + 12, maxWidth: PAGE_W - 2 * MARGIN - 24 });
  await drawTextBlock(ctx, `Supporting docs: ${stats.docCount}`, BODY, { x: MARGIN + 12, maxWidth: PAGE_W - 2 * MARGIN - 24 });
  await drawTextBlock(ctx, "Report status: Ready to share", BODY, { bold: true, x: MARGIN + 12, maxWidth: PAGE_W - 2 * MARGIN - 24 });
  ctx.y = proofTop - 132 - 14;

  await drawTextBlock(ctx, "Important note", META, { bold: true, muted: true });
  await drawTextBlock(
    ctx,
    "MoveMark organizes user-submitted renter proof. It does not provide legal advice.",
    BODY,
    { muted: true }
  );
}

export async function generateMoveInPdfBuffer(input: {
  property: Record<string, unknown>;
  rooms: Array<Record<string, unknown>>;
  inspection: Record<string, unknown> | null;
  inspectionItems: Array<Record<string, unknown>>;
  propertyDocuments: Array<Record<string, unknown>>;
  evidencePhotos?: PdfEvidencePhotoInput[];
}): Promise<Buffer> {
  const generatedAt = new Date().toISOString();
  const evidencePhotos = input.evidencePhotos ?? [];

  const pdf = await PDFDocument.create();
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const fontBold = await pdf.embedFont(StandardFonts.HelveticaBold);

  let page = pdf.addPage([PAGE_W, PAGE_H]);
  const ctx: DrawCtx = { pdf, page, y: PAGE_H - MARGIN, font, fontBold };

  const totalPhotos =
    evidencePhotos.length > 0
      ? evidencePhotos.length
      : input.inspectionItems.reduce((sum, item) => sum + numProp(item, "pdf_photo_count"), 0);
  const totalTags = input.inspectionItems.reduce((sum, item) => sum + tagsProp(item).length, 0);
  const { groups, missingRoomNames } = buildRoomPhotoGroups(input.rooms, input.inspectionItems, evidencePhotos);
  const documentedRooms = groups.length;

  await drawMoveInCoverAndSummary(ctx, input.property, generatedAt, {
    documentedRooms,
    totalRooms: input.rooms.length,
    totalPhotos,
    totalTags,
    docCount: input.propertyDocuments.length,
  });

  ctx.page = pdf.addPage([PAGE_W, PAGE_H]);
  ctx.y = PAGE_H - MARGIN;
  await drawSectionHeader(ctx, "Room evidence");
  if (groups.length === 0) {
    await drawTextBlock(ctx, "No move-in room proof recorded.", BODY);
  } else {
    for (const group of groups) {
      await drawRoomEvidenceSection(ctx, group);
    }
  }

  if (missingRoomNames.length > 0) {
    await drawSectionHeader(ctx, "Rooms not documented yet");
    await drawTextBlock(
      ctx,
      missingRoomNames.join(", "),
      BODY,
      { muted: true }
    );
  }

  await drawSectionHeader(ctx, "Supporting documents");
  if (input.propertyDocuments.length === 0) {
    await drawTextBlock(ctx, "No supporting documents attached.", BODY, { muted: true });
  } else {
    for (const d of input.propertyDocuments) {
      await ensureSpace(ctx, LINE + 4);
      const dt = documentTypeLabel((d["document_type"] as string | undefined) ?? "document");
      const fn = (d["file_name"] as string | undefined) ?? "Uploaded file";
      const uploaded = formatHumanDate((d["uploaded_at"] as string | undefined) ?? null);
      await drawTextBlock(ctx, `• User-uploaded ${dt}: ${fn}`, BODY);
      if (uploaded !== "—") {
        await drawTextBlock(ctx, `  Uploaded ${uploaded}`, META, { muted: true });
      }
    }
  }

  addFootersToAllPages(pdf, font, formatHumanDate(generatedAt));

  const bytes = await pdf.save();
  return Buffer.from(bytes);
}

export async function generateMoveOutPdfBuffer(input: {
  property: Record<string, unknown>;
  rooms: Array<Record<string, unknown>>;
  inspection: Record<string, unknown> | null;
  inspectionItems: Array<Record<string, unknown>>;
  evidencePhotos?: PdfEvidencePhotoInput[];
}): Promise<Buffer> {
  const generatedAt = new Date().toISOString();
  const evidencePhotos = input.evidencePhotos ?? [];

  const pdf = await PDFDocument.create();
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const fontBold = await pdf.embedFont(StandardFonts.HelveticaBold);

  let page = pdf.addPage([PAGE_W, PAGE_H]);
  const ctx: DrawCtx = { pdf, page, y: PAGE_H - MARGIN, font, fontBold };

  const totalPhotos =
    evidencePhotos.length > 0
      ? evidencePhotos.length
      : input.inspectionItems.reduce((sum, item) => sum + numProp(item, "pdf_photo_count"), 0);

  ctx.page.drawRectangle({ x: 0, y: PAGE_H - 72, width: PAGE_W, height: 72, color: COLOR_PRIMARY });
  ctx.page.drawText("MoveMark", { x: MARGIN, y: PAGE_H - 38, size: 22, font: fontBold, color: rgb(1, 1, 1) });
  ctx.page.drawText("Move-out Proof Report", { x: MARGIN, y: PAGE_H - 56, size: SUBTITLE, font, color: rgb(0.92, 0.97, 0.96) });
  ctx.y = PAGE_H - 92;

  await drawTextBlock(ctx, strProp(input.property, "title") || "Untitled property", HEAD, { bold: true });
  await drawTextBlock(ctx, `Location: ${formatLocation(input.property)}`, BODY);
  await drawTextBlock(ctx, `Generated: ${formatHumanDate(generatedAt)}`, BODY, { muted: true });
  ctx.y -= 8;
  await drawTextBlock(ctx, `Photos attached: ${totalPhotos}`, BODY);

  const { groups, missingRoomNames } = buildRoomPhotoGroups(input.rooms, input.inspectionItems, evidencePhotos);

  ctx.page = pdf.addPage([PAGE_W, PAGE_H]);
  ctx.y = PAGE_H - MARGIN;
  await drawSectionHeader(ctx, "Room evidence");
  if (groups.length === 0) {
    await drawTextBlock(ctx, "No move-out room proof recorded.", BODY);
  } else {
    for (const group of groups) {
      await drawRoomEvidenceSection(ctx, group);
    }
  }

  if (missingRoomNames.length > 0) {
    await drawSectionHeader(ctx, "Rooms not documented yet");
    await drawTextBlock(ctx, missingRoomNames.join(", "), BODY, { muted: true });
  }

  addFootersToAllPages(pdf, font, formatHumanDate(generatedAt));
  return Buffer.from(await pdf.save());
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
}): Promise<Buffer> {
  const generatedAt = new Date().toISOString();
  const pdf = await PDFDocument.create();
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const fontBold = await pdf.embedFont(StandardFonts.HelveticaBold);

  let page = pdf.addPage([PAGE_W, PAGE_H]);
  const ctx: DrawCtx = { pdf, page, y: PAGE_H - MARGIN, font, fontBold };

  ctx.page.drawRectangle({ x: 0, y: PAGE_H - 72, width: PAGE_W, height: 72, color: COLOR_PRIMARY });
  ctx.page.drawText("MoveMark", { x: MARGIN, y: PAGE_H - 38, size: 22, font: fontBold, color: rgb(1, 1, 1) });
  ctx.page.drawText("Dispute Evidence Packet", { x: MARGIN, y: PAGE_H - 56, size: SUBTITLE, font, color: rgb(0.92, 0.97, 0.96) });
  ctx.y = PAGE_H - 92;

  await drawTextBlock(ctx, strProp(input.property, "title") || "Untitled property", HEAD, { bold: true });
  await drawTextBlock(ctx, `Location: ${formatLocation(input.property)}`, BODY);
  await drawTextBlock(ctx, `Generated: ${formatHumanDate(generatedAt)}`, BODY, { muted: true });
  ctx.y -= 10;
  await drawTextBlock(
    ctx,
    "MoveMark organizes user-submitted proof. It does not provide legal advice.",
    BODY,
    { muted: true }
  );

  ctx.page = pdf.addPage([PAGE_W, PAGE_H]);
  ctx.y = PAGE_H - MARGIN;
  await drawSectionHeader(ctx, "Proof checklist");
  await drawTextBlock(ctx, `Move-in report: ${input.checklist.moveInReport}`, BODY);
  await drawTextBlock(ctx, `Move-out report: ${input.checklist.moveOutReport}`, BODY);

  await drawSectionHeader(ctx, "Lease / deposit documents");
  if (input.checklist.leaseAndDepositDocs.length === 0) {
    await drawTextBlock(ctx, "No supporting documents attached.", BODY, { muted: true });
  } else {
    for (const doc of input.checklist.leaseAndDepositDocs) {
      await drawTextBlock(ctx, `• ${doc}`, BODY);
    }
  }

  await drawSectionHeader(ctx, "Damage notes");
  if (input.checklist.damageNotes.length === 0) {
    await drawTextBlock(ctx, "No tagged damage notes on file.", BODY, { muted: true });
  } else {
    for (const note of input.checklist.damageNotes) {
      await drawTextBlock(ctx, `• ${note}`, BODY);
    }
  }

  await drawSectionHeader(ctx, "Timeline summary");
  if (input.checklist.timeline.length === 0) {
    await drawTextBlock(ctx, "No dated events on file.", BODY, { muted: true });
  } else {
    for (const line of input.checklist.timeline) {
      await drawTextBlock(ctx, `• ${line}`, BODY);
    }
  }

  addFootersToAllPages(pdf, font, formatHumanDate(generatedAt));
  return Buffer.from(await pdf.save());
}
