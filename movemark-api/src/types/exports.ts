export type ExportRequestBody = {
  propertyId: string;
  format: "pdf";
};

export type ExportReportType = "move_in_report" | "move_out_report" | "dispute_packet";

export type ExportResponseBody = {
  exportId: string;
  status: "completed";
  type: ExportReportType;
  requestedAt: string;
};

export type ExportErrorCode =
  | "not_enough_proof"
  | "not_enough_move_out_proof"
  | "not_enough_dispute_proof"
  | "export_already_processing"
  | "export_failed"
  | "export_generation_failed";

export type ExportJobStatus = "queued" | "processing" | "verifying" | "completed" | "failed";

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
