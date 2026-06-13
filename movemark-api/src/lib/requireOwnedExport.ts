import { supabaseAdmin } from "./supabase.js";

export type OwnedExportRow = {
  id: string;
  user_id: string;
  status: string;
  file_path: string | null;
};

export async function requireOwnedExport(
  userId: string,
  exportId: string
): Promise<OwnedExportRow | null> {
  const { data, error } = await supabaseAdmin
    .from("exports")
    .select("id,user_id,status,file_path")
    .eq("id", exportId)
    .eq("user_id", userId)
    .maybeSingle();

  if (error) {
    throw new Error(`export ownership lookup failed: ${error.message}`);
  }

  return data ?? null;
}
