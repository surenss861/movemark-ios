import type { VaultSummaryResponse } from "../types/vaults.js";
import { supabaseAdmin } from "./supabase.js";

const MOVE_IN_REQUIRED_DOCUMENT_TYPES = [
  "lease",
  "deposit_receipt",
  "listing_screenshot",
] as const;

export async function buildVaultSummary(
  userId: string,
  propertyId: string,
  options?: {
    includeExports?: boolean;
    includeDispute?: boolean;
  }
): Promise<VaultSummaryResponse> {
  const includeExports = options?.includeExports ?? false;
  const includeDispute = options?.includeDispute ?? false;

  const propertyPromise = supabaseAdmin
    .from("properties")
    .select(
      "id,title,address_line_1,city,province_state,country,move_in_date,user_id"
    )
    .eq("id", propertyId)
    .eq("user_id", userId)
    .single();

  const roomsPromise = supabaseAdmin
    .from("rooms")
    .select("id,name,sort_order")
    .eq("property_id", propertyId)
    .order("sort_order", { ascending: true });

  const inspectionsPromise = supabaseAdmin
    .from("inspections")
    .select("id,inspection_type")
    .eq("property_id", propertyId)
    .eq("user_id", userId);

  const documentsPromise = supabaseAdmin
    .from("property_documents")
    .select("id,document_type,created_at")
    .eq("property_id", propertyId)
    .eq("user_id", userId);

  const maintenancePromise = supabaseAdmin
    .from("maintenance_issues")
    .select("id,status")
    .eq("property_id", propertyId)
    .eq("user_id", userId);

  const exportsPromise = includeExports
    ? supabaseAdmin
        .from("exports")
        .select("id,export_type,status,created_at")
        .eq("property_id", propertyId)
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
    : Promise.resolve({ data: [] as Record<string, unknown>[], error: null });

  const draftDisputePromise = includeDispute
    ? supabaseAdmin
        .from("disputes")
        .select("id,status,updated_at")
        .eq("property_id", propertyId)
        .eq("user_id", userId)
        .eq("status", "draft")
        .order("updated_at", { ascending: false })
        .limit(1)
        .maybeSingle()
    : Promise.resolve({ data: null, error: null });

  const [
    propertyRes,
    roomsRes,
    inspectionsRes,
    documentsRes,
    maintenanceRes,
    exportsRes,
    draftDisputeRes,
  ] = await Promise.all([
    propertyPromise,
    roomsPromise,
    inspectionsPromise,
    documentsPromise,
    maintenancePromise,
    exportsPromise,
    draftDisputePromise,
  ]);

  for (const res of [
    propertyRes,
    roomsRes,
    inspectionsRes,
    documentsRes,
    maintenanceRes,
    exportsRes,
    draftDisputeRes,
  ]) {
    if (res.error) {
      throw new Error(res.error.message);
    }
  }

  const property = propertyRes.data;
  if (!property) {
    throw new Error("Property not found");
  }

  const rooms = roomsRes.data ?? [];
  const inspections = inspectionsRes.data ?? [];
  const documents = documentsRes.data ?? [];
  const maintenance = maintenanceRes.data ?? [];
  const exportsRows = (exportsRes.data ?? []) as Array<{
    id: string;
    export_type: string;
    status: string;
    created_at: string | null;
  }>;

  const inspectionIds = inspections.map((i) => i.id);
  let items: Array<{
    id: string;
    inspection_id: string;
    room_id: string | null;
  }> = [];

  if (inspectionIds.length > 0) {
    const { data: itemRows, error: itemsError } = await supabaseAdmin
      .from("inspection_items")
      .select("id,inspection_id,room_id")
      .in("inspection_id", inspectionIds);

    if (itemsError) {
      throw new Error(itemsError.message);
    }
    items = itemRows ?? [];
  }

  const moveInInspectionIds = new Set(
    inspections
      .filter((i) => i.inspection_type === "move_in")
      .map((i) => i.id)
  );

  const moveOutInspectionIds = new Set(
    inspections
      .filter((i) => i.inspection_type === "move_out")
      .map((i) => i.id)
  );

  const moveInRoomIds = new Set(
    items
      .filter((i) => moveInInspectionIds.has(i.inspection_id))
      .map((i) => i.room_id)
      .filter(Boolean) as string[]
  );

  const moveOutRoomIds = new Set(
    items
      .filter((i) => moveOutInspectionIds.has(i.inspection_id))
      .map((i) => i.room_id)
      .filter(Boolean) as string[]
  );

  const documentedRooms = moveInRoomIds.size;
  const moveOutDocumentedRooms = moveOutRoomIds.size;
  const totalRooms = rooms.length;

  const nextRoom =
    rooms.find((room) => !moveInRoomIds.has(room.id)) ?? null;

  const uploadedRequiredTypes = new Set(
    documents
      .map((d) => d.document_type)
      .filter((t): t is string =>
        MOVE_IN_REQUIRED_DOCUMENT_TYPES.includes(
          t as (typeof MOVE_IN_REQUIRED_DOCUMENT_TYPES)[number]
        )
      )
  );

  const uploadedTypes = Array.from(uploadedRequiredTypes);
  const missingTypes = MOVE_IN_REQUIRED_DOCUMENT_TYPES.filter(
    (t) => !uploadedRequiredTypes.has(t)
  );

  const openCount = maintenance.filter((m) => m.status === "open").length;
  const followUpCount = maintenance.filter(
    (m) => m.status === "follow_up"
  ).length;
  const resolvedCount = maintenance.filter(
    (m) => m.status === "resolved"
  ).length;

  const roomProgressWeight =
    totalRooms === 0 ? 0 : documentedRooms / totalRooms;
  const docProgressWeight =
    uploadedTypes.length / MOVE_IN_REQUIRED_DOCUMENT_TYPES.length;

  const score = Math.round(
    (roomProgressWeight * 0.7 + docProgressWeight * 0.3) * 100
  );

  let readinessStatus: VaultSummaryResponse["readiness"]["status"] =
    "needs_attention";
  if (score >= 80) readinessStatus = "strong";
  else if (score >= 40) readinessStatus = "in_progress";

  let primaryNextAction: VaultSummaryResponse["readiness"]["primaryNextAction"] =
    null;
  if (nextRoom) {
    primaryNextAction = {
      type: "continue_walkthrough",
      label: `Open ${nextRoom.name} to capture proof`,
    };
  } else if (missingTypes.length > 0) {
    primaryNextAction = {
      type: "upload_document",
      label: `Upload ${humanizeDocType(missingTypes[0])}`,
    };
  } else if (openCount + followUpCount > 0) {
    primaryNextAction = {
      type: "review_maintenance",
      label: "Review open maintenance issues",
    };
  }

  let disputeBlock: VaultSummaryResponse["dispute"] | undefined;
  if (includeDispute) {
    const draft = draftDisputeRes.data as {
      id: string;
      status?: string;
    } | null;

    if (draft?.id) {
      const { data: linkRows, error: linkErr } = await supabaseAdmin
        .from("dispute_evidence_links")
        .select("evidence_file_id,maintenance_issue_id,property_document_id")
        .eq("dispute_id", draft.id);

      if (linkErr) {
        throw new Error(linkErr.message);
      }

      const links = linkRows ?? [];
      disputeBlock = {
        hasDraft: true,
        draftId: draft.id,
        selectedPhotoCount: links.filter((l) => l.evidence_file_id).length,
        selectedIssueCount: links.filter((l) => l.maintenance_issue_id).length,
        selectedDocumentCount: links.filter((l) => l.property_document_id)
          .length,
      };
    } else {
      disputeBlock = {
        hasDraft: false,
        draftId: null,
        selectedPhotoCount: 0,
        selectedIssueCount: 0,
        selectedDocumentCount: 0,
      };
    }
  }

  return {
    property: {
      id: property.id,
      nickname: property.title ?? null,
      addressLine1: property.address_line_1,
      city: property.city ?? null,
      region: property.province_state ?? null,
      country: property.country ?? null,
      moveInDate: property.move_in_date ?? null,
      isCurrent: true,
    },
    walkthrough: {
      totalRooms,
      documentedRooms,
      nextRoom: nextRoom
        ? { roomId: nextRoom.id, name: nextRoom.name }
        : null,
      hasMoveOutStarted: moveOutDocumentedRooms > 0,
      moveOutDocumentedRooms,
    },
    supportingRecords: {
      requiredTotal: MOVE_IN_REQUIRED_DOCUMENT_TYPES.length,
      uploadedRequired: uploadedTypes.length,
      missingRequired: missingTypes.length,
      uploadedTypes,
      missingTypes: [...missingTypes],
    },
    maintenance: {
      openCount,
      followUpCount,
      resolvedCount,
    },
    readiness: {
      score,
      status: readinessStatus,
      primaryNextAction,
    },
    exports: includeExports
      ? {
          moveInReportCount: exportsRows.filter(
            (e) => e.export_type === "move_in_report"
          ).length,
          moveOutReportCount: exportsRows.filter(
            (e) => e.export_type === "move_out_report"
          ).length,
          disputePacketCount: exportsRows.filter(
            (e) => e.export_type === "dispute_packet"
          ).length,
          latest: exportsRows[0]
            ? {
                id: exportsRows[0].id,
                type: exportsRows[0].export_type,
                status: exportsRows[0].status,
                createdAt: exportsRows[0].created_at,
              }
            : null,
        }
      : undefined,
    dispute: disputeBlock,
    updatedAt: new Date().toISOString(),
  };
}

function humanizeDocType(type: string): string {
  return type
    .replace(/_/g, " ")
    .replace(/\b\w/g, (m) => m.toUpperCase());
}
