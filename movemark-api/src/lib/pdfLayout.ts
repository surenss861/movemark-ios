import { PDFDocument, PDFPage, PDFFont, rgb, RGB } from "pdf-lib";

export const PAGE_W = 612;
export const PAGE_H = 792;
export const MARGIN = 48;
export const CONTENT_W = PAGE_W - 2 * MARGIN;

export const COLORS = {
  text: rgb(0.08, 0.09, 0.11),
  muted: rgb(0.42, 0.44, 0.48),
  accent: rgb(0.16, 0.42, 0.34),
  accentSoft: rgb(0.9, 0.96, 0.93),
  rule: rgb(0.86, 0.88, 0.9),
  white: rgb(1, 1, 1),
};

export const LEGAL_DISCLAIMER =
  "MoveMark organizes renter proof and records. It does not provide legal advice.";

export type PdfFonts = {
  regular: PDFFont;
  bold: PDFFont;
};

export type PdfLayoutContext = {
  pdf: PDFDocument;
  page: PDFPage;
  y: number;
  fonts: PdfFonts;
};

export function newLayoutContext(pdf: PDFDocument, fonts: PdfFonts): PdfLayoutContext {
  return {
    pdf,
    page: pdf.addPage([PAGE_W, PAGE_H]),
    y: PAGE_H - MARGIN,
    fonts,
  };
}

export async function embedStandardFonts(pdf: PDFDocument): Promise<PdfFonts> {
  const { StandardFonts } = await import("pdf-lib");
  return {
    regular: await pdf.embedFont(StandardFonts.Helvetica),
    bold: await pdf.embedFont(StandardFonts.HelveticaBold),
  };
}

