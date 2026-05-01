// 결 (Gyeol) — Edge Function: submit-dealbreakers

import {
  getServiceRoleClient,
  getUserClient,
  handleError,
  jsonResponse,
  readJson,
  requireUserId,
} from "../_shared/supabase.ts";
import { encodeMvpCiphertext } from "../_shared/crypto-scaffold.ts";
import type { DomainId } from "../_shared/types.ts";

interface RequestBody {
  domain: DomainId;
  raw_texts: string[];
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const body = await readJson<RequestBody>(req);
    const texts = body.raw_texts
      .map((text) => text.trim())
      .filter((text) => text.length > 0)
      .slice(0, 3);

    const service = getServiceRoleClient();
    await service.from("explicit_dealbreakers")
      .delete()
      .eq("user_id", userId)
      .eq("domain", body.domain);

    if (texts.length > 0) {
      await service.from("explicit_dealbreakers").insert(
        texts.map((text, index) => ({
          user_id: userId,
          domain: body.domain,
          seq: index + 1,
          raw_user_text_ciphertext: encodeMvpCiphertext(text),
        })),
      );
    }

    return jsonResponse({ saved_count: texts.length });
  } catch (err) {
    return handleError(err);
  }
});
