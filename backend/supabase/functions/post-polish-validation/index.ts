// 결 (Gyeol) — Edge Function: post-polish-validation (외부 호출용)
// 매칭알고리즘 v7 §8.5 — 단독 검증 엔드포인트.
// recommendation-matrix-engine 안에서 inline 호출하지만, 외부에서 단독 검증할 때도 사용.

import {
  handleError,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/supabase.ts";
import {
  buildValidationContext,
  validatePolishOutput,
} from "../_shared/post-polish-validation.ts";
import { loggerFor } from "../_shared/logger.ts";
import type { RecommendationNarrative } from "../_shared/types.ts";

interface RequestBody {
  draft: RecommendationNarrative;
  polished: RecommendationNarrative;
  raw_answers: string;
  is_boundary_check: boolean;
}

Deno.serve(async (req) => {
  const log = loggerFor("post-polish-validation");
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    if (
      req.headers.get("x-internal-call") !== Deno.env.get("INTERNAL_CALL_TOKEN")
    ) {
      log.warn("unauthorized.internal_call_token_mismatch");
      throw new HttpError(401, "internal_only");
    }
    const body = await readJson<RequestBody>(req);
    const ctx = buildValidationContext(
      body.draft,
      body.raw_answers,
      body.is_boundary_check,
    );
    const result = validatePolishOutput(body.draft, body.polished, ctx);
    log.info("validation.done", {
      valid: result.valid,
      reason: result.reason ?? null,
      is_boundary_check: body.is_boundary_check,
    });
    return jsonResponse(result);
  } catch (err) {
    return handleError(err);
  }
});
