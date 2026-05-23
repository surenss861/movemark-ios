/**
 * Local PDF smoke test — generates sample move-in PDFs without live Supabase data.
 * Usage: npm run smoke:pdf
 */
import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const OUT_DIR = join(process.cwd(), "tmp", "pdf-smoke");

async function main() {
  process.env.SUPABASE_URL ??= "https://example.supabase.co";
  process.env.SUPABASE_SERVICE_ROLE_KEY ??= "smoke-test-key";

  const { generateDisputePacketPdfBuffer, generateMoveInPdfBuffer } = await import("../src/lib/pdf.js");

  mkdirSync(OUT_DIR, { recursive: true });

  const propertyId = "00000000-0000-4000-8000-000000000001";
  const kitchenId = "00000000-0000-4000-8000-000000000101";
  const livingId = "00000000-0000-4000-8000-000000000102";
  const itemKitchen = "00000000-0000-4000-8000-000000000201";

  const property = {
    title: "QA Rental — 123 Main St",
    address_line_1: "123 Main Street",
    city: "Toronto",
    province_state: "ON",
    postal_code: "M5V 1A1",
  };

  const rooms = [
    { id: kitchenId, name: "Kitchen" },
    { id: livingId, name: "Living Room" },
  ];

  const inspectionItems = [
    {
      id: itemKitchen,
      room_id: kitchenId,
      condition_rating: 3,
      notes: "Scuff on baseboard near stove — documented at move-in.",
      created_at: "2026-05-20T14:30:00.000Z",
      pdf_photo_count: 2,
      pdf_issue_tag_names: ["Wall scuff", "Existing wear"],
    },
  ];

  const partial = await generateMoveInPdfBuffer({
    property,
    propertyId,
    rooms,
    inspection: { id: "insp-1" },
    inspectionItems,
    propertyDocuments: [{ document_type: "Lease", file_name: "lease-2026.pdf" }],
  });
  writeFileSync(join(OUT_DIR, "move-in-partial-rooms.pdf"), partial);

  const singleRoom = await generateMoveInPdfBuffer({
    property,
    propertyId,
    rooms: [rooms[0]],
    inspection: { id: "insp-1" },
    inspectionItems,
    propertyDocuments: [],
  });
  writeFileSync(join(OUT_DIR, "move-in-one-room.pdf"), singleRoom);

  const dispute = await generateDisputePacketPdfBuffer({
    property,
    checklist: {
      moveInReport: "Included (PDF ready · May 20, 2026)",
      moveOutReport: "Not available",
      leaseAndDepositDocs: ["Lease agreement — lease-2026.pdf"],
      damageNotes: ["Tagged issue: Wall scuff", "Tagged issue: Existing wear"],
      timeline: ["May 20, 2026 — Kitchen move-in photos saved"],
    },
    moveInStats: { documentedRooms: 1, totalPhotos: 2 },
    moveOutStats: { documentedRooms: 0, totalPhotos: 0 },
  });
  writeFileSync(join(OUT_DIR, "dispute-packet.pdf"), dispute);

  console.log(`Wrote PDF smoke samples to ${OUT_DIR}`);
  console.log("  - move-in-one-room.pdf");
  console.log("  - move-in-partial-rooms.pdf");
  console.log("  - dispute-packet.pdf");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
