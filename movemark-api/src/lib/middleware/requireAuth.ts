import { createMiddleware } from "hono/factory";
import { requireUserIdFromBearer } from "../auth.js";
import type { AppVariables } from "./types.js";
import { safeJsonError } from "./safeError.js";

export const requireAuth = createMiddleware<{ Variables: AppVariables }>(
  async (c, next) => {
    try {
      const userId = await requireUserIdFromBearer(c);
      c.set("userId", userId);
      await next();
    } catch {
      return safeJsonError(c, 401, "Unauthorized", "require_auth");
    }
  }
);

export function getUserId(c: { get: (key: "userId") => string | undefined }): string {
  const userId = c.get("userId");
  if (!userId) {
    throw new Error("Unauthorized");
  }
  return userId;
}
