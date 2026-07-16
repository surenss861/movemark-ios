import { describe, expect, it, vi, beforeEach } from "vitest";
import app from "../app.js";

vi.mock("../lib/auth.js", () => ({
  requireUserIdFromBearer: vi.fn(async () => "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"),
}));

const fromMock = vi.fn();
const rpcMock = vi.fn();

vi.mock("../lib/supabase.js", () => ({
  supabaseAdmin: {
    from: (...args: unknown[]) => fromMock(...args),
    rpc: (...args: unknown[]) => rpcMock(...args),
    auth: { getUser: vi.fn() },
    storage: { from: vi.fn() },
  },
}));

vi.mock("../lib/entitlements.js", async () => {
  const actual = await vi.importActual<typeof import("../lib/entitlements.js")>(
    "../lib/entitlements.js"
  );
  return {
    ...actual,
    assertCanEnqueueExport: vi.fn(async () => ({ ok: true as const })),
    isUserPro: vi.fn(async () => false),
    countCompletedMoveInExports: vi.fn(async () => 0),
  };
});

function chain(result: { data: unknown; error: unknown }) {
  const api: Record<string, unknown> = {};
  const self = () => api;
  for (const m of [
    "select",
    "eq",
    "in",
    "order",
    "limit",
    "insert",
    "update",
    "maybeSingle",
    "single",
  ]) {
    api[m] = vi.fn(self);
  }
  api.maybeSingle = vi.fn(async () => result);
  api.single = vi.fn(async () => result);
  api.then = undefined;
  // terminal for select lists
  Object.assign(api, {
    order: vi.fn(() => ({
      ...api,
      limit: vi.fn(async () => result),
      then: undefined,
    })),
  });
  return api;
}

describe("POST /api/exports enqueue", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns 202 queued for move-in when allowed", async () => {
    fromMock.mockImplementation((table: string) => {
      if (table === "properties") {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                maybeSingle: async () => ({ data: { id: "prop-1" }, error: null }),
              }),
            }),
          }),
        };
      }
      if (table === "exports") {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                eq: () => ({
                  order: () => ({
                    limit: async () => ({ data: [], error: null }),
                  }),
                }),
              }),
            }),
          }),
          insert: () => ({
            select: () => ({
              single: async () => ({
                data: {
                  id: "export-1",
                  requested_at: "2026-07-16T00:00:00.000Z",
                  created_at: "2026-07-16T00:00:00.000Z",
                },
                error: null,
              }),
            }),
          }),
        };
      }
      return chain({ data: null, error: null });
    });

    const res = await app.request("http://localhost/api/exports/move-in", {
      method: "POST",
      headers: {
        Authorization: "Bearer test",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        propertyId: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        format: "pdf",
      }),
    });

    expect(res.status).toBe(202);
    const body = await res.json();
    expect(body.status).toBe("queued");
    expect(body.exportId).toBe("export-1");
  });

  it("returns 402 when entitlement check fails for move-out", async () => {
    const entitlements = await import("../lib/entitlements.js");
    vi.mocked(entitlements.assertCanEnqueueExport).mockResolvedValueOnce({
      ok: false,
      status: 402,
      code: "pro_required",
      message: "MoveMark Pro is required for this export.",
    });

    const res = await app.request("http://localhost/api/exports/move-out", {
      method: "POST",
      headers: {
        Authorization: "Bearer test",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        propertyId: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        format: "pdf",
      }),
    });

    expect(res.status).toBe(402);
    const body = await res.json();
    expect(body.code).toBe("pro_required");
  });
});
