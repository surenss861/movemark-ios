import { supabaseAdmin } from "./supabase.js";
import { uploadExportToSupabaseStorage } from "./storage.js";
import {
  DISPUTE_PACKET_TYPE,
  isActiveExportJob,
  MOVE_IN_REPORT_TYPE,
  MOVE_OUT_REPORT_TYPE,
} from "./exportGuards.js";

export type ExportRowRef = {
  id: string;
  status: string;
  file_path?: string | null;
  export_type: string;
};

export async function findActiveExport(
  userId: string,
  propertyId: string,
  exportType: string
): Promise<ExportRowRef | null> {
  const { data } = await supabaseAdmin
    .from("exports")
    .select("id,status,file_path,export_type")
    .eq("user_id", userId)
    .eq("property_id", propertyId)
    .eq("export_type", exportType)
    .order("created_at", { ascending: false })
    .limit(5);

  return (
    (data ?? []).find((row) =>
      isActiveExportJob({ status: row.status as string, file_path: row.file_path as string | null })
    ) ?? null
  );
}

export async function setExportStatus(
  exportId: string,
  status: "queued" | "processing" | "verifying" | "completed" | "failed",
  extra: Record<string, unknown> = {}
): Promise<void> {
  const { error } = await supabaseAdmin.from("exports").update({ status, ...extra }).eq("id", exportId);
  if (error) throw new Error(`status update failed: ${error.message}`);
}

export async function markExportFailed(exportId: string, reason: string, errorCode?: string): Promise<void> {
  try {
    const metadata = errorCode ? { error_code: errorCode } : {};
    const { error } = await supabaseAdmin
      .from("exports")
      .update({
        status: "failed",
        error_message: reason.slice(0, 2000),
        metadata,
      })
      .eq("id", exportId);
    if (error) {
      console.error(`[movemark-api:exports] markExportFailed update error id=${exportId}`, error);
    } else {
      console.log(`[movemark-api:exports] export status=failed id=${exportId} reason=${reason}`);
    }
  } catch (e) {
    console.error(`[movemark-api:exports] markExportFailed exception id=${exportId}`, e);
  }
}

export async function runExportPipeline(params: {
  userId: string;
  exportId: string;
  generatePdf: () => Promise<Buffer>;
}): Promise<{ path: string }> {
  await setExportStatus(params.exportId, "processing");

  const pdfBuffer = await params.generatePdf();

  await setExportStatus(params.exportId, "verifying");

  const upload = await uploadExportToSupabaseStorage({
    userId: params.userId,
    exportId: params.exportId,
    fileBuffer: pdfBuffer,
  });

  await setExportStatus(params.exportId, "completed", {
    file_path: upload.path,
    completed_at: new Date().toISOString(),
  });

  return upload;
}

export { MOVE_IN_REPORT_TYPE, MOVE_OUT_REPORT_TYPE, DISPUTE_PACKET_TYPE };
