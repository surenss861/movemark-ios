/** Hono context variables set by security middleware. */
export type AppVariables = {
  requestId: string;
  userId?: string;
};
