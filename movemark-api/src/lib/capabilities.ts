import type { PropertyCapabilitiesResponse } from "../types/capabilities.js";
import { supabaseAdmin } from "./supabase.js";

/**
 * Server-side capability hints. Replace `isPro` with your entitlement source
 * (e.g. RevenueCat customer lookup or synced `profiles` column) when ready.
 */
export async function buildPropertyCapabilities(
  userId: string,
  propertyId: string
): Promise<PropertyCapabilitiesResponse> {
  const [propertiesRes, inspectionsRes] = await Promise.all([
    supabaseAdmin.from("properties").select("id").eq("user_id", userId),

    supabaseAdmin
      .from("inspections")
      .select("id,inspection_type")
      .eq("property_id", propertyId)
      .eq("user_id", userId),
  ]);

  if (propertiesRes.error) throw new Error(propertiesRes.error.message);
  if (inspectionsRes.error) throw new Error(inspectionsRes.error.message);

  const inspectionList = inspectionsRes.data ?? [];
  const moveInInspectionIds = new Set(
    inspectionList
      .filter((i) => i.inspection_type === "move_in")
      .map((i) => i.id)
  );
  const moveOutInspectionIds = new Set(
    inspectionList
      .filter((i) => i.inspection_type === "move_out")
      .map((i) => i.id)
  );

  let inspectionItems: Array<{ inspection_id: string }> = [];
  const allInspIds = inspectionList.map((i) => i.id);
  if (allInspIds.length > 0) {
    const { data: ii, error: iiErr } = await supabaseAdmin
      .from("inspection_items")
      .select("inspection_id")
      .in("inspection_id", allInspIds);
    if (iiErr) throw new Error(iiErr.message);
    inspectionItems = ii ?? [];
  }

  const hasMoveInEvidence = inspectionItems.some((row) =>
    moveInInspectionIds.has(row.inspection_id)
  );

  const hasMoveOutEvidence = inspectionItems.some((row) =>
    moveOutInspectionIds.has(row.inspection_id)
  );

  const isPro = false;
  const freeMoveInExportsRemaining = 1;

  const propertyCount = propertiesRes.data?.length ?? 0;

  const canExportMoveInBase = isPro || freeMoveInExportsRemaining > 0;
  const exportBlockedReason: PropertyCapabilitiesResponse["exports"]["reasonIfBlocked"] =
    !isPro && freeMoveInExportsRemaining <= 0 ? "quota_exhausted" : null;

  return {
    propertyId,
    subscription: {
      plan: isPro ? "pro" : "free",
      isPro,
    },
    exports: {
      canExportMoveIn: canExportMoveInBase,
      canExportMoveOut: isPro && hasMoveOutEvidence,
      freeMoveInExportsRemaining,
      reasonIfBlocked: exportBlockedReason,
    },
    disputes: {
      canUseDisputeBuilder: isPro,
      canGenerateFormalPacket: isPro,
      reasonIfBlocked: isPro ? null : "pro_required",
    },
    properties: {
      canCreateAnotherProperty: isPro || propertyCount < 1,
      reasonIfBlocked:
        !isPro && propertyCount >= 1 ? "property_limit_reached" : null,
    },
    workflow: {
      canStartMoveInExportNow: hasMoveInEvidence && canExportMoveInBase,
      canStartMoveOutExportNow: isPro && hasMoveOutEvidence,
      canOpenDisputeBuilderNow: isPro,
    },
    updatedAt: new Date().toISOString(),
  };
}
