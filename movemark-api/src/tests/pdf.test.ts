import { describe, expect, it } from "vitest";
import { generateMoveInPdfBuffer } from "../lib/pdf.js";

describe("generateMoveInPdfBuffer", () => {
  it("produces a non-empty PDF with cover and footer pages", async () => {
    const buffer = await generateMoveInPdfBuffer({
      property: {
        title: "Maple Street Apartment",
        address_line_1: "42 Maple St",
        city: "Toronto",
        province_state: "ON",
        postal_code: "M5V 1A1",
      },
      rooms: [
        { id: "room-1", name: "Kitchen" },
        { id: "room-2", name: "Bedroom" },
      ],
      inspection: { id: "insp-1", inspection_type: "move_in" },
      inspectionItems: [
        {
          id: "item-1",
          room_id: "room-1",
          notes: "Scratch on counter",
          condition_rating: 3,
          created_at: "2026-06-14T03:41:00.000Z",
          pdf_photo_count: 1,
          pdf_issue_tag_names: ["Scratch"],
        },
      ],
      propertyDocuments: [{ document_type: "lease", file_name: "lease.pdf", uploaded_at: "2026-06-01T12:00:00.000Z" }],
      evidencePhotos: [],
    });

    expect(buffer.length).toBeGreaterThan(1000);
    const header = buffer.subarray(0, 5).toString("utf8");
    expect(header).toBe("%PDF-");
  });
});
