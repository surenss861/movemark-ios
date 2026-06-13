import { randomUUID } from "node:crypto";
import { createMiddleware } from "hono/factory";
import type { AppVariables } from "./types.js";

export const requestIdMiddleware = createMiddleware<{ Variables: AppVariables }>(
  async (c, next) => {
    const incoming = c.req.header("X-Request-Id")?.trim();
    const requestId =
      incoming && incoming.length <= 128 ? incoming : randomUUID();
    c.set("requestId", requestId);
    c.header("X-Request-Id", requestId);
    await next();
  }
);

export function logRequest(
  c: { get: (key: "requestId") => string; req: { method: string; path: string } },
  message: string,
  extra?: Record<string, unknown>
): void {
  console.log(
    JSON.stringify({
      level: "info",
      requestId: c.get("requestId"),
      method: c.req.method,
      path: c.req.path,
      message,
      ...extra,
    })
  );
}
