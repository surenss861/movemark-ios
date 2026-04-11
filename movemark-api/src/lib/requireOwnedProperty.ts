import { supabaseAdmin } from "./supabase.js";

export async function requireOwnedProperty(
  userId: string,
  propertyId: string
): Promise<{ id: string } | null> {
  const { data, error } = await supabaseAdmin
    .from("properties")
    .select("id")
    .eq("id", propertyId)
    .eq("user_id", userId)
    .maybeSingle();

  if (error) {
    throw new Error(`property ownership lookup failed: ${error.message}`);
  }

  if (!data) {
    return null;
  }

  return data;
}
