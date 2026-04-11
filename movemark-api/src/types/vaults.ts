export type ReadinessStatus = "strong" | "in_progress" | "needs_attention";

export type PrimaryNextActionType =
  | "continue_walkthrough"
  | "upload_document"
  | "review_maintenance"
  | "open_exports"
  | "open_dispute_builder";

export interface VaultSummaryResponse {
  property: {
    id: string;
    nickname: string | null;
    addressLine1: string;
    city: string | null;
    region: string | null;
    country: string | null;
    moveInDate: string | null;
    isCurrent: boolean;
  };
  walkthrough: {
    totalRooms: number;
    documentedRooms: number;
    nextRoom: { roomId: string; name: string } | null;
    hasMoveOutStarted: boolean;
    moveOutDocumentedRooms: number;
  };
  supportingRecords: {
    requiredTotal: number;
    uploadedRequired: number;
    missingRequired: number;
    uploadedTypes: string[];
    missingTypes: string[];
  };
  maintenance: {
    openCount: number;
    followUpCount: number;
    resolvedCount: number;
  };
  readiness: {
    score: number;
    status: ReadinessStatus;
    primaryNextAction: { type: PrimaryNextActionType; label: string } | null;
  };
  exports?: {
    moveInReportCount: number;
    moveOutReportCount: number;
    disputePacketCount: number;
    latest: {
      id: string;
      type: string;
      status: string;
      createdAt: string | null;
    } | null;
  };
  dispute?: {
    hasDraft: boolean;
    draftId: string | null;
    selectedPhotoCount: number;
    selectedIssueCount: number;
    selectedDocumentCount: number;
  };
  updatedAt: string;
}
