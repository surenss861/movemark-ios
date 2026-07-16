import { describe, expect, it, vi, beforeEach } from "vitest";
import {
  entitlementStatusFromEvent,
  primaryEntitlementId,
  resolveRevenueCatUserId,
} from "../lib/entitlements.js";
import { mapWithConcurrency } from "../lib/concurrency.js";

describe("resolveRevenueCatUserId", () => {
  it("prefers UUID app_user_id over anonymous", () => {
    expect(
      resolveRevenueCatUserId({
        app_user_id: "$RCAnonymousID:abc",
        aliases: ["aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"],
      })
    ).toBe("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee");
  });

  it("returns null when only anonymous ids exist", () => {
    expect(
      resolveRevenueCatUserId({
        app_user_id: "$RCAnonymousID:abc",
      })
    ).toBeNull();
  });
});

describe("entitlementStatusFromEvent", () => {
  it("marks INITIAL_PURCHASE active", () => {
    expect(
      entitlementStatusFromEvent("INITIAL_PURCHASE", Date.now() + 86_400_000)
    ).toBe("active");
  });

  it("marks EXPIRATION expired", () => {
    expect(entitlementStatusFromEvent("EXPIRATION", Date.now() - 1000)).toBe("expired");
  });

  it("keeps cancellation active until expiration", () => {
    expect(
      entitlementStatusFromEvent("CANCELLATION", Date.now() + 86_400_000)
    ).toBe("active");
  });
});

describe("primaryEntitlementId", () => {
  it("prefers movemark_pro ids", () => {
    expect(primaryEntitlementId(["other", "movemark_pro1"])).toBe("movemark_pro1");
  });
});

describe("mapWithConcurrency", () => {
  it("respects concurrency and preserves order", async () => {
    const seen: number[] = [];
    let inFlight = 0;
    let maxInFlight = 0;

    const results = await mapWithConcurrency([1, 2, 3, 4, 5], 2, async (n) => {
      inFlight += 1;
      maxInFlight = Math.max(maxInFlight, inFlight);
      await new Promise((r) => setTimeout(r, 10));
      seen.push(n);
      inFlight -= 1;
      return n * 10;
    });

    expect(results).toEqual([10, 20, 30, 40, 50]);
    expect(seen.sort()).toEqual([1, 2, 3, 4, 5]);
    expect(maxInFlight).toBeLessThanOrEqual(2);
  });
});

describe("assertCanEnqueueExport", () => {
  beforeEach(() => {
    vi.resetModules();
  });

  it("blocks unpaid move-out", async () => {
    vi.doMock("../lib/supabase.js", () => ({
      supabaseAdmin: {
        from: () => ({
          select: () => ({
            eq: () => ({
              in: async () => ({ data: [], error: null }),
            }),
          }),
        }),
      },
    }));

    const { assertCanEnqueueExport } = await import("../lib/entitlements.js");
    const result = await assertCanEnqueueExport(
      "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
      "move_out_report"
    );
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.code).toBe("pro_required");
      expect(result.status).toBe(402);
    }
  });
});
