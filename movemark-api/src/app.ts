import { Hono } from "hono";
import { cors } from "hono/cors";
import { assertEnv, corsAllowedOrigins } from "./lib/env.js";
import { requestIdMiddleware } from "./lib/middleware/requestId.js";
import { rateLimitHealthByIp } from "./lib/middleware/rateLimit.js";
import type { AppVariables } from "./lib/middleware/types.js";
import { checkReadiness } from "./lib/readiness.js";
import { accountRouter } from "./routes/account.js";
import { propertyCapabilitiesRouter } from "./routes/capabilities.js";
import { disputesRouter } from "./routes/disputes.js";
import { exportsRouter } from "./routes/exports.js";
import { vaultsRouter } from "./routes/vaults.js";
import { webhooksRouter } from "./routes/webhooks.js";

assertEnv();

const app = new Hono<{ Variables: AppVariables }>();

/** Browser cross-origin only; native apps typically omit `Origin` and do not rely on CORS. Never use `*`. */
const allowedOrigins = corsAllowedOrigins();
app.use("*", requestIdMiddleware);
app.use(
  "*",
  cors({
    origin: (origin) => {
      if (!origin) return null;
      if (allowedOrigins.length === 0) return null;
      return allowedOrigins.includes(origin) ? origin : null;
    },
    allowHeaders: ["Authorization", "Content-Type", "X-Request-Id"],
    allowMethods: ["GET", "POST", "DELETE", "OPTIONS"],
    exposeHeaders: ["X-Request-Id"],
  })
);

app.get("/", (c) => c.json({ ok: true, service: "movemark-api" }));
app.get("/api/health", rateLimitHealthByIp, (c) =>
  c.json({ ok: true, uptime: process.uptime() })
);

app.get("/api/ready", rateLimitHealthByIp, async (c) => {
  const result = await checkReadiness();
  if (!result.ok) {
    return c.json(
      {
        ok: false,
        checks: result.checks,
      },
      503
    );
  }
  return c.json({ ok: true, checks: result.checks }, 200);
});

app.route("/api/exports", exportsRouter);
app.route("/api/vaults", vaultsRouter);
app.route("/api/disputes", disputesRouter);
app.route("/api/properties", propertyCapabilitiesRouter);
app.route("/api/account", accountRouter);
app.route("/api/webhooks", webhooksRouter);

export default app;
