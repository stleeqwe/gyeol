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
import { writeLlmTrace } from "../_shared/llm-trace.ts";
import { DOMAIN_IDS } from "../_shared/types.ts";

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
    const domains = new Set(
      (analyses ?? []).map((analysis) => analysis.domain),
    );
    const missingDomains = DOMAIN_IDS.filter((domain) => !domains.has(domain));
    if (error || !analyses || missingDomains.length > 0) {
      reqLog.warn("analysis_incomplete", {
        analysis_count: analyses?.length ?? 0,
        missing_domains: missingDomains,
      });
      throw new HttpError(400, "analysis_incomplete");
    }
    reqLog.info("analyses.loaded", { analysis_count: analyses.length });

    const summaryBlock = analyses.map((a) =>
      `## ${a.domain}\n- where: ${a.summary_where}\n- why: ${a.summary_why}\n- how: ${a.summary_how}\n- tension: ${
        a.summary_tension_text ?? ""
      }`
    ).join("\n\n");

    const userPromptD = `# 6영역 요약 (public_safe)\n${summaryBlock}`;
    const llmStart = performance.now();
    const { data: result, usage, thinkingSummary } = await callGeminiJson<
      PromptDResponse
    >({
      model: "gemini-3-flash",
      systemPrompt: SYSTEM_PROMPT_D,
      userPrompt: userPromptD,
      temperature: 0.3,
      maxOutputTokens: 4096,
      thinkingLevel: "high",
    });
    const llmLatencyMs = Math.round(performance.now() - llmStart);
    reqLog.info("llm.ok", {
      llm_latency_ms: llmLatencyMs,
      prompt_version: PROMPT_VERSION.D,
      model: "gemini-3-flash",
      label_chars: result.core_identity.label.length,
      interpretation_chars: result.core_identity.interpretation.length,
      input_tokens: usage?.inputTokens ?? 0,
      output_tokens: usage?.outputTokens ?? 0,
      thinking_tokens: usage?.thinkingTokens ?? 0,
    });

    await writeLlmTrace(service, {
      userId,
      functionName: "llm-prompt-d",
      promptVersion: PROMPT_VERSION.D,
      modelId: "gemini-3-flash",
      thinkingLevel: "high",
    }, {
      userPrompt: userPromptD,
      responseText: JSON.stringify(result),
      thinkingSummary,
      usage,
      latencyMs: llmLatencyMs,
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
