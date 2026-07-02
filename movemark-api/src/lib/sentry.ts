import * as Sentry from "@sentry/node";

let initialized = false;

/** Initializes Sentry when SENTRY_DSN is set. No-op otherwise. */
export function initSentry(): void {
  const dsn = process.env.SENTRY_DSN?.trim();
  if (!dsn || initialized) return;

  Sentry.init({
    dsn,
    environment: process.env.APP_ENV ?? "development",
    release: process.env.SENTRY_RELEASE,
    tracesSampleRate: 0,
  });
  initialized = true;
}

export function captureException(error: unknown): void {
  if (!initialized) return;
  Sentry.captureException(error);
}
