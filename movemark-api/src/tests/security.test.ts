import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../lib/supabase.js", () => {
  const from = vi.fn();
  return {
    supabaseAdmin: {
      auth: {
        getUser: vi.fn(),
      },
      from,
      storage: {
        from: vi.fn(),
      },
    },
  };
});

import app from "../app.js";
import { supabaseAdmin } from "../lib/supabase.js";
import {
  checkExportCreateRateLimit,
  resetRateLimitsForTests,
} from "../lib/middleware/rateLimit.js";
import { requireOwnedExport } from "../lib/requireOwnedExport.js";

const USER_A = "11111111-1111-4111-8111-111111111111";
const USER_B = "22222222-2222-4222-8222-222222222222";
const PROPERTY_A = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11";
const EXPORT_A = "b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22";

function authHeaders(userId: string): HeadersInit {
  return { Authorization: `Bearer token-${userId}` };
}

function mockGetUser(userId: string | null) {
  vi.mocked(supabaseAdmin.auth.getUser).mockImplementation(async (jwt?: string) => {
    const token = jwt ?? "";
    const id = token.replace("Bearer ", "").replace("token-", "");
    if (!userId || id !== userId) {
      return { data: { user: null }, error: { message: "invalid", name: "AuthApiError", status: 401 } };
    }
    return { data: { user: { id: userId } as { id: string } }, error: null };
  });
}

beforeEach(() => {
  vi.clearAllMocks();
  resetRateLimitsForTests();
});

describe("security middleware", () => {
  it("returns 401 when Authorization header is missing", async () => {
    const res = await app.request("/api/exports?propertyId=" + PROPERTY_A);
    expect(res.status).toBe(401);
    const body = await res.json();
    expect(body.error).toBe("Unauthorized");
  });

  it("attaches X-Request-Id on health check", async () => {
    const res = await app.request("/api/health");
    expect(res.status).toBe(200);
    expect(res.headers.get("X-Request-Id")).toBeTruthy();
  });

  it("rejects webhook with invalid secret", async () => {
    const res = await app.request("/api/webhooks/revenuecat", {
      method: "POST",
      headers: {
        Authorization: "Bearer wrong-secret",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ event: { id: "evt_1", type: "TEST" } }),
    });
    expect(res.status).toBe(401);
  });

  it("accepts webhook with valid secret", async () => {
    const res = await app.request("/api/webhooks/revenuecat", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-webhook-secret",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ event: { id: "evt_1", type: "TEST" } }),
    });
    expect(res.status).toBe(200);
  });
});

describe("export ownership", () => {
  it("requireOwnedExport returns null for cross-user export", async () => {
    const chain = {
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      maybeSingle: vi.fn().mockResolvedValue({ data: null, error: null }),
    };
    vi.mocked(supabaseAdmin.from).mockReturnValue(chain as never);

    const row = await requireOwnedExport(USER_B, EXPORT_A);
    expect(row).toBeNull();
    expect(chain.eq).toHaveBeenCalledWith("user_id", USER_B);
  });

  it("GET download returns 404 when export belongs to another user", async () => {
    mockGetUser(USER_B);

    const chain = {
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      maybeSingle: vi.fn().mockResolvedValue({ data: null, error: null }),
    };
    vi.mocked(supabaseAdmin.from).mockReturnValue(chain as never);

    const res = await app.request(`/api/exports/${EXPORT_A}/download`, {
      headers: authHeaders(USER_B),
    });

    expect(res.status).toBe(404);
  });

  it("GET list returns 404 for property not owned by user", async () => {
    mockGetUser(USER_A);

    const chain = {
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      maybeSingle: vi.fn().mockResolvedValue({ data: null, error: null }),
    };
    vi.mocked(supabaseAdmin.from).mockReturnValue(chain as never);

    const res = await app.request(`/api/exports?propertyId=${PROPERTY_A}`, {
      headers: authHeaders(USER_A),
    });

    expect(res.status).toBe(404);
  });
});

describe("rate limits", () => {
  it("blocks export create after hourly limit", async () => {
    for (let i = 0; i < 3; i++) {
      const allowed = await checkExportCreateRateLimit(USER_A, PROPERTY_A, "move_in");
      expect(allowed.allowed).toBe(true);
    }
    const blocked = await checkExportCreateRateLimit(USER_A, PROPERTY_A, "move_in");
    expect(blocked.allowed).toBe(false);
    if (!blocked.allowed) {
      expect(blocked.retryAfterSec).toBeGreaterThan(0);
    }
  });

  it("returns 429 when health rate limit exceeded", async () => {
    for (let i = 0; i < 60; i++) {
      const res = await app.request("/api/health", {
        headers: { "X-Forwarded-For": "10.0.0.99" },
      });
      expect(res.status).toBe(200);
    }
    const blocked = await app.request("/api/health", {
      headers: { "X-Forwarded-For": "10.0.0.99" },
    });
    expect(blocked.status).toBe(429);
  });
});
