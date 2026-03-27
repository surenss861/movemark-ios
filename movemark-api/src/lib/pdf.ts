export async function generateMoveInPdfBuffer(input: {
  property: Record<string, unknown>;
  rooms: Array<Record<string, unknown>>;
  inspection: Record<string, unknown> | null;
  inspectionItems: Array<Record<string, unknown>>;
  propertyDocuments: Array<Record<string, unknown>>;
}): Promise<Buffer> {
  const title = (input.property["title"] as string | undefined) ?? "Untitled";
  const address = (input.property["address_line1"] as string | undefined) ?? "";

  const content = [
    "MoveMark Move-In Report",
    `Property: ${title}`,
    `Address: ${address}`,
    `Rooms: ${input.rooms.length}`,
    `Inspection Items: ${input.inspectionItems.length}`,
    `Supporting Docs: ${input.propertyDocuments.length}`,
  ].join("\n");

  return Buffer.from(content, "utf-8");
}
