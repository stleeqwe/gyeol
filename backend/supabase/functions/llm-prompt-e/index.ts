// 결 (Gyeol) — Edge Function: llm-prompt-e (명시 dealbreaker 정규화)
// AI프롬프트 v7 §1.4.4 + §3 (Flash-Lite)

import {
  getServiceRoleClient,
  getUserClient,
  handleError,
  HttpError,
  jsonResponse,
  readJson,
  requireUserId,
} from "../_shared/supabase.ts";
import { callGeminiJson } from "../_shared/vertex.ts";
import { PROMPT_VERSION, SYSTEM_PROMPT_E } from "../_shared/prompts.ts";
import { loggerFor } from "../_shared/logger.ts";
import { decodeMvpCiphertext } from "../_shared/crypto-scaffold.ts";
import type { DomainId, Intensity, Scope, Stance } from "../_shared/types.ts";

interface PromptEItem {
  domain_id: DomainId;
  raw_user_text_excerpt_internal_only: string;
  canonical_target_id: string | null;
  unacceptable_stances: Stance[];
  intensity_min_for_conflict: Intensity;
  scope: Scope;
  confidence: "high" | "medium" | "low";
  unmapped_reason: string | null;
}

interface PromptEResponse {
  items: PromptEItem[];
}

Deno.serve(async (req) => {
  const log = loggerFor("llm-prompt-e");
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const reqLog = log.with({ user_id: userId });
    reqLog.info("dealbreaker_normalize.start");

    const service = getServiceRoleClient();

    const { data: dealbreakers, error } = await service
      .from("explicit_dealbreakers")
      .select("id, domain, seq, raw_user_text_ciphertext")
      .eq("user_id", userId)
      .is("canonical_target_id", null);
    if (error) {
      reqLog.error("load_failed", { error: error.message });
      throw new HttpError(500, "load_failed");
    }
    if (!dealbreakers?.length) {
      reqLog.info("no_pending_dealbreakers");
      return jsonResponse({ items: [], prompt_version: PROMPT_VERSION.E });
    }
    reqLog.info("dealbreakers.loaded", { pending_count: dealbreakers.length });

    // canonical_targets 사전 로드
    const { data: targets } = await service
      .from("canonical_targets")
      .select("id, domain, label_korean, aliases");
    const dictionary = (targets ?? []).map((t) =>
      `- ${t.id} | domain=${t.domain} | label=${t.label_korean} | aliases=${
        (t.aliases ?? []).join(",")
      }`
    ).join("\n");

    const userInputs = dealbreakers.map((d) => {
      const text = decodeMvpCiphertext(d.raw_user_text_ciphertext);
      return `- id=${d.id} | domain=${d.domain} | text="${text}"`;
    }).join("\n");

    const userPrompt = `
# Canonical 사전
${dictionary}

# 사용자 입력
${userInputs}

각 입력을 canonical_target_id로 매핑하고 unacceptable_stances + intensity + scope를 설정.
`;

    const llmStart = performance.now();
    const result = await callGeminiJson<PromptEResponse>({
      model: "gemini-3.1-flash-lite",
      systemPrompt: SYSTEM_PROMPT_E,
      userPrompt,
      temperature: 0.2,
      maxOutputTokens: 2048,
    });
    reqLog.info("llm.ok", {
      llm_latency_ms: Math.round(performance.now() - llmStart),
      prompt_version: PROMPT_VERSION.E,
      model: "gemini-3.1-flash-lite",
      result_count: result.items.length,
    });

    // 결과를 dealbreaker row에 반영
    let mapped = 0;
    let unmapped = 0;
    for (let i = 0; i < dealbreakers.length && i < result.items.length; i++) {
      const item = result.items[i];
      const row = dealbreakers[i];
      if (item.canonical_target_id) {
        mapped++;
        await service.from("explicit_dealbreakers")
          .update({
            canonical_target_id: item.canonical_target_id,
            unacceptable_stances: item.unacceptable_stances,
            intensity_min_for_conflict: item.intensity_min_for_conflict,
            scope: item.scope,
          })
          .eq("id", row.id);
      } else {
        unmapped++;
        // unmapped → 운영자 큐
        await service.from("operator_review_queue").insert({
          issue_type: "unmapped_dealbreaker",
          related_user_id: userId,
          payload: {
            dealbreaker_id: row.id,
            domain: row.domain,
            unmapped_reason: item.unmapped_reason,
          },
          priority: 4,
        });
      }
    }
    reqLog.info("dealbreaker_normalize.ok", { mapped, unmapped });

    return jsonResponse({
      items: result.items,
      prompt_version: PROMPT_VERSION.E,
    });
  } catch (err) {
    return handleError(err);
  }
});
