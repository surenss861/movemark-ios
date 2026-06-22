import { env } from "./env.js";
import { supabaseAdmin } from "./supabase.js";

export type ReadinessChecks = {
  database: boolean;
  exportStorage: boolean;
};

export type ReadinessResult = {
  ok: boolean;
  checks: ReadinessChecks;
};

/** Verifies Supabase Postgres and export storage bucket are reachable. */
export async function checkReadiness(): Promise<ReadinessResult> {
  const checks: ReadinessChecks = {
    database: false,
    exportStorage: false,
  };

  try {
    const { error } = await supabaseAdmin.from("properties").select("id").limit(1);
    checks.database = !error;
  } catch {
    checks.database = false;
  }

  try {
    const { error } = await supabaseAdmin.storage.from(env.EXPORT_BUCKET_NAME).list("", { limit: 1 });
    checks.exportStorage = !error;
  } catch {
    checks.exportStorage = false;
  }

  return {
    ok: checks.database && checks.exportStorage,
    checks,
  };
}
