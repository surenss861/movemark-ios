export type RevenueCatWebhookEvent = {
  api_version?: string;
  event?: {
    id?: string;
    type?: string;
    app_user_id?: string;
    product_id?: string;
    entitlement_ids?: string[];
    environment?: string;
    purchased_at_ms?: number;
    expiration_at_ms?: number | null;
    aliases?: string[];
    original_app_user_id?: string;
  };
};
