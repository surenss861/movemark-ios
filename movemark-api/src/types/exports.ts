export type ExportRequestBody = {
  propertyId: string;
  format: "pdf";
};

export type ExportResponseBody = {
  exportId: string;
  status: "queued";
  type: "move_in_report";
  requestedAt: string;
};

export type ExportJobStatus = "queued" | "processing" | "completed" | "failed";

export type ExportListItem = {
  id: string;
  userId: string;
  propertyId: string;
  type: string;
  status: ExportJobStatus;
  requestedAt: string | null;
  completedAt: string | null;
  filePath: string | null;
  createdAt: string | null;
};

export type ExportDownloadResponseBody = {
  exportId: string;
  status: ExportJobStatus;
  downloadUrl: string;
  expiresInSeconds: number;
};
