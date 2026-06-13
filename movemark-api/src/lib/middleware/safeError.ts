import type { Context } from "hono";
import type { AppVariables } from "./types.js";

export function safeJsonError(
  c: Context<{ Variables: AppVariables }>,
  status: 400 | 401 | 403 | 404 | 409 | 429 | 500,
  publicMessage: string,
  logLabel?: string,
  internalError?: unknown
): Response {
  if (internalError !== undefined) {
    console.error(
      JSON.stringify({
        level: "error",
        requestId: c.get("requestId"),
        method: c.req.method,
        path: c.req.path,
        label: logLabel ?? "api_error",
        error:
          internalError instanceof Error
            ? internalError.message
            : String(internalError),
      })
    );
  }
  return c.json({ error: publicMessage }, status);
}

export function isUnauthorizedError(error: unknown): boolean {
  return error instanceof Error && error.message === "Unauthorized";
}
