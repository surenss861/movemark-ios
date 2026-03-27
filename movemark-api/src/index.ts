import { Hono } from "hono";
import { cors } from "hono/cors";
import { serve } from "@hono/node-server";
import { assertEnv } from "./lib/env.js";
import { exportsRouter } from "./routes/exports.js";
import { webhooksRouter } from "./routes/webhooks.js";

assertEnv();

const app = new Hono();

app.use("*", cors());

app.get("/", (c) => c.json({ ok: true, service: "movemark-api" }));
app.get("/api/health", (c) => c.json({ ok: true, uptime: process.uptime() }));

app.route("/api/exports", exportsRouter);
app.route("/api/webhooks", webhooksRouter);

const port = Number(process.env.PORT ?? 3000);
const host = "0.0.0.0";
serve({
  fetch: app.fetch,
  port,
  hostname: host,
});
console.log(`[movemark-api] listening on ${host}:${port}`);

process.on("uncaughtException", (error) => {
  console.error("[movemark-api] uncaughtException", error);
});

process.on("unhandledRejection", (reason) => {
  console.error("[movemark-api] unhandledRejection", reason);
});

export default app;