function longestFittingPrefix(
  font: PDFFont,
  text: string,
  size: number,
  maxW: number
): string {
  if (!text) return "";
  if (font.widthOfTextAtSize(text, size) <= maxW) return text;
  let lo = 1;
  let hi = text.length;
  let best = "";
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    const sub = text.slice(0, mid);
    if (font.widthOfTextAtSize(sub, size) <= maxW) {
      best = sub;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return best || text.slice(0, 1);
}

function wrapLine(font: PDFFont, text: string, size: number, maxW: number): string[] {
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

export async function ensureSpace(ctx: PdfLayoutContext, need: number): Promise<void> {
  if (ctx.y - need < MARGIN) {
    ctx.page = ctx.pdf.addPage([PAGE_W, PAGE_H]);
    ctx.y = PAGE_H - MARGIN;
  }
}

export async function drawTextBlock(
  ctx: PdfLayoutContext,
  text: string,
  size: number,
  opts: { bold?: boolean; color?: RGB; muted?: boolean; lineHeight?: number } = {}
): Promise<void> {
  const font = opts.bold ? ctx.fonts.bold : ctx.fonts.regular;
  const color = opts.color ?? (opts.muted ? COLORS.muted : COLORS.text);
  const lh = opts.lineHeight ?? size + 3;
  for (const line of wrapLine(font, text, size, CONTENT_W)) {
    await ensureSpace(ctx, lh);
    ctx.page.drawText(line, { x: MARGIN, y: ctx.y, size, font, color });
    ctx.y -= lh;
  }
}

export async function drawRule(ctx: PdfLayoutContext): Promise<void> {
  await ensureSpace(ctx, 12);
  ctx.y -= 4;
  ctx.page.drawLine({
    start: { x: MARGIN, y: ctx.y },
    end: { x: PAGE_W - MARGIN, y: ctx.y },
    thickness: 1,
    color: COLORS.rule,
  });
  ctx.y -= 10;
}

export function formatReportDate(iso = new Date().toISOString()): string {
  try {
    return new Date(iso).toLocaleString("en-CA", {
      month: "long",
      day: "numeric",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });
  } catch {
    return iso;
  }
}

export type PropertySummaryInput = {
  title: string;
  addressLines: string[];
};

export function propertyAddressLines(property: Record<string, unknown>): string[] {
  const line1 = strProp(property, "address_line_1", "address_line1");
  const line2 = strProp(property, "address_line_2", "address_line2");
  const city = strProp(property, "city");
  const region = strProp(property, "province_state");
  const postal = strProp(property, "postal_code");
  const cityLine = [city, region].filter(Boolean).join(", ");
  return [line1, line2, cityLine, postal].filter(Boolean);
}

export function strProp(row: Record<string, unknown>, snake: string, camel?: string): string {
  const v = (row[snake] ?? (camel ? row[camel] : undefined)) as string | undefined;
  return (v ?? "").trim();
}

export async function drawCoverPage(
  ctx: PdfLayoutContext,
  input: {
    reportTitle: string;
    reportType: string;
    property: PropertySummaryInput;
    generatedAt?: string;
    subtitle?: string;
  }
): Promise<void> {
  ctx.y = PAGE_H - 96;
  await drawTextBlock(ctx, "MoveMark", 28, { bold: true, color: COLORS.accent });
  ctx.y -= 6;
  await drawTextBlock(ctx, input.reportTitle, 22, { bold: true });
  ctx.y -= 4;
  await drawTextBlock(ctx, input.reportType, 11, { muted: true });
  ctx.y -= 18;

  ctx.page.drawRectangle({
    x: MARGIN,
    y: ctx.y - 108,
    width: CONTENT_W,
    height: 108,
    color: COLORS.accentSoft,
    borderColor: COLORS.rule,
    borderWidth: 1,
  });

  let boxY = ctx.y - 18;
  const drawInBox = async (text: string, size: number, bold = false) => {
    ctx.page.drawText(text, {
      x: MARGIN + 16,
      y: boxY,
      size,
      font: bold ? ctx.fonts.bold : ctx.fonts.regular,
      color: COLORS.text,
    });
    boxY -= size + 8;
  };

  await drawInBox(input.property.title || "Rental", 14, true);
  for (const line of input.property.addressLines) {
    await drawInBox(line, 11);
  }
  if (input.property.addressLines.length === 0) {
    await drawInBox("Address not on file", 11);
  }

  ctx.y -= 128;
  if (input.subtitle) {
    await drawTextBlock(ctx, input.subtitle, 11, { muted: true });
    ctx.y -= 4;
  }
  await drawTextBlock(ctx, `Generated ${formatReportDate(input.generatedAt)}`, 10, { muted: true });
  ctx.y -= 20;
  await drawRule(ctx);
}

export async function drawSectionHeader(ctx: PdfLayoutContext, title: string): Promise<void> {
  ctx.y -= 6;
  await drawTextBlock(ctx, title, 13, { bold: true, color: COLORS.accent });
  ctx.y -= 2;
}

export async function drawBulletList(ctx: PdfLayoutContext, items: string[]): Promise<void> {
  if (items.length === 0) {
    await drawTextBlock(ctx, "None on file.", 11, { muted: true });
    return;
  }
  for (const item of items) {
    await drawTextBlock(ctx, `• ${item}`, 11);
  }
}

export async function drawDisclaimerFooter(ctx: PdfLayoutContext): Promise<void> {
  ctx.y -= 10;
  await drawRule(ctx);
  await drawTextBlock(ctx, LEGAL_DISCLAIMER, 9, { muted: true });
}

export type EmbeddedPhoto = {
  image: Awaited<ReturnType<PDFDocument["embedJpg"]>>;
  width: number;
  height: number;
};

export async function drawPhotoGrid(
  ctx: PdfLayoutContext,
  photos: EmbeddedPhoto[],
  opts: { columns?: number; cellSize?: number; gap?: number; maxPhotos?: number } = {}
): Promise<void> {
  const columns = opts.columns ?? 3;
  const cellSize = opts.cellSize ?? 96;
  const gap = opts.gap ?? 8;
  const maxPhotos = opts.maxPhotos ?? 6;
  const slice = photos.slice(0, maxPhotos);

  if (slice.length === 0) {
    await drawTextBlock(ctx, "No photos embedded for this room.", 10, { muted: true });
    return;
  }

  const rows = Math.ceil(slice.length / columns);
  const gridH = rows * cellSize + Math.max(0, rows - 1) * gap;
  await ensureSpace(ctx, gridH + 8);

  for (let i = 0; i < slice.length; i++) {
    const col = i % columns;
    const row = Math.floor(i / columns);
    const x = MARGIN + col * (cellSize + gap);
    const yTop = ctx.y - row * (cellSize + gap);

    const photo = slice[i];
    const scale = Math.min(cellSize / photo.width, cellSize / photo.height);
    const w = photo.width * scale;
    const h = photo.height * scale;
    const offsetX = (cellSize - w) / 2;
    const offsetY = (cellSize - h) / 2;

    ctx.page.drawRectangle({
      x,
      y: yTop - cellSize,
      width: cellSize,
      height: cellSize,
      color: rgb(0.95, 0.95, 0.96),
      borderColor: COLORS.rule,
      borderWidth: 0.5,
    });

    ctx.page.drawImage(photo.image, {
      x: x + offsetX,
      y: yTop - cellSize + offsetY,
      width: w,
      height: h,
    });
  }

  ctx.y -= gridH + 8;
  if (photos.length > maxPhotos) {
    await drawTextBlock(ctx, `+ ${photos.length - maxPhotos} more photo(s) on file`, 9, { muted: true });
  }
}
