// 결 (Gyeol) — Edge Function: prepare-review
// Ensures core identity and dealbreaker normalization are present before self-review.

import {
  getServiceRoleClient,
  getUserClient,
  handleError,
  HttpError,
  jsonResponse,
  requireUserId,
} from "../_shared/supabase.ts";
import { missingFinishedDomains } from "../_shared/flow-state.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const auth = req.headers.get("authorization") ?? "";
    const userClient = getUserClient(auth);
    const userId = await requireUserId(userClient);
    const service = getServiceRoleClient();

    const { data: interviews } = await service
      .from("interviews")
      .select("domain, status")
      .eq("user_id", userId);
    const missing = missingFinishedDomains(interviews ?? []);
    if (missing.length > 0) {
      throw new HttpError(400, "not_all_domains_finished");
    }

    const { data: existingCore } = await service
      .from("core_identities")
      .select("user_id")
      .eq("user_id", userId)
      .limit(1);
    let coreCreated = false;
    if ((existingCore?.length ?? 0) === 0) {
      await invokeUserFunction("llm-prompt-d", auth, {});
      coreCreated = true;
    }

    const { data: pendingDealbreakers } = await service
      .from("explicit_dealbreakers")
      .select("id")
      .eq("user_id", userId)
      .is("canonical_target_id", null)
      .limit(1);
    let dealbreakersNormalized = false;
    if ((pendingDealbreakers?.length ?? 0) > 0) {
      await invokeUserFunction("llm-prompt-e", auth, {});
      dealbreakersNormalized = true;
    }

    const { data: remainingDealbreakers } = await service
      .from("explicit_dealbreakers")
      .select("id")
      .eq("user_id", userId)
      .is("canonical_target_id", null)
      .limit(1);
    if ((remainingDealbreakers?.length ?? 0) > 0) {
      throw new HttpError(400, "dealbreakers_not_normalized");
    }

    return jsonResponse({
      status: "ready",
      core_created: coreCreated,
      dealbreakers_normalized: dealbreakersNormalized,
    });
  } catch (err) {
    return handleError(err);
  }
});

async function invokeUserFunction(
  name: string,
  auth: string,
  body: unknown,
): Promise<void> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const resp = await fetch(`${supabaseUrl}/functions/v1/${name}`, {
    method: "POST",
    headers: { authorization: auth, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new HttpError(resp.status, `${name}_failed: ${text}`);
  }
}
