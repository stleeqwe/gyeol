// 결 (Gyeol) — Edge Function: normalization-worker
// 매칭알고리즘 v5 §2 + v7 §2.2 (raw quote 차단 강화)

import {
  getServiceRoleClient,
  handleError,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/supabase.ts";
import { detectRawQuoteInAnalysis } from "../_shared/raw-quote.ts";
import { loggerFor } from "../_shared/logger.ts";
import { decodeMvpCiphertext } from "../_shared/crypto-scaffold.ts";
import type {
  DisgustPoint,
  DomainId,
  InferredDealbreaker,
  NormalizedDomainPayload,
  SacredValue,
} from "../_shared/types.ts";

interface RequestBody {
  user_id: string;
  domain_id: DomainId;
}

Deno.serve(async (req) => {
  const log = loggerFor("normalization-worker");
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
    const reqLog = log.with({
      user_id: body.user_id,
      domain_id: body.domain_id,
    });
    reqLog.info("normalize.start");
    const service = getServiceRoleClient();

    // 영역 분석 + raw answers 로드
    const { data: ana } = await service
      .from("analyses")
      .select(
        "id, summary_where, summary_why, summary_how, summary_tension_text, structured_ciphertext",
      )
      .eq("user_id", body.user_id)
      .eq("domain", body.domain_id)
      .single();
    if (!ana) throw new HttpError(404, "analysis_not_found");

    const { data: answers } = await service
      .from("interview_answers")
      .select("text_ciphertext")
      .eq("user_id", body.user_id)
      .eq("domain", body.domain_id);
    const rawAnswers = (answers ?? []).map((a) =>
      decodeMvpCiphertext(a.text_ciphertext)
    ).join("\n");

    // raw quote 2차 방어선
    const detect = detectRawQuoteInAnalysis(
      {
        where: ana.summary_where,
        why: ana.summary_why,
        how: ana.summary_how,
        tensionText: ana.summary_tension_text ?? undefined,
      },
      rawAnswers,
    );
    if (detect.detected) {
      reqLog.warn("raw_quote_detected", {
        reason: detect.reason,
        operator_review_priority: 2,
      });
      await service.from("operator_review_queue").insert({
        issue_type: "raw_quote_in_summary",
        related_user_id: body.user_id,
        related_analysis_id: ana.id,
        payload: {
          domain: body.domain_id,
          reason: detect.reason,
          matched: detect.matchedPattern,
        },
        priority: 2,
      });
      // normalized_profile에 차단 표시
      await service.from("normalized_profiles").upsert({
        user_id: body.user_id,
        profile_version: "v7",
        payload: {},
        raw_quote_detected: true,
      }, { onConflict: "user_id" });
      return jsonResponse({ status: "blocked", reason: "raw_quote" }, 422);
    }

    // structured 복호화
    const structured = JSON.parse(
      decodeMvpCiphertext(ana.structured_ciphertext),
    );

    // canonical 매핑 — 1차 단순 룰 (운영 단계 LLM-assisted 매핑 보강)
    const domainPayload = mapToNormalizedDomain(body.domain_id, structured);

    // 기존 normalized_profile 가져와 merge
    const { data: existing } = await service
      .from("normalized_profiles")
      .select("payload")
      .eq("user_id", body.user_id)
      .maybeSingle();
    const merged = {
      ...(existing?.payload ?? {}),
      [body.domain_id]: domainPayload,
    };

    await service.from("normalized_profiles").upsert({
      user_id: body.user_id,
      profile_version: "v7",
      payload: merged,
      raw_quote_detected: false,
    }, { onConflict: "user_id" });
    reqLog.info("normalize.ok", {
      principle_count: domainPayload.canonical_principles.length,
      sacred_count: domainPayload.sacred_targets.length,
      disgust_count: domainPayload.disgust_targets.length,
      dealbreaker_count: domainPayload.dealbreaker_targets.length,
      domain_salience: domainPayload.domain_salience,
    });

    return jsonResponse({ status: "ok", domain: body.domain_id });
  } catch (err) {
    return handleError(err);
  }
});

interface StructuredInput {
  surface_position: string;
  core_principle: string;
  principle_mix: {
    principle: string;
    weight: "high" | "medium" | "low";
    evidence_ids: string[];
  }[];
  sacred_values: SacredValue[];
  moral_disgust_points: DisgustPoint[];
  inferred_dealbreaker: InferredDealbreaker[];
  depth_level: "shallow" | "moderate" | "deep";
}

function mapToNormalizedDomain(
  _domain: DomainId,
  structured: StructuredInput,
): NormalizedDomainPayload {
  // canonical_principles
  const canonical_principles = structured.principle_mix.map((p) => ({
    principle: p.principle, // 이미 LLM이 canonical id로 매핑한 가정
    weight: p.weight,
  }));

  // axis_positions — 1차 단순화: principle weight 기반 -3..+3 추정
  // 운영 단계: principle ↔ axis 명시적 매핑 사전 사용
  const axis_positions: { axis: string; value: number }[] = [];

  // domain_salience — depth_level 기반
  const salience: NormalizedDomainPayload["domain_salience"] =
    structured.depth_level === "deep"
      ? "core"
      : structured.depth_level === "moderate"
      ? "important"
      : "supporting";

  return {
    canonical_principles,
    axis_positions,
    sacred_targets: structured.sacred_values,
    disgust_targets: structured.moral_disgust_points,
    dealbreaker_targets: structured.inferred_dealbreaker,
    domain_salience: salience,
  };
}
