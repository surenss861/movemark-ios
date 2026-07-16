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
  /** Optional HS256 JWT secret for local token verify (Project Settings → API → JWT Secret). */
  SUPABASE_JWT_SECRET: process.env.SUPABASE_JWT_SECRET ?? "",
  EXPORT_BUCKET_NAME: process.env.EXPORT_BUCKET_NAME ?? "exports",
  EVIDENCE_BUCKET_NAME: process.env.EVIDENCE_BUCKET_NAME ?? "inspection-media",
  REVENUECAT_WEBHOOK_SECRET: process.env.REVENUECAT_WEBHOOK_SECRET ?? "",
  /** Optional Redis/Upstash URL for shared rate limits across replicas. */
  REDIS_URL: process.env.REDIS_URL ?? "",
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
