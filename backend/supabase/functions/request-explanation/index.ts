// 결 (Gyeol) — Edge Function: request-explanation
// Lazy MVP queue: pending matches -> explanation payload -> recommendation narrative.

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
  match_id?: string;
  limit?: number;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const body = await readJson<RequestBody>(req);
    const service = getServiceRoleClient();

    let query = service
      .from("matches")
      .select("id")
      .eq("viewer_id", userId)
      .eq("recommendation_status", "pending")
      .order("final_score", { ascending: false })
      .limit(Math.min(Math.max(body.limit ?? 30, 1), 30));
    if (body.match_id) query = query.eq("id", body.match_id);

    const { data: matches } = await query;
    const internalToken = Deno.env.get("INTERNAL_CALL_TOKEN") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    let prepared = 0;

    for (const match of matches ?? []) {
      await invokeInternal(
        `${supabaseUrl}/functions/v1/explanation-payload-builder`,
        internalToken,
        { match_id: match.id },
      );
      await invokeInternal(
        `${supabaseUrl}/functions/v1/recommendation-matrix-engine`,
        internalToken,
        { match_id: match.id },
      );
      prepared++;
    }

    return jsonResponse({ prepared });
  } catch (err) {
    return handleError(err);
  }
});

async function invokeInternal(
  url: string,
  token: string,
  body: unknown,
): Promise<void> {
  const resp = await fetch(url, {
    method: "POST",
    headers: { "x-internal-call": token, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new HttpError(resp.status, `internal_invocation_failed: ${text}`);
  }
}
