// 결 (Gyeol) — Edge Function: llm-prompt-b (영역 분석문)
// AI프롬프트 v7 §2.1

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
import { PROMPT_VERSION, SYSTEM_PROMPT_B } from "../_shared/prompts.ts";
import { detectRawQuoteInAnalysis } from "../_shared/raw-quote.ts";
import { loggerFor } from "../_shared/logger.ts";
import {
  decodeMvpCiphertext,
  encodeMvpCiphertext,
} from "../_shared/crypto-scaffold.ts";
import { writeLlmTrace } from "../_shared/llm-trace.ts";
import type { DomainAnalysis, DomainId } from "../_shared/types.ts";

interface RequestBody {
  interview_id: string;
  domain_id: DomainId;
}

Deno.serve(async (req) => {
  const log = loggerFor("llm-prompt-b");
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const body = await readJson<RequestBody>(req);
    const reqLog = log.with({ user_id: userId, domain_id: body.domain_id });
    reqLog.info("analysis.start", { interview_id: body.interview_id });

    const service = getServiceRoleClient();
    const { data: interview, error: interviewErr } = await service
      .from("interviews")
      .select("id, domain, status")
      .eq("id", body.interview_id)
      .eq("user_id", userId)
      .eq("domain", body.domain_id)
      .single();
    if (interviewErr || !interview) {
      reqLog.warn("interview_not_found", { error: interviewErr?.message });
      throw new HttpError(404, "interview_not_found");
    }
    if (interview.status !== "analyzing") {
      reqLog.warn("interview_not_analyzing", { status: interview.status });
      throw new HttpError(409, "interview_not_analyzing");
    }

    // 영역의 모든 답변 로드
    const { data: answers, error: ansErr } = await service
      .from("interview_answers")
      .select(
        "id, seq, text_ciphertext, depth_level, follow_up_question_text, is_open_question_answer",
      )
      .eq("interview_id", body.interview_id)
      .eq("user_id", userId)
      .eq("domain", body.domain_id)
      .order("seq", { ascending: true });
    if (ansErr || !answers || answers.length === 0) {
      reqLog.warn("no_answers", { error: ansErr?.message });
      throw new HttpError(400, "no_answers");
    }
    reqLog.info("answers.loaded", {
      answer_count: answers.length,
      max_depth: Math.max(...answers.map((a) => a.depth_level ?? 1)),
    });

    // 평문 합본 (LLM 입력 + raw_quote 검사용)
    const rawAnswerLines: string[] = [];
    for (const a of answers) {
      const text = decodeMvpCiphertext(a.text_ciphertext);
      if (a.is_open_question_answer) {
        rawAnswerLines.push(`# 오픈 질문 답변\n${text}\n`);
      } else {
        rawAnswerLines.push(
          `# 후속 (depth=${a.depth_level}) ${
            a.follow_up_question_text ?? ""
          }\n${text}\n`,
        );
      }
    }
    const rawAnswers = rawAnswerLines.join("\n");

    const profileVersion = "v7";
    const assessmentVersion = "v7.1.0";

    const userPromptB =
      `# 영역\n${body.domain_id}\n\n# 사용자 답변 묶음\n${rawAnswers}`;
    const llmStart = performance.now();
    const { data: analysis, usage, thinkingSummary } = await callGeminiJson<
      DomainAnalysis
    >({
      model: "gemini-3-flash",
      systemPrompt: SYSTEM_PROMPT_B,
      userPrompt: userPromptB,
      temperature: 0.3,
      maxOutputTokens: 8192,
      thinkingLevel: "high",
    });
    const llmLatencyMs = Math.round(performance.now() - llmStart);
    reqLog.info("llm.ok", {
      llm_latency_ms: llmLatencyMs,
      prompt_version: PROMPT_VERSION.B,
      model: "gemini-3-flash",
      principle_count: analysis.structured?.principle_mix?.length ?? 0,
      sacred_count: analysis.structured?.sacred_values?.length ?? 0,
      disgust_count: analysis.structured?.moral_disgust_points?.length ?? 0,
      inferred_dealbreaker_count:
        analysis.structured?.inferred_dealbreaker?.length ?? 0,
      evidence_count: analysis.answer_evidence?.length ?? 0,
      depth_level: analysis.structured?.depth_level,
      confidence: analysis.structured?.confidence_level,
      input_tokens: usage?.inputTokens ?? 0,
      output_tokens: usage?.outputTokens ?? 0,
      thinking_tokens: usage?.thinkingTokens ?? 0,
    });

    await writeLlmTrace(service, {
      userId,
      functionName: "llm-prompt-b",
      promptVersion: PROMPT_VERSION.B,
      modelId: "gemini-3-flash",
      thinkingLevel: "high",
      domain: body.domain_id,
      interviewId: body.interview_id,
    }, {
      userPrompt: userPromptB,
      responseText: JSON.stringify(analysis),
      thinkingSummary,
      usage,
      latencyMs: llmLatencyMs,
    });

    // raw quote 감지 (1차 — LLM이 따랐는지 검증)
    const detect = detectRawQuoteInAnalysis(
      {
        where: analysis.summary.where,
        why: analysis.summary.why,
        how: analysis.summary.how,
        tensionText: analysis.summary.tension?.text,
      },
      rawAnswers,
    );
    if (detect.detected) {
      reqLog.warn("raw_quote_detected", {
        reason: detect.reason,
        operator_review_priority: 3,
      });
      // operator review queue 추가 + 분석 저장 차단
      await service.from("operator_review_queue").insert({
        issue_type: "raw_quote_in_summary",
        related_user_id: userId,
        payload: {
          domain_id: body.domain_id,
          reason: detect.reason,
          matched: detect.matchedPattern,
        },
        priority: 3,
      });
      throw new HttpError(422, "raw_quote_detected");
    }

    // structured ciphertext + analyses insert
    const { data: ana, error: anaErr } = await service.from("analyses").upsert({
      user_id: userId,
      interview_id: body.interview_id,
      domain: body.domain_id,
      profile_version: profileVersion,
      assessment_version: assessmentVersion,
      summary_where: analysis.summary.where,
      summary_why: analysis.summary.why,
      summary_how: analysis.summary.how,
      summary_tension_type: analysis.summary.tension?.type ?? null,
      summary_tension_text: analysis.summary.tension?.text ?? null,
      structured_ciphertext: encodeMvpCiphertext(
        JSON.stringify(analysis.structured),
      ),
      depth_level: maxDepth(answers.map((a) => a.depth_level)),
    }, { onConflict: "user_id,domain" })
      .select("id")
      .single();
    if (anaErr || !ana) throw new HttpError(500, "analysis_insert_failed");

    // answer_evidence replace (격리)
    await service.from("answer_evidence")
      .delete()
      .eq("analysis_id", ana.id)
      .eq("user_id", userId);

    if (analysis.answer_evidence?.length) {
      const rows = analysis.answer_evidence.map((ev) => ({
        analysis_id: ana.id,
        user_id: userId,
        domain: body.domain_id,
        evidence_id: ev.evidence_id,
        quote_ciphertext: encodeMvpCiphertext(ev.quote),
        context: ev.context,
      }));
      await service.from("answer_evidence").insert(rows);
    }

    // 정규화 워커 트리거 (비동기 큐 또는 직접 호출)
    await triggerNormalization(service, userId, body.domain_id);
    reqLog.info("analysis.ok", { analysis_id: ana.id });

    return jsonResponse({
      analysis_id: ana.id,
      summary: analysis.summary,
      prompt_version: PROMPT_VERSION.B,
    });
  } catch (err) {
    return handleError(err);
  }
});

function maxDepth(levels: number[]): number {
  return levels.reduce((m, x) => Math.max(m, x ?? 1), 1);
}

async function triggerNormalization(
  service: ReturnType<typeof getServiceRoleClient>,
  userId: string,
  domainId: DomainId,
): Promise<void> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const internalToken = Deno.env.get("INTERNAL_CALL_TOKEN") ?? "";
  const resp = await fetch(`${supabaseUrl}/functions/v1/normalization-worker`, {
    method: "POST",
    headers: {
      "x-internal-call": internalToken,
      "content-type": "application/json",
    },
    body: JSON.stringify({ user_id: userId, domain_id: domainId }),
  });
  if (!resp.ok) {
    const text = await resp.text();
    await service.from("operator_review_queue").insert({
      issue_type: "normalization_failed",
      related_user_id: userId,
      payload: { domain_id: domainId, status: resp.status, body: text },
      priority: 3,
    });
    throw new HttpError(resp.status, `normalization_failed: ${text}`);
  }
}
