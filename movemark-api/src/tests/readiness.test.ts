import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../lib/supabase.js", () => {
  const from = vi.fn();
  const storageFrom = vi.fn();
  return {
    supabaseAdmin: {
      from,
      storage: {
        from: storageFrom,
      },
    },
  };
});

import app from "../app.js";
import { supabaseAdmin } from "../lib/supabase.js";
import { resetRateLimitsForTests } from "../lib/middleware/rateLimit.js";

beforeEach(() => {
  vi.clearAllMocks();
  resetRateLimitsForTests();
});

describe("GET /api/ready", () => {
  it("returns 200 when database and export storage are reachable", async () => {
    const dbChain = {
      select: vi.fn().mockReturnThis(),
      limit: vi.fn().mockResolvedValue({ data: [], error: null }),
    };
    vi.mocked(supabaseAdmin.from).mockReturnValue(dbChain as never);

    const list = vi.fn().mockResolvedValue({ data: [], error: null });
    vi.mocked(supabaseAdmin.storage.from).mockReturnValue({ list } as never);

    const res = await app.request("/api/ready");
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.ok).toBe(true);
    expect(body.checks).toEqual({ database: true, exportStorage: true });
  });

  it("returns 503 when a dependency check fails", async () => {
    const dbChain = {
      select: vi.fn().mockReturnThis(),
      limit: vi.fn().mockResolvedValue({ data: null, error: { message: "db down" } }),
    };
    vi.mocked(supabaseAdmin.from).mockReturnValue(dbChain as never);

    const list = vi.fn().mockResolvedValue({ data: [], error: null });
    vi.mocked(supabaseAdmin.storage.from).mockReturnValue({ list } as never);

    const res = await app.request("/api/ready");
    expect(res.status).toBe(503);
    const body = await res.json();
    expect(body.ok).toBe(false);
    expect(body.checks.database).toBe(false);
    expect(body.checks.exportStorage).toBe(true);
  });
});
