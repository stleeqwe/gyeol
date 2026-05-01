// 결 (Gyeol) — Edge Function: llm-prompt-c-postedit (추천 narrative 후편집)
// AI프롬프트 v7 §3 + 매칭알고리즘 v7 §8.4

import {
  getServiceRoleClient,
  handleError,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/supabase.ts";
import { callGeminiJson } from "../_shared/vertex.ts";
import { PROMPT_VERSION, SYSTEM_PROMPT_C } from "../_shared/prompts.ts";
import { loggerFor } from "../_shared/logger.ts";
import type { RecommendationNarrative } from "../_shared/types.ts";

interface RequestBody {
  draft: RecommendationNarrative;
  viewer_core_label: string;
  candidate_core_label: string;
  candidate_core_interpretation: string;
}

Deno.serve(async (req) => {
  const log = loggerFor("llm-prompt-c-postedit");
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    // service_role 호출 전제 (내부 Edge Function 트리거)
    if (
      req.headers.get("x-internal-call") !== Deno.env.get("INTERNAL_CALL_TOKEN")
    ) {
      log.warn("unauthorized.internal_call_token_mismatch");
      throw new HttpError(401, "internal_only");
    }
    const body = await readJson<RequestBody>(req);
    log.info("postedit.start", {
      draft_headline_chars: body.draft.headline.length,
      draft_alignment_chars: body.draft.alignment_narrative.length,
      draft_tension_chars: body.draft.tension_narrative.length,
    });

    const userPrompt = `
# 후보의 통합 핵심 유형
${body.candidate_core_label}
${body.candidate_core_interpretation}

# Viewer의 통합 핵심 유형
${body.viewer_core_label}

# Draft narrative
${JSON.stringify(body.draft, null, 2)}

# 지시
원본 의미를 유지한 채 톤·연결성·읽힘새만 다듬어 polished JSON으로 응답.
`;

    const llmStart = performance.now();
    const polished = await callGeminiJson<RecommendationNarrative>({
      model: "gemini-3.1-flash-lite",
      systemPrompt: SYSTEM_PROMPT_C,
      userPrompt,
      temperature: 0.3,
      maxOutputTokens: 1024,
      jsonSchema: {
        type: "object",
        required: ["headline", "alignment_narrative", "tension_narrative"],
        properties: {
          headline: { type: "string", minLength: 4, maxLength: 80 },
          alignment_narrative: { type: "string", maxLength: 800 },
          tension_narrative: { type: "string", maxLength: 800 },
        },
      },
    });
    log.info("postedit.ok", {
      llm_latency_ms: Math.round(performance.now() - llmStart),
      prompt_version: PROMPT_VERSION.C,
      model: "gemini-3.1-flash-lite",
      polished_headline_chars: polished.headline.length,
      polished_alignment_chars: polished.alignment_narrative.length,
      polished_tension_chars: polished.tension_narrative.length,
    });

    return jsonResponse({
      polished,
      prompt_version: PROMPT_VERSION.C,
    });
  } catch (err) {
    return handleError(err);
  }
});
