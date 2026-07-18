import { env } from "./env.js";
import { supabaseAdmin } from "./supabase.js";

const USER_STORAGE_BUCKETS = [
  env.EVIDENCE_BUCKET_NAME,
  "maintenance-media",
  env.EXPORT_BUCKET_NAME,
  "leases",
  "deposit-receipts",
  "listing-screenshots",
  "documents",
] as const;

type StorageListItem = {
  id?: string | null;
  name: string;
};

async function listObjectPaths(bucket: string, prefix: string, depth = 0): Promise<string[]> {
  if (depth > 5) {
    console.warn(`[movemark-api:deleteAccount] storage path depth exceeded bucket=${bucket} prefix=${prefix}`);
    return [];
  }

  const { data, error } = await supabaseAdmin.storage.from(bucket).list(prefix, {
    limit: 1000,
  });
  if (error) {
    throw new Error(`storage_list_failed:${bucket}:${error.message}`);
  }

  const paths: string[] = [];
  for (const item of (data ?? []) as StorageListItem[]) {
    if (!item.name) continue;
    const fullPath = prefix ? `${prefix}/${item.name}` : item.name;
    // Supabase marks folders with a null id in list responses.
    if (item.id) {
      paths.push(fullPath);
      continue;
    }
    const nested = await listObjectPaths(bucket, fullPath, depth + 1);
    paths.push(...nested);
  }
  return paths;
}

async function deletePrefix(bucket: string, userId: string): Promise<void> {
  const prefixes = Array.from(new Set([userId, userId.toLowerCase()]));
  for (const prefix of prefixes) {
    const paths = await listObjectPaths(bucket, prefix);
    for (let i = 0; i < paths.length; i += 100) {
      const batch = paths.slice(i, i + 100);
      if (batch.length === 0) continue;
      const { error } = await supabaseAdmin.storage.from(bucket).remove(batch);
      if (error) {
        throw new Error(`storage_remove_failed:${bucket}:${error.message}`);
      }
    }
  }
}

/**
 * Deletes owned Postgres rows, then storage objects, then the Auth user.
 *
 * Order matters: there is no cross-step transaction here, so we do the
 * irreversible, hard-to-recover-from step (storage removal) only after the
 * DB rows that reference those files are already gone. If this throws
 * partway through, the worst state a retry can find is "DB rows gone,
 * some storage files still present, auth user still present" — safe to
 * re-run (the RPC is a no-op on rows that no longer exist, storage cleanup
 * finishes removing now-orphaned files, and the auth user isn't deleted
 * until everything else succeeded). The old order (storage first) could
 * instead delete files then fail the RPC, leaving DB rows dangling on
 * file_paths that no longer resolve to anything, with no way to reconstruct
 * them.
 */
export async function deleteAccountForUser(userId: string): Promise<void> {
  const { error: rpcError } = await supabaseAdmin.rpc("delete_user_owned_data", {
    target_user_id: userId,
  });
  if (rpcError) {
    throw new Error(`delete_user_owned_data_failed:${rpcError.message}`);
  }

  for (const bucket of USER_STORAGE_BUCKETS) {
    await deletePrefix(bucket, userId);
  }

  const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(userId);
  if (authError) {
    throw new Error(`delete_auth_user_failed:${authError.message}`);
  }
}
