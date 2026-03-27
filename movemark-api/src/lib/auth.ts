import type { Context } from "hono";
import { supabaseAdmin } from "./supabase.js";

export async function requireUserIdFromBearer(c: Context): Promise<string> {
  const authHeader = c.req.header("Authorization");

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    throw new Error("Missing or invalid Authorization header");
  }

  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) {
    throw new Error("Missing bearer token");
  }

  const { data, error } = await supabaseAdmin.auth.getUser(token);

  if (error || !data.user) {
    throw new Error("Unauthorized");
  }

  return data.user.id;
}
