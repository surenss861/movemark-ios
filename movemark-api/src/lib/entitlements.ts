import { supabaseAdmin } from "./supabase.js";

export const PRO_ENTITLEMENT_IDS = ["movemark_pro", "movemark_pro1"] as const;

export type EntitlementStatus =
  | "active"
  | "inactive"
  | "expired"
  | "billing_issue"
  | "cancelled";

export type UserEntitlementRow = {
  user_id: string;
  entitlement_id: string;
  product_id: string | null;
  status: EntitlementStatus;
  expires_at: string | null;
  environment: string | null;
  revenuecat_app_user_id: string | null;
  last_event_id: string | null;
  last_event_type: string | null;
  updated_at: string;
};

/** UUID-shaped app user ids (Supabase user id after RevenueCat logIn). */
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function resolveRevenueCatUserId(event: {
  app_user_id?: string;
  original_app_user_id?: string;
  aliases?: string[];
}): string | null {
  const candidates = [
    event.app_user_id,
    event.original_app_user_id,
    ...(event.aliases ?? []),
  ];
  for (const raw of candidates) {
    const id = raw?.trim();
    if (!id) continue;
    if (id.startsWith("$RCAnonymousID:")) continue;
    if (UUID_RE.test(id)) return id.toLowerCase();
  }
  return null;
}

const ACTIVE_EVENT_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "PRODUCT_CHANGE",
  "SUBSCRIPTION_EXTENDED",
  "TEMPORARY_ENTITLEMENT_GRANT",
]);

const INACTIVE_EVENT_TYPES = new Set([
  "EXPIRATION",
  "CANCELLATION",
  "BILLING_ISSUE",
  "SUBSCRIPTION_PAUSED",
]);

export function entitlementStatusFromEvent(
  eventType: string | undefined,
  expirationAtMs: number | null | undefined
): EntitlementStatus {
  const type = (eventType ?? "").toUpperCase();
  if (type === "BILLING_ISSUE") return "billing_issue";
  if (type === "CANCELLATION") {
    if (expirationAtMs && expirationAtMs > Date.now()) return "active";
    return "cancelled";
  }
  if (type === "EXPIRATION") return "expired";
  if (INACTIVE_EVENT_TYPES.has(type)) return "inactive";
  if (ACTIVE_EVENT_TYPES.has(type)) {
    if (expirationAtMs != null && expirationAtMs <= Date.now()) return "expired";
    return "active";
  }
  // Unknown events: keep active only if expiration is still in the future.
  if (expirationAtMs != null && expirationAtMs > Date.now()) return "active";
  return "inactive";
}

export function primaryEntitlementId(entitlementIds: string[] | undefined): string {
  if (!entitlementIds?.length) return "movemark_pro";
  for (const id of PRO_ENTITLEMENT_IDS) {
    if (entitlementIds.includes(id)) return id;
  }
  return entitlementIds[0] ?? "movemark_pro";
}

export async function upsertUserEntitlement(input: {
  userId: string;
  entitlementId: string;
  productId?: string | null;
  status: EntitlementStatus;
  expiresAt: string | null;
  environment?: string | null;
  revenueCatAppUserId?: string | null;
  lastEventId?: string | null;
  lastEventType?: string | null;
}): Promise<void> {
  const { error } = await supabaseAdmin.from("user_entitlements").upsert(
    {
      user_id: input.userId,
      entitlement_id: input.entitlementId,
      product_id: input.productId ?? null,
      status: input.status,
      expires_at: input.expiresAt,
      environment: input.environment ?? null,
      revenuecat_app_user_id: input.revenueCatAppUserId ?? null,
      last_event_id: input.lastEventId ?? null,
      last_event_type: input.lastEventType ?? null,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "user_id,entitlement_id" }
  );
  if (error) {
    throw new Error(`upsert_user_entitlement_failed:${error.message}`);
  }
}

export async function isUserPro(userId: string): Promise<boolean> {
  const { data, error } = await supabaseAdmin
    .from("user_entitlements")
    .select("status,expires_at,entitlement_id")
    .eq("user_id", userId)
    .in("entitlement_id", [...PRO_ENTITLEMENT_IDS]);

  if (error) {
    console.error("[movemark-api:entitlements] isUserPro query failed", error);
    return false;
  }

  const now = Date.now();
  for (const row of data ?? []) {
    if (row.status !== "active") continue;
    if (row.expires_at) {
      const exp = Date.parse(row.expires_at);
      if (!Number.isNaN(exp) && exp <= now) continue;
    }
    return true;
  }
  return false;
}

/** Move-in exports that consume free quota (completed or still in flight). */
export async function countCompletedMoveInExports(userId: string): Promise<number> {
  const { count, error } = await supabaseAdmin
    .from("exports")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("export_type", "move_in_report")
    .in("status", ["queued", "processing", "completed"]);

  if (error) {
    console.error("[movemark-api:entitlements] countCompletedMoveInExports", error);
    return 0;
  }
  return count ?? 0;
}

export async function assertCanEnqueueExport(
  userId: string,
  exportType: "move_in_report" | "move_out_report" | "dispute_packet"
): Promise<
  | { ok: true }
  | { ok: false; status: 402 | 403; code: string; message: string }
> {
  const pro = await isUserPro(userId);

  if (exportType === "move_out_report" || exportType === "dispute_packet") {
    if (!pro) {
      return {
        ok: false,
        status: 402,
        code: "pro_required",
        message: "MoveMark Pro is required for this export.",
      };
    }
    return { ok: true };
  }

  // move_in_report: Pro unlimited, free gets 1 completed export.
  if (pro) return { ok: true };

  const completed = await countCompletedMoveInExports(userId);
  if (completed >= 1) {
    return {
      ok: false,
      status: 402,
      code: "quota_exhausted",
      message: "Free move-in export quota used. Upgrade to Pro for more reports.",
    };
  }
  return { ok: true };
}
