// MoveMark — Formal dispute packet generator.
// Reads dispute (including move_out_date, received_itemized, charge_date), builds HTML packet,
// uploads to exports bucket, returns signed URL for parity with simple PDF.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface DisputeRow {
  id: string;
  property_id: string;
  user_id: string;
  title: string;
  dispute_type: string;
  status: string;
  amount_in_question: number | null;
  summary: string | null;
  move_out_date: string | null;
  received_itemized: boolean | null;
  charge_date: string | null;
  created_at: string | null;
  updated_at: string | null;
}

interface PropertyRow {
  id: string;
  title: string;
  address_line_1: string;
  address_line_2?: string;
  city: string;
  province_state: string;
  postal_code: string;
  country: string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return Response.json({ error: "Missing Authorization" }, { status: 401, headers: corsHeaders });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const body = await req.json();
    const disputeId = body?.dispute_id;
    const propertyId = body?.property_id;
    if (!disputeId || !propertyId) {
      return Response.json(
        { error: "dispute_id and property_id required" },
        { status: 400, headers: corsHeaders }
      );
    }

    const { data: dispute, error: disputeError } = await supabase
      .from("disputes")
      .select("id, property_id, user_id, title, dispute_type, status, amount_in_question, summary, move_out_date, received_itemized, charge_date, created_at, updated_at")
      .eq("id", disputeId)
      .single();

    if (disputeError || !dispute) {
      return Response.json(
        { error: "Dispute not found or access denied" },
        { status: 404, headers: corsHeaders }
      );
    }

    const { data: property, error: propError } = await supabase
      .from("properties")
      .select("id, title, address_line_1, address_line_2, city, province_state, postal_code, country")
      .eq("id", propertyId)
      .single();

    if (propError || !property) {
      return Response.json(
        { error: "Property not found or access denied" },
        { status: 404, headers: corsHeaders }
      );
    }

    const d = dispute as DisputeRow;
    const p = property as PropertyRow;

    const moveOutLabel = d.move_out_date
      ? formatDate(d.move_out_date)
      : "—";
    const itemizedLabel = d.received_itemized === true ? "Yes" : "No";
    const chargeDateLabel = d.charge_date
      ? formatDate(d.charge_date)
      : "—";

    const html = buildPacketHtml(d, p, moveOutLabel, itemizedLabel, chargeDateLabel);

    const path = `${d.user_id}/${d.property_id}/dispute_packet/${d.id}_${Date.now()}.html`;
    const { error: uploadError } = await supabase.storage
      .from("exports")
      .upload(path, html, {
        contentType: "text/html; charset=utf-8",
        upsert: true,
      });

    if (uploadError) {
      return Response.json(
        { error: "Upload failed: " + uploadError.message },
        { status: 500, headers: corsHeaders }
      );
    }

    const { data: signed, error: signError } = await supabase.storage
      .from("exports")
      .createSignedUrl(path, 3600);

    if (signError || !signed?.signedUrl) {
      return Response.json(
        { error: "Signed URL failed: " + (signError?.message ?? "unknown") },
        { status: 500, headers: corsHeaders }
      );
    }

    return Response.json(
      { signed_url: signed.signedUrl },
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return Response.json(
      { error: String(e) },
      { status: 500, headers: corsHeaders }
    );
  }
});

function formatDate(isoOrDate: string): string {
  try {
    const d = new Date(isoOrDate);
    if (isNaN(d.getTime())) return isoOrDate;
    return d.toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric" });
  } catch {
    return isoOrDate;
  }
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function buildPacketHtml(
  d: DisputeRow,
  p: PropertyRow,
  moveOutLabel: string,
  itemizedLabel: string,
  chargeDateLabel: string
): string {
  const title = escapeHtml(d.title);
  const typeLabel = escapeHtml(d.dispute_type.replace(/_/g, " "));
  const amount = d.amount_in_question != null ? `$${Number(d.amount_in_question).toFixed(2)}` : "—";
  const summary = escapeHtml(d.summary ?? "No summary provided.");
  const address = escapeHtml([p.address_line_1, p.address_line_2, p.city, p.province_state, p.postal_code, p.country].filter(Boolean).join(", "));

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>MoveMark — Formal Dispute Packet: ${title}</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 720px; margin: 0 auto; padding: 24px; color: #1a1a1a; line-height: 1.5; }
    h1 { font-size: 1.5rem; margin-bottom: 8px; }
    h2 { font-size: 1rem; color: #555; margin-top: 24px; margin-bottom: 8px; }
    .label { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; color: #666; margin-bottom: 2px; }
    .value { margin-bottom: 12px; }
    .section { margin-top: 20px; padding-top: 20px; border-top: 1px solid #eee; }
  </style>
</head>
<body>
  <h1>MoveMark — Formal Dispute Packet</h1>
  <p class="label">Generated</p>
  <p class="value">${escapeHtml(new Date().toLocaleString("en-US", { dateStyle: "long", timeStyle: "short" }))}</p>

  <div class="section">
    <h2>Property</h2>
    <p class="value">${address}</p>
  </div>

  <div class="section">
    <h2>Dispute</h2>
    <p class="label">Title</p>
    <p class="value">${title}</p>
    <p class="label">Type</p>
    <p class="value">${typeLabel}</p>
    <p class="label">Amount in question</p>
    <p class="value">${amount}</p>
    <p class="label">Move-out date</p>
    <p class="value">${moveOutLabel}</p>
    <p class="label">Itemized charges received</p>
    <p class="value">${itemizedLabel}</p>
    <p class="label">Charge date</p>
    <p class="value">${chargeDateLabel}</p>
  </div>

  <div class="section">
    <h2>Summary</h2>
    <p class="value">${summary}</p>
  </div>
</body>
</html>`;
}
