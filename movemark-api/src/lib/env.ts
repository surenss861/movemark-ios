/** Comma-separated browser origins allowed for CORS (e.g. `https://app.example.com,http://localhost:5173`). */
export function corsAllowedOrigins(): string[] {
  const raw = process.env.CORS_ALLOWED_ORIGINS ?? "";
  return raw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

export const env = {
  SUPABASE_URL: process.env.SUPABASE_URL ?? "",
  SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY ?? "",
  EXPORT_BUCKET_NAME: process.env.EXPORT_BUCKET_NAME ?? "exports",
  REVENUECAT_WEBHOOK_SECRET: process.env.REVENUECAT_WEBHOOK_SECRET ?? "",
  APP_ENV: process.env.APP_ENV ?? "development",
};

export function assertEnv(): void {
  const required = [
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "EXPORT_BUCKET_NAME",
  ] as const;

  for (const key of required) {
    if (!env[key]) {
      throw new Error(`Missing required env var: ${key}`);
    }
  }

  if (env.APP_ENV === "production" && !env.REVENUECAT_WEBHOOK_SECRET) {
    throw new Error("Missing required env var: REVENUECAT_WEBHOOK_SECRET (production)");
  }
}
