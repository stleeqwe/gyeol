// 결 (Gyeol) — post-polish validation 8가지 검사
// 매칭알고리즘 v7 §8.5

import type { RecommendationNarrative } from "./types.ts";
import { detectRawQuoteInSummary } from "./raw-quote.ts";

const EVALUATIVE_WORDS = [
  "최고",
  "완벽",
  "이상적",
  "특별한",
  "탁월한",
  "훌륭한",
  "더 나은",
  "더 좋은",
  "정말",
  "진짜",
  "참",
  "분명히",
  "확실히",
  "당연히",
  "perfect",
  "ideal",
  "best",
];

export type PolishValidationReason =
  | "raw_quote_introduced"
  | "evaluative_word_introduced"
  | "tension_dropped"
  | "boundary_language_dropped"
  | "new_domain_introduced"
  | "new_principle_introduced"
  | "json_invalid"
  | "length_out_of_range";

export interface PolishValidationResult {
  valid: boolean;
  reason?: PolishValidationReason;
  details?: string;
}

interface ValidationContext {
  /** raw 답변 합본 — n-gram 검사용 */
  rawAnswers: string;
  /** boundary_check 페어 여부 */
  isBoundaryCheck: boolean;
  /** draft에 등장하는 영역명 */
  draftDomainNames: Set<string>;
  /** draft에 등장하는 원칙명 */
  draftPrincipleNames: Set<string>;
  /** draft에서 tension narrative 길이가 0이 아니었는지 */
  draftTensionPresent: boolean;
  /** 길이 허용 폭 (0.2 → ±20%) */
  lengthTolerance: number;
}

function hasEvaluative(text: string): string | null {
  for (const w of EVALUATIVE_WORDS) {
    if (text.includes(w)) return w;
  }
  return null;
}

function hasBoundaryLanguage(text: string): boolean {
  return /(경계|선|확인|영역|입장)/.test(text);
}

function totalLength(n: RecommendationNarrative): number {
  return n.headline.length + n.alignment_narrative.length +
    n.tension_narrative.length;
}

export function validatePolishOutput(
  draft: RecommendationNarrative,
  polished: unknown,
  context: ValidationContext,
): PolishValidationResult {
  // 1) JSON valid (이미 LLM이 JSON 모드로 응답하지만 결정론 검증)
  if (
    typeof polished !== "object" ||
    polished === null ||
    typeof (polished as RecommendationNarrative).headline !== "string" ||
    typeof (polished as RecommendationNarrative).alignment_narrative !==
      "string" ||
    typeof (polished as RecommendationNarrative).tension_narrative !== "string"
  ) {
    return { valid: false, reason: "json_invalid" };
  }

  const p = polished as RecommendationNarrative;

  // 2) raw quote
  const allText =
    `${p.headline}\n${p.alignment_narrative}\n${p.tension_narrative}`;
  const rq = detectRawQuoteInSummary(allText, context.rawAnswers);
  if (rq.detected) {
    return {
      valid: false,
      reason: "raw_quote_introduced",
      details: rq.matchedPattern,
    };
  }

  // 3) evaluative
  const ev = hasEvaluative(allText);
  if (ev) {
    return { valid: false, reason: "evaluative_word_introduced", details: ev };
  }

  // 4) tension dropped (draft에 있던 tension이 사라진 경우)
  if (context.draftTensionPresent && p.tension_narrative.trim().length === 0) {
    return { valid: false, reason: "tension_dropped" };
  }

  // 5) boundary language dropped
  if (
    context.isBoundaryCheck &&
    !hasBoundaryLanguage(p.tension_narrative + " " + p.headline)
  ) {
    return { valid: false, reason: "boundary_language_dropped" };
  }

  // 6) 새 영역명
  for (
    const domName of [
      "신념",
      "사회",
      "생명",
      "가족",
      "권위",
      "일",
      "삶",
      "친밀",
    ]
  ) {
    if (allText.includes(domName) && !context.draftDomainNames.has(domName)) {
      return {
        valid: false,
        reason: "new_domain_introduced",
        details: domName,
      };
    }
  }

  // 7) 새 원칙명 — draft에 없던 원칙명이 polish에 새로 들어왔는지
  // 단순화: principle 후보 단어 8자 이상이 draft에는 없고 polish에는 있는 경우
  const newSegments = p.alignment_narrative.split(/[.,\s]+/).filter((s) =>
    s.length >= 8
  );
  for (const seg of newSegments) {
    if (!context.draftPrincipleNames.has(seg)) {
      // strict 검사가 너무 보수적일 수 있음 — 운영 단계 보강 필요
      // 1차에서는 *quotation으로 새 원칙명을 강조*하는 패턴만 차단
      if (seg.startsWith("'") || seg.startsWith('"') || seg.startsWith("「")) {
        return {
          valid: false,
          reason: "new_principle_introduced",
          details: seg,
        };
      }
    }
  }

  // 8) 길이 ±20%
  const draftLen = totalLength(draft);
  const polishedLen = totalLength(p);
  const ratio = polishedLen / Math.max(1, draftLen);
  if (
    ratio < 1 - context.lengthTolerance || ratio > 1 + context.lengthTolerance
  ) {
    return {
      valid: false,
      reason: "length_out_of_range",
      details: `ratio=${ratio.toFixed(2)}`,
    };
  }

  return { valid: true };
}

export function buildValidationContext(
  draft: RecommendationNarrative,
  rawAnswers: string,
  isBoundaryCheck: boolean,
): ValidationContext {
  const draftAll =
    `${draft.headline}\n${draft.alignment_narrative}\n${draft.tension_narrative}`;
  const segments = new Set(
    draftAll.split(/[.,\s]+/).filter((s) => s.length >= 4),
  );
  const domainNames = new Set<string>();
  for (
    const dn of ["신념", "사회", "생명", "가족", "권위", "일", "삶", "친밀"]
  ) {
    if (draftAll.includes(dn)) domainNames.add(dn);
  }
  return {
    rawAnswers,
    isBoundaryCheck,
    draftDomainNames: domainNames,
    draftPrincipleNames: segments,
    draftTensionPresent: draft.tension_narrative.trim().length > 0,
    lengthTolerance: 0.2,
  };
}
