// 결 (Gyeol) — Edge Function: llm-prompt-a (후속 질문 생성)
// AI프롬프트 v7 §2 + 시스템설계 v3 §4

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
import { PROMPT_VERSION, SYSTEM_PROMPT_A } from "../_shared/prompts.ts";
import { loggerFor } from "../_shared/logger.ts";
import { decodeMvpCiphertext } from "../_shared/crypto-scaffold.ts";
import { writeLlmTrace } from "../_shared/llm-trace.ts";
import type { DomainId } from "../_shared/types.ts";

interface RequestBody {
  interview_id: string;
  domain_id: DomainId;
  parent_answer_id: string; // 직전 답변
}

interface PromptAResponse {
  follow_up_question: string;
  rationale_internal: string;
}

Deno.serve(async (req) => {
  const log = loggerFor("llm-prompt-a");
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const body = await readJson<RequestBody>(req);
    const reqLog = log.with({ user_id: userId, domain_id: body.domain_id });
    reqLog.info("follow_up.start", { interview_id: body.interview_id });

    const service = getServiceRoleClient();
    // 직전 답변과 영역 컨텍스트 로드
    const { data: parent, error: parentErr } = await service
      .from("interview_answers")
      .select("id, interview_id, domain, seq, depth_level, text_ciphertext")
      .eq("id", body.parent_answer_id)
      .eq("user_id", userId)
      .single();
    if (parentErr || !parent) {
      reqLog.warn("parent_answer_not_found", {
        parent_answer_id: body.parent_answer_id,
      });
      throw new HttpError(404, "parent_answer_not_found");
    }
    if (
      parent.interview_id.toLowerCase() !== body.interview_id.toLowerCase() ||
      parent.domain !== body.domain_id
    ) {
      reqLog.warn("context_mismatch");
      throw new HttpError(400, "context_mismatch");
    }

    // raw 답변 평문 복호화 — 1차 스캐폴드. 운영 단계 application-level decryption 필요.
    const decrypted = decodeMvpCiphertext(parent.text_ciphertext);

    const userPrompt =
      `# 영역\n${body.domain_id}\n\n# 사용자 답변\n${decrypted}\n\n# 깊이 단계\n${parent.depth_level}`;

    const llmStart = performance.now();
    const { data: response, usage, thinkingSummary } = await callGeminiJson<
      PromptAResponse
    >({
      model: "gemini-3-flash",
      systemPrompt: SYSTEM_PROMPT_A,
      userPrompt,
      temperature: 0.6,
      maxOutputTokens: 2048,
      thinkingLevel: "high",
      jsonSchema: {
        type: "object",
        required: ["follow_up_question", "rationale_internal"],
        properties: {
          follow_up_question: { type: "string", minLength: 5 },
          rationale_internal: { type: "string" },
        },
      },
    });
    const llmLatencyMs = Math.round(performance.now() - llmStart);
    reqLog.info("follow_up.ok", {
      depth_level: parent.depth_level,
      llm_latency_ms: llmLatencyMs,
      prompt_version: PROMPT_VERSION.A,
      model: "gemini-3-flash",
      question_chars: response.follow_up_question.length,
      input_tokens: usage?.inputTokens ?? 0,
      output_tokens: usage?.outputTokens ?? 0,
      thinking_tokens: usage?.thinkingTokens ?? 0,
    });

    await writeLlmTrace(service, {
      userId,
      functionName: "llm-prompt-a",
      promptVersion: PROMPT_VERSION.A,
      modelId: "gemini-3-flash",
      thinkingLevel: "high",
      domain: body.domain_id,
      interviewId: body.interview_id,
      parentAnswerId: body.parent_answer_id,
    }, {
      userPrompt,
      responseText: JSON.stringify(response),
      thinkingSummary,
      usage,
      latencyMs: llmLatencyMs,
    });

    return jsonResponse({
      follow_up_question: response.follow_up_question,
      prompt_version: PROMPT_VERSION.A,
    });
  } catch (err) {
    return handleError(err);
  }
});
