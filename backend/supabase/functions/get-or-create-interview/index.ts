// 결 (Gyeol) — Edge Function: get-or-create-interview
// Authenticated facade for interview row creation.

import {
  getServiceRoleClient,
  getUserClient,
  handleError,
  HttpError,
  jsonResponse,
  readJson,
  requireUserId,
} from "../_shared/supabase.ts";
import { DOMAIN_IDS, type DomainId } from "../_shared/types.ts";

interface RequestBody {
  domain: DomainId;
}

const INTERVIEW_SELECT =
  "id, user_id, domain, status, skip_reason_value, is_private_kept, voice_input_used, restarted_count, started_at, finalized_at";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const body = await readJson<RequestBody>(req);
    if (!DOMAIN_IDS.includes(body.domain)) {
      throw new HttpError(400, "invalid_domain");
    }

    const service = getServiceRoleClient();
    const { data, error } = await service.from("interviews")
      .upsert({ user_id: userId, domain: body.domain }, {
        onConflict: "user_id,domain",
      })
      .select(INTERVIEW_SELECT)
      .single();

    if (error || !data) {
      throw new HttpError(500, "interview_upsert_failed");
    }
    return jsonResponse(data);
  } catch (err) {
    return handleError(err);
  }
});
