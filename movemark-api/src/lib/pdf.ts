import { PDFDocument, StandardFonts, rgb } from "pdf-lib";

const PAGE_W = 612;
const PAGE_H = 792;
const MARGIN = 50;
const LINE = 14;
const BODY = 11;
const TITLE = 18;
const HEAD = 12;
const META = 9;

/** Max prefix of `s` (from start) that fits at `size` within `maxW`; at least one code unit if `s` is non-empty. */
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

/**
 * Word-wrap for PDF body text. Breaks unbroken tokens (URLs, long filenames) so lines stay within the content width
 * and `drawParagraph` + `ensureSpace` cannot paint off the page horizontally.
 */
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
  page: ReturnType<PDFDocument["addPage"]>;
  y: number;
  font: Awaited<ReturnType<PDFDocument["embedFont"]>>;
  fontBold: Awaited<ReturnType<PDFDocument["embedFont"]>>;
};

const PAGE_BOTTOM = MARGIN;

async function ensureSpace(ctx: DrawCtx, need: number): Promise<void> {
  if (ctx.y - need < PAGE_BOTTOM) {
    ctx.page = ctx.pdf.addPage([PAGE_W, PAGE_H]);
    ctx.y = PAGE_H - MARGIN;
  }
}

async function drawParagraph(ctx: DrawCtx, text: string, size: number, bold = false, muted = false): Promise<void> {
  const maxW = PAGE_W - 2 * MARGIN;
  const font = bold ? ctx.fontBold : ctx.font;
  const lines = wrapLine(font, text, size, maxW);
  const color = muted ? rgb(0.38, 0.38, 0.42) : rgb(0.1, 0.1, 0.12);
  for (const line of lines) {
    await ensureSpace(ctx, LINE);
    ctx.page.drawText(line, {
      x: MARGIN,
      y: ctx.y,
      size,
      font,
      color,
    });
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

export async function generateMoveInPdfBuffer(input: {
  property: Record<string, unknown>;
  rooms: Array<Record<string, unknown>>;
  inspection: Record<string, unknown> | null;
  inspectionItems: Array<Record<string, unknown>>;
  propertyDocuments: Array<Record<string, unknown>>;
}): Promise<Buffer> {
  const pdf = await PDFDocument.create();
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const fontBold = await pdf.embedFont(StandardFonts.HelveticaBold);

  let page = pdf.addPage([PAGE_W, PAGE_H]);
  const ctx: DrawCtx = { pdf, page, y: PAGE_H - MARGIN, font, fontBold };

  const title = strProp(input.property, "title") || "Untitled";
  const line1 = strProp(input.property, "address_line_1", "address_line1");
  const line2 = strProp(input.property, "address_line_2", "address_line2");
  const city = strProp(input.property, "city");
  const region = strProp(input.property, "province_state");
  const postal = strProp(input.property, "postal_code");

  const cityLine = [city, region].filter(Boolean).join(", ");
  const addressBits = [line1, line2, cityLine, postal].filter(Boolean);

  await drawParagraph(ctx, "MoveMark — Move-in report", TITLE, true);
  ctx.y -= 6;
  await drawParagraph(ctx, `Property: ${title}`, HEAD, true);
  for (const bit of addressBits) {
    await drawParagraph(ctx, bit, BODY);
  }
  if (addressBits.length === 0) {
    await drawParagraph(ctx, "Address not on file.", BODY, false, true);
  }

  ctx.y -= 8;
  await drawParagraph(
    ctx,
    `Summary: ${input.rooms.length} room(s), ${input.inspectionItems.length} inspection item(s), ${input.propertyDocuments.length} supporting document(s).`,
    BODY
  );
  ctx.y -= 12;

  await drawParagraph(ctx, "Rooms", HEAD, true);
  if (input.rooms.length === 0) {
    await drawParagraph(ctx, "No rooms recorded.", BODY);
  } else {
    for (const r of input.rooms) {
      await ensureSpace(ctx, LINE + 2);
      const name = (r["name"] as string | undefined)?.trim() || "Room";
      await drawParagraph(ctx, `• ${name}`, BODY);
    }
  }
  ctx.y -= 10;

  await drawParagraph(ctx, "Move-in proof by room", HEAD, true);
  if (input.inspectionItems.length === 0) {
    await drawParagraph(ctx, "No move-in inspection items.", BODY);
  } else {
    const roomNameById = new Map<string, string>();
    for (const r of input.rooms) {
      const id = r["id"] as string | undefined;
      if (id) roomNameById.set(id, ((r["name"] as string) ?? id).trim() || id);
    }

    const byRoom = new Map<string, Array<Record<string, unknown>>>();
    for (const item of input.inspectionItems) {
      const rid = (item["room_id"] as string | undefined) ?? "";
      const list = byRoom.get(rid) ?? [];
      list.push(item);
      byRoom.set(rid, list);
    }

    const roomOrderIds = input.rooms.map((r) => r["id"] as string | undefined).filter((id): id is string => Boolean(id));
    const seen = new Set<string>();
    const orderedRoomKeys: string[] = [];
    for (const id of roomOrderIds) {
      if (byRoom.has(id)) {
        orderedRoomKeys.push(id);
        seen.add(id);
      }
    }
    for (const k of byRoom.keys()) {
      if (!seen.has(k)) orderedRoomKeys.push(k);
    }

    for (const roomKey of orderedRoomKeys) {
      const items = byRoom.get(roomKey) ?? [];
      if (items.length === 0) continue;

      const roomLabel =
        roomKey && roomNameById.has(roomKey) ? (roomNameById.get(roomKey) as string) : roomKey ? `Room ${roomKey.slice(0, 8)}…` : "Unassigned room";

      await ensureSpace(ctx, 72);
      await drawParagraph(ctx, roomLabel, HEAD, true);
      ctx.y -= 4;

      for (const item of items) {
        // Upper bound for one entry: header + meta + generous notes/tags (actual height grows per wrapped line).
        await ensureSpace(ctx, 140);

        const notes = strProp(item, "notes");
        const rating = item["condition_rating"];
        const created = strProp(item, "created_at");
        const photos = numProp(item, "pdf_photo_count");
        const tags = tagsProp(item);

        await drawParagraph(ctx, `Condition: ${rating ?? "—"}`, BODY, true);

        const meta: string[] = [];
        if (photos > 0) meta.push(`Photos on file: ${photos}`);
        if (created) meta.push(`Logged: ${created}`);
        if (meta.length) {
          await drawParagraph(ctx, meta.join(" · "), META, false, true);
        }

        if (notes) {
          ctx.y -= 2;
          await drawParagraph(ctx, notes.replace(/\n/g, " "), BODY);
        }

        if (tags.length > 0) {
          ctx.y -= 2;
          await drawParagraph(ctx, `Tags: ${tags.join(", ")}`, META, false, true);
        }

        ctx.y -= 8;
      }
    }
  }

  ctx.y -= 8;

  await drawParagraph(ctx, "Supporting documents on file", HEAD, true);
  if (input.propertyDocuments.length === 0) {
    await drawParagraph(ctx, "None listed.", BODY);
  } else {
    for (const d of input.propertyDocuments) {
      await ensureSpace(ctx, LINE + 4);
      const dt = (d["document_type"] as string | undefined) ?? "document";
      const fn = (d["file_name"] as string | undefined) ?? "";
      await drawParagraph(ctx, `• ${dt}${fn ? ` — ${fn}` : ""}`, BODY);
    }
  }

  ctx.y -= 14;
  await drawParagraph(ctx, `Generated ${new Date().toISOString()}`, META, false, true);

  const bytes = await pdf.save();
  return Buffer.from(bytes);
}
