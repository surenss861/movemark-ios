export type CapabilityBlockReason =
  | "pro_required"
  | "property_limit_reached"
  | "no_move_in_evidence"
  | "no_move_out_evidence"
  | "draft_required"
  | "quota_exhausted"
  | null;

export interface PropertyCapabilitiesResponse {
  propertyId: string;
  subscription: {
    plan: "free" | "pro";
    isPro: boolean;
  };
  exports: {
    canExportMoveIn: boolean;
    canExportMoveOut: boolean;
    freeMoveInExportsRemaining: number;
    reasonIfBlocked: CapabilityBlockReason;
  };
  disputes: {
    canUseDisputeBuilder: boolean;
    canGenerateFormalPacket: boolean;
    reasonIfBlocked: CapabilityBlockReason;
  };
  properties: {
    canCreateAnotherProperty: boolean;
    reasonIfBlocked: CapabilityBlockReason;
  };
  workflow: {
    canStartMoveInExportNow: boolean;
    canStartMoveOutExportNow: boolean;
    canOpenDisputeBuilderNow: boolean;
  };
  updatedAt: string;
}
