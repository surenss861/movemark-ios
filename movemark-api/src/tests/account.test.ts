import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../lib/supabase.js", () => {
  const from = vi.fn();
  return {
    supabaseAdmin: {
      auth: {
        getUser: vi.fn(),
        admin: {
          deleteUser: vi.fn(),
        },
      },
      from,
      rpc: vi.fn(),
      storage: {
        from: vi.fn(),
      },
    },
  };
});

import app from "../app.js";
import { supabaseAdmin } from "../lib/supabase.js";
import { resetRateLimitsForTests } from "../lib/middleware/rateLimit.js";

const USER_A = "11111111-1111-4111-8111-111111111111";

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

describe("DELETE /api/account", () => {
  it("returns 401 when Authorization header is missing", async () => {
    const res = await app.request("/api/account", { method: "DELETE" });
    expect(res.status).toBe(401);
  });

  it("deletes storage, owned data, and auth user for the authenticated account", async () => {
    mockGetUser(USER_A);

    const list = vi.fn().mockResolvedValue({ data: [], error: null });
    const remove = vi.fn().mockResolvedValue({ data: [], error: null });
    vi.mocked(supabaseAdmin.storage.from).mockReturnValue({ list, remove } as never);
    vi.mocked(supabaseAdmin.rpc).mockResolvedValue({ data: null, error: null } as never);
    vi.mocked(supabaseAdmin.auth.admin.deleteUser).mockResolvedValue({
      data: { user: null },
      error: null,
    } as never);

    const res = await app.request("/api/account", {
      method: "DELETE",
      headers: authHeaders(USER_A),
    });

    expect(res.status).toBe(204);
    expect(supabaseAdmin.rpc).toHaveBeenCalledWith("delete_user_owned_data", {
      target_user_id: USER_A,
    });
    expect(supabaseAdmin.auth.admin.deleteUser).toHaveBeenCalledWith(USER_A);
  });

  it("returns 500 when auth user deletion fails", async () => {
    mockGetUser(USER_A);

    const list = vi.fn().mockResolvedValue({ data: [], error: null });
    const remove = vi.fn().mockResolvedValue({ data: [], error: null });
    vi.mocked(supabaseAdmin.storage.from).mockReturnValue({ list, remove } as never);
    vi.mocked(supabaseAdmin.rpc).mockResolvedValue({ data: null, error: null } as never);
    vi.mocked(supabaseAdmin.auth.admin.deleteUser).mockResolvedValue({
      data: { user: null },
      error: { message: "boom", name: "AuthApiError", status: 500 },
    } as never);

    const res = await app.request("/api/account", {
      method: "DELETE",
      headers: authHeaders(USER_A),
    });

    expect(res.status).toBe(500);
    const body = await res.json();
    expect(body.error).toBe("Couldn’t delete your account. Try again.");
  });
});
