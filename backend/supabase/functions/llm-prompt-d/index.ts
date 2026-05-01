// 결 (Gyeol) — Edge Function: llm-prompt-d (통합 핵심 유형)
// AI프롬프트 v7 §2.2

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
import { PROMPT_VERSION, SYSTEM_PROMPT_D } from "../_shared/prompts.ts";
import { loggerFor } from "../_shared/logger.ts";

interface RequestBody {
  // 6영역 분석 모두 완료된 사용자 호출
}

interface PromptDResponse {
  core_identity: { label: string; interpretation: string };
}

Deno.serve(async (req) => {
  const log = loggerFor("llm-prompt-d");
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const reqLog = log.with({ user_id: userId });
    reqLog.info("core_identity.start");

    const service = getServiceRoleClient();
    const { data: analyses, error } = await service
      .from("analyses")
      .select(
        "domain, summary_where, summary_why, summary_how, summary_tension_text",
      )
      .eq("user_id", userId);
    if (error || !analyses || analyses.length < 3) {
      reqLog.warn("insufficient_analyses", {
        analysis_count: analyses?.length ?? 0,
      });
      throw new HttpError(400, "insufficient_analyses");
    }
    reqLog.info("analyses.loaded", { analysis_count: analyses.length });

    const summaryBlock = analyses.map((a) =>
      `## ${a.domain}\n- where: ${a.summary_where}\n- why: ${a.summary_why}\n- how: ${a.summary_how}\n- tension: ${
        a.summary_tension_text ?? ""
      }`
    ).join("\n\n");

    const llmStart = performance.now();
    const result = await callGeminiJson<PromptDResponse>({
      model: "gemini-3-flash",
      systemPrompt: SYSTEM_PROMPT_D,
      userPrompt: `# 6영역 요약 (public_safe)\n${summaryBlock}`,
      temperature: 0.3,
      maxOutputTokens: 1024,
    });
    reqLog.info("llm.ok", {
      llm_latency_ms: Math.round(performance.now() - llmStart),
      prompt_version: PROMPT_VERSION.D,
      model: "gemini-3-flash",
      label_chars: result.core_identity.label.length,
      interpretation_chars: result.core_identity.interpretation.length,
    });

    await service.from("core_identities").upsert({
      user_id: userId,
      profile_version: "v7",
      assessment_version: "v7.1.0",
      label: result.core_identity.label,
      interpretation: result.core_identity.interpretation,
    });
    reqLog.info("core_identity.ok");

    return jsonResponse({
      core_identity: result.core_identity,
      prompt_version: PROMPT_VERSION.D,
    });
  } catch (err) {
    return handleError(err);
  }
});
