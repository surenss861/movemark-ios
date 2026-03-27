import { env } from "./env.js";
import { supabaseAdmin } from "./supabase.js";

export async function uploadExportToSupabaseStorage(params: {
  userId: string;
  exportId: string;
  fileBuffer: Buffer;
}): Promise<{ path: string }> {
  const path = `${params.userId}/${params.exportId}.pdf`;

  const { error } = await supabaseAdmin.storage
    .from(env.EXPORT_BUCKET_NAME)
    .upload(path, params.fileBuffer, {
      contentType: "application/pdf",
      upsert: true,
    });

  if (error) {
    throw new Error(`Failed to upload export: ${error.message}`);
  }

  return { path };
}
