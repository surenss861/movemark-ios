export interface DisputeEvidenceCatalogResponse {
  propertyId: string;
  roomPhotos: DisputeRoomPhotoItem[];
  /** Evidence files linked to a maintenance issue only (not walkthrough inspection items). */
  maintenancePhotos: DisputeMaintenancePhotoItem[];
  maintenanceIssues: DisputeMaintenanceIssueItem[];
  documents: DisputeDocumentItem[];
  summary: {
    photoCount: number;
    maintenanceCount: number;
    documentCount: number;
  };
  updatedAt: string;
}

export interface DisputeMaintenancePhotoItem {
  evidenceFileId: string;
  maintenanceIssueId: string;
  issueTitle: string;
  issueCategory: string | null;
  capturedAt: string | null;
  label: string;
  thumbnailUrl?: string | null;
}

export interface DisputeRoomPhotoItem {
  evidenceFileId: string;
  inspectionItemId: string | null;
  roomId: string | null;
  roomName: string | null;
  entryTitle: string | null;
  stage: "move_in" | "move_out" | "unknown";
  capturedAt: string | null;
  label: string;
  thumbnailUrl?: string | null;
  tagNames: string[];
  conditionRating: number | null;
}

export interface DisputeMaintenanceIssueItem {
  issueId: string;
  title: string;
  category: string | null;
  status: "open" | "follow_up" | "resolved";
  createdAt: string | null;
  label: string;
  attachmentCount: number;
}

export interface DisputeDocumentItem {
  documentId: string;
  type: string;
  label: string;
  uploadedAt: string | null;
  previewUrl?: string | null;
}
