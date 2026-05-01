// 결 (Gyeol) — Edge Function: raw-quote-detector (외부 호출용)
// 매칭알고리즘 v7 §2.2

import {
  handleError,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/supabase.ts";
import {
  detectRawQuoteInAnalysis,
  detectRawQuoteInSummary,
} from "../_shared/raw-quote.ts";
import { loggerFor } from "../_shared/logger.ts";

interface RequestBody {
  text?: string;
  fields?: { where: string; why: string; how: string; tensionText?: string };
  raw_answers: string;
  ngram_min_length?: number;
}

Deno.serve(async (req) => {
  const log = loggerFor("raw-quote-detector");
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
    if (body.fields) {
      const result = detectRawQuoteInAnalysis(body.fields, body.raw_answers);
      log.info("detect.fields", {
        detected: result.detected,
        reason: result.reason ?? null,
      });
      return jsonResponse(result);
    }
    if (body.text) {
      const result = detectRawQuoteInSummary(body.text, body.raw_answers, {
        ngramMinLength: body.ngram_min_length,
      });
      log.info("detect.text", {
        detected: result.detected,
        reason: result.reason ?? null,
        ngram_min_length: body.ngram_min_length ?? 8,
      });
      return jsonResponse(result);
    }
    throw new HttpError(400, "text_or_fields_required");
  } catch (err) {
    return handleError(err);
  }
});
