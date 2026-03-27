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
}
