// 결 (Gyeol) — Edge Function: recommendation-matrix-engine (4단계)
// 매칭알고리즘 v7 §8 + 매트릭스 엔진 v3
//
// 흐름:
//  1) draft_narrative 결정론 조립
//  2) needs_polish 평가 → 캐시 확인 → LLM-C 호출 → post-polish-validation
//  3) matches.recommendation_narrative + status=ready 갱신

import {
  getServiceRoleClient,
  handleError,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/supabase.ts";
import {
  assembleDraftNarrative,
  evaluateDraftQuality,
  TEMPLATE_LIBRARY,
} from "../_shared/matrix-engine.ts";
import {
  buildValidationContext,
  validatePolishOutput,
} from "../_shared/post-polish-validation.ts";
import {
  computeDraftHash,
  computePolishCacheKey,
} from "../_shared/cache-key.ts";
import { loggerFor } from "../_shared/logger.ts";
import { decodeMvpCiphertext } from "../_shared/crypto-scaffold.ts";
import type {
  AnalysisSummary,
  CompatibilityAssessmentBasic,
  ExplanationPayload,
  RecommendationNarrative,
} from "../_shared/types.ts";

interface RequestBody {
  match_id: string;
}

const POLISH_PROMPT_VERSION = "C.v7.0";

Deno.serve(async (req) => {
  const log = loggerFor("recommendation-matrix-engine");
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
    const reqLog = log.with({ match_id: body.match_id });
    reqLog.info("matrix.start");
    const service = getServiceRoleClient();

    const { data: m, error } = await service
      .from("matches")
      .select(
        "id, viewer_id, candidate_id, qualitative_label, queue_reason, compatibility_assessment_basic, explanation_payload, assessment_version",
      )
      .eq("id", body.match_id)
      .single();
    if (error || !m || !m.explanation_payload) {
      reqLog.warn("explanation_not_built", {
        has_match: !!m,
        error: error?.message,
      });
      throw new HttpError(400, "explanation_not_built");
    }

    const basic = m
      .compatibility_assessment_basic as CompatibilityAssessmentBasic;
    const payload = m.explanation_payload as ExplanationPayload;

    // viewer / candidate core_identity + summaries
    const [
      { data: viewerCore },
      { data: candidateCore },
      { data: candidateAnalyses },
    ] = await Promise.all([
      service.from("core_identities").select(
        "label, interpretation, profile_version",
      ).eq("user_id", m.viewer_id).single(),
      service.from("core_identities").select(
        "label, interpretation, profile_version",
      ).eq("user_id", m.candidate_id).single(),
      service.from("analyses").select(
        "domain, summary_where, summary_why, summary_how, summary_tension_text",
      ).eq("user_id", m.candidate_id),
    ]);
    if (!viewerCore || !candidateCore) {
      reqLog.warn("core_identity_missing", {
        viewer: !!viewerCore,
        candidate: !!candidateCore,
      });
      throw new HttpError(400, "core_identity_missing");
    }

    const candidateSummariesByDomain: Partial<Record<string, AnalysisSummary>> =
      {};
    for (const a of candidateAnalyses ?? []) {
      candidateSummariesByDomain[a.domain] = {
        where: a.summary_where,
        why: a.summary_why,
        how: a.summary_how,
        tension: a.summary_tension_text
          ? { type: "", text: a.summary_tension_text }
          : undefined,
      };
    }

    // 1) draft 조립
    const draft = assembleDraftNarrative(basic, payload, {
      viewerCoreLabel: viewerCore.label,
      candidateCoreLabel: candidateCore.label,
      candidateCoreInterpretation: candidateCore.interpretation,
      candidateSummariesByDomain,
    });
    reqLog.info("draft.assembled", {
      qualitative_label: basic.qualitative_label,
      queue_reason: basic.queue_reason,
      headline_chars: draft.headline.length,
      alignment_chars: draft.alignment_narrative.length,
      tension_chars: draft.tension_narrative.length,
    });

    // 2) needs_polish 평가
    const evaluation = evaluateDraftQuality(draft);
    reqLog.info("polish.evaluation", {
      needs_polish: evaluation.needsPolish,
      reasons: evaluation.reasons,
    });

    let finalNarrative: RecommendationNarrative = draft;
    let polishApplied = false;
    let polishValidationPassed = true;
    let polishFailureReason: string | null = null;
    let cacheKey: string | null = null;

    if (evaluation.needsPolish) {
      const draftHash = await computeDraftHash(draft);
      cacheKey = await computePolishCacheKey({
        viewerId: m.viewer_id,
        candidateId: m.candidate_id,
        viewerProfileVersion: viewerCore.profile_version,
        candidateProfileVersion: candidateCore.profile_version,
        assessmentVersion: m.assessment_version,
        templateLibraryVersion: TEMPLATE_LIBRARY.version,
        polishPromptVersion: POLISH_PROMPT_VERSION,
        draftHash,
      });

      // 캐시 확인
      const { data: cached } = await service.from("polished_output_cache")
        .select(
          "polished_headline, polished_alignment_narrative, polished_tension_narrative, validation_passed, validation_failure_reason, expires_at",
        )
        .eq("cache_key", cacheKey)
        .gt("expires_at", new Date().toISOString())
        .maybeSingle();

      let polished: RecommendationNarrative | null = null;
      let validationPassed = false;

      if (cached && cached.validation_passed) {
        polished = {
          headline: cached.polished_headline,
          alignment_narrative: cached.polished_alignment_narrative,
          tension_narrative: cached.polished_tension_narrative,
        };
        validationPassed = true;
        reqLog.info("polish.cache_hit", {
          cache_key_prefix: cacheKey.slice(0, 8),
        });
      } else {
        // LLM-C 호출
        reqLog.info("polish.cache_miss", {
          cache_key_prefix: cacheKey.slice(0, 8),
        });
        const internalToken = Deno.env.get("INTERNAL_CALL_TOKEN") ?? "";
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
        const llmStart = performance.now();
        const polishResp = await fetch(
          `${supabaseUrl}/functions/v1/llm-prompt-c-postedit`,
          {
            method: "POST",
            headers: {
              "x-internal-call": internalToken,
              "content-type": "application/json",
            },
            body: JSON.stringify({
              draft,
              viewer_core_label: viewerCore.label,
              candidate_core_label: candidateCore.label,
              candidate_core_interpretation: candidateCore.interpretation,
            }),
          },
        );
        const llmLatencyMs = Math.round(performance.now() - llmStart);
        if (!polishResp.ok) {
          polishFailureReason = `polish_llm_${polishResp.status}`;
          reqLog.error("polish.llm_call_failed", {
            http_status: polishResp.status,
            latency_ms: llmLatencyMs,
          });
        } else {
          const polishJson = await polishResp.json();
          const candidate = polishJson.polished as RecommendationNarrative;
          reqLog.info("polish.llm_call_ok", {
            latency_ms: llmLatencyMs,
            prompt_version: POLISH_PROMPT_VERSION,
          });

          // raw 답변 합본 (validation 입력)
          const { data: viewerAnswers } = await service
            .from("interview_answers")
            .select("text_ciphertext")
            .eq("user_id", m.viewer_id);
          const rawAnswers = (viewerAnswers ?? []).map((a) =>
            decodeMvpCiphertext(a.text_ciphertext)
          ).join("\n");

          const ctx = buildValidationContext(
            draft,
            rawAnswers,
            m.queue_reason === "boundary_check",
          );
          const validation = validatePolishOutput(draft, candidate, ctx);
          reqLog.info("polish.validation", {
            valid: validation.valid,
            reason: validation.reason ?? null,
          });

          if (validation.valid) {
            polished = candidate;
            validationPassed = true;
            // 캐시 저장
            await service.from("polished_output_cache").upsert({
              cache_key: cacheKey,
              viewer_id: m.viewer_id,
              candidate_id: m.candidate_id,
              viewer_profile_version: viewerCore.profile_version,
              candidate_profile_version: candidateCore.profile_version,
              assessment_version: m.assessment_version,
              template_library_version: TEMPLATE_LIBRARY.version,
              polish_prompt_version: POLISH_PROMPT_VERSION,
              draft_hash: draftHash,
              polished_headline: polished.headline,
              polished_alignment_narrative: polished.alignment_narrative,
              polished_tension_narrative: polished.tension_narrative,
              validation_passed: true,
              expires_at: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000)
                .toISOString(),
            });
            reqLog.info("polish.cache_saved", {
              cache_key_prefix: cacheKey.slice(0, 8),
            });
          } else {
            polishFailureReason = validation.reason ?? "unknown";
            reqLog.warn("polish.validation_failed", {
              reason: validation.reason,
              fallback_to_draft: true,
            });
            await service.from("operator_review_queue").insert({
              issue_type: "polish_validation_failed",
              related_match_id: m.id,
              payload: {
                reason: validation.reason,
                details: validation.details,
              },
              priority: 5,
            });
          }
        }
      }

      if (polished) {
        finalNarrative = polished;
        polishApplied = true;
        polishValidationPassed = validationPassed;
      } else {
        polishApplied = false;
        polishValidationPassed = false;
      }
    }

    // 3) matches 갱신
    await service.from("matches").update({
      recommendation_narrative: finalNarrative,
      polish_cache_key: cacheKey,
      polish_applied: polishApplied,
      polish_validation_passed: polishValidationPassed,
      polish_failure_reason: polishFailureReason,
      recommendation_status: "ready",
    }).eq("id", m.id);
    reqLog.info("matrix.ok", {
      polish_applied: polishApplied,
      polish_validation_passed: polishValidationPassed,
      polish_failure_reason: polishFailureReason,
      recommendation_status: "ready",
    });

    return jsonResponse({
      match_id: m.id,
      status: "ready",
      polish_applied: polishApplied,
      polish_validation_passed: polishValidationPassed,
    });
  } catch (err) {
    return handleError(err);
  }
});
