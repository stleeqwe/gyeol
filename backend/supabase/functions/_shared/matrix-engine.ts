// 결 (Gyeol) — 추천 이유 매트릭스 엔진 (결정론)
// 매칭알고리즘 v7 §8 + 매트릭스엔진 v3

import type {
  AlignmentByDomain,
  AnalysisSummary,
  CompatibilityAssessmentBasic,
  ExplanationPayload,
  ExplanationPayloadDomain,
  RecommendationNarrative,
} from "./types.ts";
import { DOMAIN_LABELS_KO } from "./types.ts";

const TEMPLATE_LIBRARY_VERSION = "v3.1.0";

interface ViewerCandidateContext {
  viewerCoreLabel: string;
  candidateCoreLabel: string;
  candidateCoreInterpretation: string;
  candidateSummariesByDomain: Partial<Record<string, AnalysisSummary>>;
}

function topAlignmentDomains(
  payload: ExplanationPayload,
  alignmentByDomain: AlignmentByDomain[],
  limit = 2,
): ExplanationPayloadDomain[] {
  const lookup = new Map(alignmentByDomain.map((a) => [a.domain_id, a]));
  return [...payload.alignment_by_domain]
    .filter((d) => {
      const base = lookup.get(d.domain_id);
      return base?.alignment_level === "strong" ||
        base?.alignment_level === "moderate";
    })
    .sort((a, b) => {
      const ba = lookup.get(b.domain_id)?.alignment_score ?? 0;
      const aa = lookup.get(a.domain_id)?.alignment_score ?? 0;
      return ba - aa;
    })
    .slice(0, limit);
}

function topTensionDomains(
  payload: ExplanationPayload,
  alignmentByDomain: AlignmentByDomain[],
  limit = 2,
): ExplanationPayloadDomain[] {
  const lookup = new Map(alignmentByDomain.map((a) => [a.domain_id, a]));
  return [...payload.alignment_by_domain]
    .filter((d) => {
      const base = lookup.get(d.domain_id);
      return base?.alignment_level === "tension" ||
        base?.alignment_level === "soft_conflict";
    })
    .sort((a, b) => {
      const ba = lookup.get(b.domain_id)?.tension_score ?? 0;
      const aa = lookup.get(a.domain_id)?.tension_score ?? 0;
      return ba - aa;
    })
    .slice(0, limit);
}

function buildHeadline(
  basic: CompatibilityAssessmentBasic,
  payload: ExplanationPayload,
  ctx: ViewerCandidateContext,
): string {
  const top = topAlignmentDomains(payload, basic.alignment_by_domain, 1)[0];
  if (basic.qualitative_label === "boundary") {
    const bcp = payload.boundary_check_payload;
    if (bcp) {
      const dom = DOMAIN_LABELS_KO[bcp.domain_id];
      return `${dom}에서 당신의 경계를 다시 묻는 사람`;
    }
    return "경계를 함께 살펴봐야 하는 사람";
  }
  if (top) {
    const principle = top.pair_reason_atoms.shared_principles[0];
    if (principle) {
      return `${principle.label}을 공유하는 사람`;
    }
    const sacred = top.pair_reason_atoms.shared_sacred_targets[0];
    if (sacred) {
      return `같이 무겁게 두는 영역이 있는 사람`;
    }
    return `${DOMAIN_LABELS_KO[top.domain_id]}에서 결이 닿는 사람`;
  }
  return "결을 함께 살펴볼 사람";
}

function buildAlignmentNarrative(
  payload: ExplanationPayload,
  alignmentByDomain: AlignmentByDomain[],
  ctx: ViewerCandidateContext,
): string {
  const tops = topAlignmentDomains(payload, alignmentByDomain, 2);
  if (tops.length === 0) {
    return "닿는 영역을 찾기는 어렵습니다.";
  }
  const sentences = tops.map((d) => d.public_alignment_sentence).filter((s) =>
    s.length > 0
  );
  return sentences.join(" ");
}

function buildTensionNarrative(
  payload: ExplanationPayload,
  alignmentByDomain: AlignmentByDomain[],
  ctx: ViewerCandidateContext,
): string {
  const tops = topTensionDomains(payload, alignmentByDomain, 2);
  if (tops.length === 0) return "";
  const sentences = tops.map((d) => d.public_tension_sentence).filter((s) =>
    s.length > 0
  );
  if (payload.boundary_check_payload) {
    const bcp = payload.boundary_check_payload;
    const dom = DOMAIN_LABELS_KO[bcp.domain_id];
    sentences.push(
      `${dom} 영역의 ${bcp.viewer_boundary}에 대한 입장이 ${bcp.candidate_position}로 다릅니다. 이 부분을 확인해야 합니다.`,
    );
  }
  return sentences.join(" ");
}

export function assembleDraftNarrative(
  basic: CompatibilityAssessmentBasic,
  payload: ExplanationPayload,
  ctx: ViewerCandidateContext,
): RecommendationNarrative {
  return {
    headline: buildHeadline(basic, payload, ctx),
    alignment_narrative: buildAlignmentNarrative(
      payload,
      basic.alignment_by_domain,
      ctx,
    ),
    tension_narrative: buildTensionNarrative(
      payload,
      basic.alignment_by_domain,
      ctx,
    ),
  };
}

/** 후편집 평가 함수 — draft narrative가 LLM 후편집이 필요한지 결정.
 *  needs_polish=true 인 페어만 LLM-C 호출.
 *  매칭알고리즘 v7 §8.3 + 매트릭스 엔진 v3.
 */
export function evaluateDraftQuality(draft: RecommendationNarrative): {
  needsPolish: boolean;
  reasons: string[];
} {
  const reasons: string[] = [];

  // 1) 너무 짧은 narrative
  const allText = [
    draft.headline,
    draft.alignment_narrative,
    draft.tension_narrative,
  ].join(" ");
  if (allText.length < 80) reasons.push("too_short");

  // 2) 같은 단어 반복 (어색)
  const words = draft.alignment_narrative.split(/\s+/);
  const wordCounts = new Map<string, number>();
  for (const w of words) {
    if (w.length < 2) continue;
    wordCounts.set(w, (wordCounts.get(w) ?? 0) + 1);
  }
  for (const [w, c] of wordCounts) {
    if (c >= 4) {
      reasons.push("repetitive_word");
      break;
    }
  }

  // 3) tension narrative가 boundary_check인데 너무 평이
  if (draft.headline.includes("경계") && draft.tension_narrative.length < 50) {
    reasons.push("boundary_too_terse");
  }

  // 4) 헤드라인이 다소 일반화 ("결을 함께 살펴볼 사람")
  if (
    draft.headline === "결을 함께 살펴볼 사람" ||
    draft.headline === "경계를 함께 살펴봐야 하는 사람"
  ) {
    reasons.push("generic_headline");
  }

  return { needsPolish: reasons.length > 0, reasons };
}

export const TEMPLATE_LIBRARY = {
  version: TEMPLATE_LIBRARY_VERSION,
};
