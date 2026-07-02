import { serve } from "@hono/node-server";
import app from "./app.js";
import { captureException, initSentry } from "./lib/sentry.js";

initSentry();

const defaultPort = process.env.NODE_ENV === "production" ? 8080 : 3000;
const port = Number(process.env.PORT) || defaultPort;
const host = "0.0.0.0";

const server = serve({
  fetch: app.fetch,
  port,
  hostname: host,
});
console.log(`[movemark-api] listening on ${host}:${port}`);

/** Railway and other hosts send SIGTERM before stopping the container; npm then logs `signal SIGTERM`. That is normal, not an app crash. */
function shutdown(signal: string) {
  console.log(
    `[movemark-api] ${signal} received — closing HTTP server (expected on redeploy/restart)`
  );
  server.close((err) => {
    if (err) {
      console.error("[movemark-api] server.close error", err);
      process.exit(1);
    }
    process.exit(0);
  });
  setTimeout(() => {
    console.error("[movemark-api] server.close timed out, exiting");
    process.exit(1);
  }, 10_000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

process.on("uncaughtException", (error) => {
  console.error("[movemark-api] uncaughtException", error);
  captureException(error);
});

process.on("unhandledRejection", (reason) => {
  console.error("[movemark-api] unhandledRejection", reason);
  captureException(reason);
});
