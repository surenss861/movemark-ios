import { Hono } from "hono";
import { deleteAccountForUser } from "../lib/deleteAccount.js";
import { getUserId, requireAuth } from "../lib/middleware/requireAuth.js";
import { safeJsonError } from "../lib/middleware/safeError.js";
import type { AppVariables } from "../lib/middleware/types.js";

export const accountRouter = new Hono<{ Variables: AppVariables }>();

accountRouter.use("*", requireAuth);

/** Permanently deletes the authenticated user's account and owned data. */
accountRouter.delete("/", async (c) => {
  const userId = getUserId(c);
  try {
    await deleteAccountForUser(userId);
    return c.body(null, 204);
  } catch (error) {
    return safeJsonError(
      c,
      500,
      "Couldn’t delete your account. Try again.",
      "delete_account",
      error
    );
  }
});
