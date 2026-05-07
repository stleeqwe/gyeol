// 결 (Gyeol) — Edge Function: submit-consent
// Authenticated facade for PIPA consent recording.

import {
  getServiceRoleClient,
  getUserClient,
  handleError,
  HttpError,
  jsonResponse,
  readJson,
  requireUserId,
} from "../_shared/supabase.ts";

interface RequestBody {
  consent_text_version: string;
  ip_address?: string | null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const body = await readJson<RequestBody>(req);
    const version = body.consent_text_version?.trim();
    if (!version) {
      throw new HttpError(400, "consent_text_version_required");
    }

    const service = getServiceRoleClient();
    const { data, error } = await service.from("consents")
      .insert({
        user_id: userId,
        sensitive_data_processing: true,
        voice_on_device_disclosed: true,
        raw_quote_isolation_disclosed: true,
        no_ai_training_disclosed: true,
        data_residency_disclosed: true,
        consent_text_version: version,
        ip_address: body.ip_address ?? null,
        user_agent: req.headers.get("user-agent"),
      })
      .select("id")
      .single();

    if (error || !data) {
      throw new HttpError(500, "consent_insert_failed");
    }
    return jsonResponse({ consent_id: data.id, has_active_consent: true });
  } catch (err) {
    return handleError(err);
  }
});
