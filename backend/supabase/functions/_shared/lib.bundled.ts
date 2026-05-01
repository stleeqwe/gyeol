// 결 (Gyeol) — bundled lib

import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2.45.4";

// ─── types.ts ───
// 결 (Gyeol) — 공통 타입
// AI프롬프트 v7 §1.4 + 매칭알고리즘 v7 §4 + 시스템설계 v3 §3.1

export type DomainId =
  | "belief"
  | "society"
  | "bioethics"
  | "family"
  | "work_life"
  | "intimacy";

export const DOMAIN_IDS: DomainId[] = [
  "belief",
  "society",
  "bioethics",
  "family",
  "work_life",
  "intimacy",
];

export const DOMAIN_LABELS_KO: Record<DomainId, string> = {
  belief: "신념 체계",
  society: "사회와 개인",
  bioethics: "생명 윤리",
  family: "가족과 권위",
  work_life: "일과 삶",
  intimacy: "친밀함",
};

export type Stance =
  | "require"
  | "support"
  | "allow"
  | "neutral"
  | "avoid"
  | "reject";

export type Intensity = "strong" | "moderate" | "mild";

export type Scope =
  | "self"
  | "partner"
  | "children"
  | "household"
  | "public_policy";

export type AlignmentLevel =
  | "strong"
  | "moderate"
  | "tension"
  | "soft_conflict";

export type QualitativeLabel = "alignment" | "compromise" | "boundary";

export type QueueReason = "top_match" | "boundary_check";

export type RecommendationStatus =
  | "pending"
  | "ready"
  | "needs_review_hidden"
  | "fallback_shown";

// AI 프롬프트 v7 §1.4.2 — 영역 분석 출력
export interface AnalysisSummary {
  where: string; // public_safe
  why: string; // public_safe
  how: string; // public_safe
  tension?: { type: string; text: string };
}

export interface PrincipleMix {
  principle: string;
  weight: "high" | "medium" | "low";
  evidence_ids: string[]; // v7: evidence_quote 폐기, ids만
}

export interface SacredValue {
  target: string;
  stance: Stance;
  intensity: Intensity;
  scope: Scope;
  evidence_ids: string[];
}

export interface DisgustPoint {
  target: string;
  intensity: Intensity;
  evidence_ids: string[];
}

export interface InferredDealbreaker {
  target: string;
  unacceptable_stances: Stance[];
  intensity_min_for_conflict: Intensity;
  scope: Scope;
  confidence: "high" | "medium" | "low";
}

export interface AnalysisStructured {
  surface_position: string;
  core_principle: string;
  principle_mix: PrincipleMix[];
  sacred_values: SacredValue[];
  moral_disgust_points: DisgustPoint[];
  edge_conditions: { condition: string; expected_behavior: string }[];
  self_interest_stability: "stable" | "uncertain" | "shifting";
  loved_one_stability: "stable" | "uncertain" | "shifting";
  opposing_view_tolerance: "high" | "medium" | "low";
  non_negotiables: { boundary: string; intensity: "strong" | "moderate" }[];
  inferred_dealbreaker: InferredDealbreaker[];
  confidence_level: "high" | "medium" | "low";
  depth_level: "shallow" | "moderate" | "deep";
}

export interface AnswerEvidence {
  evidence_id: string; // ev_001
  quote: string; // self_review_only
  context: string;
}

export interface DomainAnalysis {
  domain_id: DomainId;
  summary: AnalysisSummary;
  structured: AnalysisStructured;
  answer_evidence: AnswerEvidence[];
}

// 매칭알고리즘 v7 §4.3
export interface AlignmentByDomain {
  domain_id: DomainId;
  alignment_level: AlignmentLevel;
  alignment_score?: number; // 운영 분석용
  tension_score?: number; // 운영 분석용
  alignment_summary: string;
}

export interface CompatibilityAssessmentBasic {
  assessment_version: string;
  final_score: number;
  qualitative_label: QualitativeLabel;
  comparable_domain_count: number;
  comparable_domain_weight_sum: number;
  alignment_by_domain: AlignmentByDomain[];
  shared_sacred_targets: string[];
  queue_reason: QueueReason;
}

// 매칭알고리즘 v7 §4.4
export interface PairReasonAtoms {
  shared_principles: { principle_id: string; label: string }[];
  different_principles: {
    viewer_position: string;
    candidate_position: string;
  }[];
  shared_sacred_targets: string[];
  shared_rejection_targets: string[];
  tension_targets: string[];
}

export interface ExplanationPayloadDomain {
  domain_id: DomainId;
  public_alignment_sentence: string;
  public_tension_sentence: string;
  pair_reason_atoms: PairReasonAtoms;
}

export interface BoundaryCheckPayload {
  domain_id: DomainId;
  source: "inferred_dealbreaker" | "explicit_dealbreaker";
  viewer_boundary: string;
  candidate_position: string;
  confidence: "high" | "medium" | "low";
}

export interface ExplanationPayload {
  viewer_id: string;
  candidate_id: string;
  alignment_by_domain: ExplanationPayloadDomain[];
  boundary_check_payload: BoundaryCheckPayload | null;
}

// 매트릭스 엔진 — 추천 narrative
export interface RecommendationNarrative {
  headline: string;
  alignment_narrative: string;
  tension_narrative: string;
}

// normalized_profile (정규화 레이어 산출)
export interface NormalizedDomainPayload {
  canonical_principles: {
    principle: string;
    weight: "high" | "medium" | "low";
  }[];
  axis_positions: { axis: string; value: number }[]; // -3..+3
  sacred_targets: SacredValue[];
  disgust_targets: DisgustPoint[];
  dealbreaker_targets: InferredDealbreaker[];
  domain_salience: "core" | "important" | "supporting";
}

export interface NormalizedProfile {
  user_id: string;
  profile_version: string;
  payload: Partial<Record<DomainId, NormalizedDomainPayload>>;
}

// ─── stance-distance.ts ───
// 결 (Gyeol) — stance distance matrix
// 매칭알고리즘 v7 §4.4.5

export const STANCE_DISTANCE: Record<Stance, Record<Stance, number>> = {
  require: {
    require: 0,
    support: 1,
    allow: 2,
    neutral: 3,
    avoid: 4,
    reject: 5,
  },
  support: {
    require: 1,
    support: 0,
    allow: 1,
    neutral: 2,
    avoid: 3,
    reject: 4,
  },
  allow: { require: 2, support: 1, allow: 0, neutral: 1, avoid: 2, reject: 3 },
  neutral: {
    require: 3,
    support: 2,
    allow: 1,
    neutral: 0,
    avoid: 1,
    reject: 2,
  },
  avoid: { require: 4, support: 3, allow: 2, neutral: 1, avoid: 0, reject: 1 },
  reject: { require: 5, support: 4, allow: 3, neutral: 2, avoid: 1, reject: 0 },
};

const INTENSITY_RANK: Record<Intensity, number> = {
  mild: 1,
  moderate: 2,
  strong: 3,
};

export function maxIntensity(a: Intensity, b: Intensity): Intensity {
  return INTENSITY_RANK[a] >= INTENSITY_RANK[b] ? a : b;
}

/** 매칭알고리즘 v7 §4.4.5: distance>=3 AND max intensity >= moderate → tension */
export function isTensionTarget(
  viewerStance: Stance,
  candidateStance: Stance,
  viewerIntensity: Intensity,
  candidateIntensity: Intensity,
): boolean {
  const distance = STANCE_DISTANCE[viewerStance][candidateStance];
  const max = maxIntensity(viewerIntensity, candidateIntensity);
  return distance >= 3 && (max === "moderate" || max === "strong");
}

/** require/support + strong/moderate 양측 → shared_sacred */
export function isSharedSacred(
  viewerStance: Stance,
  candidateStance: Stance,
  viewerIntensity: Intensity,
  candidateIntensity: Intensity,
): boolean {
  const supportLike = (s: Stance) => s === "require" || s === "support";
  const moderateUp = (i: Intensity) => i === "moderate" || i === "strong";
  return (
    supportLike(viewerStance) &&
    supportLike(candidateStance) &&
    moderateUp(viewerIntensity) &&
    moderateUp(candidateIntensity)
  );
}

/** reject/avoid + strong/moderate 양측 → shared_rejection (v7 §4.4.4) */
export function isSharedRejection(
  viewerStance: Stance,
  candidateStance: Stance,
  viewerIntensity: Intensity,
  candidateIntensity: Intensity,
): boolean {
  const rejectLike = (s: Stance) => s === "reject" || s === "avoid";
  const moderateUp = (i: Intensity) => i === "moderate" || i === "strong";
  return (
    rejectLike(viewerStance) &&
    rejectLike(candidateStance) &&
    moderateUp(viewerIntensity) &&
    moderateUp(candidateIntensity)
  );
}

// ─── raw-quote.ts ───
// 결 (Gyeol) — raw quote detector
// 매칭알고리즘 v7 §2.2 + AI프롬프트 v7 §1.3
// 3중 방어선 중 2차 (정규화 레이어). 1차는 LLM 자체, 3차는 매트릭스 엔진.

const QUOTE_PATTERNS: RegExp[] = [
  /(['"][^'"]{5,}['"])/u, // "..." 또는 '...' 5자 이상
  /([「『].{4,}?[」』])/u, // 한국 따옴표
  /(<<.{4,}?>>)/u,
];

/** n-gram (substring) overlap 검사 — 8자 이상 연속 일치
 *  단순한 sliding window. 운영 단계에서 normalize(공백, 조사, 대소문자) 보강 필요.
 */
function ngramOverlap(text: string, source: string, minLength = 8): boolean {
  if (text.length < minLength || source.length < minLength) return false;
  const t = text.replace(/\s+/g, " ");
  const s = source.replace(/\s+/g, " ");
  for (let i = 0; i + minLength <= t.length; i++) {
    const slice = t.slice(i, i + minLength);
    if (s.includes(slice)) return true;
  }
  return false;
}

export interface RawQuoteCheckResult {
  detected: boolean;
  reason?: "quote_pattern" | "ngram_overlap";
  matchedPattern?: string;
}

/** summary 텍스트에 raw quote가 포함되었는지 검사.
 *  rawAnswers는 현재 사용자가 영역에 작성한 모든 raw 답변 합본.
 */
export function detectRawQuoteInSummary(
  summary: string,
  rawAnswers: string,
  options: { ngramMinLength?: number } = {},
): RawQuoteCheckResult {
  const minLen = options.ngramMinLength ?? 8;

  for (const pat of QUOTE_PATTERNS) {
    const m = summary.match(pat);
    if (m) {
      return { detected: true, reason: "quote_pattern", matchedPattern: m[0] };
    }
  }
  if (ngramOverlap(summary, rawAnswers, minLen)) {
    return { detected: true, reason: "ngram_overlap" };
  }
  return { detected: false };
}

/** 분석 객체의 모든 public_safe 필드를 일괄 검사 */
export function detectRawQuoteInAnalysis(
  fields: { where: string; why: string; how: string; tensionText?: string },
  rawAnswers: string,
): RawQuoteCheckResult {
  for (const [key, value] of Object.entries(fields)) {
    if (!value) continue;
    const r = detectRawQuoteInSummary(value, rawAnswers);
    if (r.detected) {
      return {
        ...r,
        matchedPattern: `${key}: ${r.matchedPattern ?? "(ngram)"}`,
      };
    }
  }
  return { detected: false };
}

// ─── scoring.ts ───
// 결 (Gyeol) — 호환 점수 계산 결정론
// 매칭알고리즘 v5 §4 (호환 점수) + v7 §4.3 (basic 산출)

const ASSESSMENT_VERSION = "v7.1.0";

const DOMAIN_WEIGHTS: Record<DomainId, number> = {
  // Salience-augmented in compute step. base weights = equal.
  belief: 1.0,
  society: 1.0,
  bioethics: 1.0,
  family: 1.0,
  work_life: 1.0,
  intimacy: 1.0,
};

// salience boost (domain_salience='core' → 1.5x, 'important' → 1.0x, 'supporting' → 0.6x)
const SALIENCE_MULTIPLIER: Record<
  NormalizedDomainPayload["domain_salience"],
  number
> = {
  core: 1.5,
  important: 1.0,
  supporting: 0.6,
};

interface AlignmentResult {
  level: AlignmentLevel;
  score: number; // 0..1
  tension: number; // 0..1
  summary: string;
}

function principlesOverlap(
  a: NormalizedDomainPayload,
  b: NormalizedDomainPayload,
): { sharedHigh: number; sharedAny: number; differing: number } {
  const aMap = new Map(
    a.canonical_principles.map((p) => [p.principle, p.weight]),
  );
  const bMap = new Map(
    b.canonical_principles.map((p) => [p.principle, p.weight]),
  );

  let sharedHigh = 0;
  let sharedAny = 0;
  let differing = 0;
  for (const [pid, aw] of aMap) {
    const bw = bMap.get(pid);
    if (bw) {
      sharedAny++;
      if (aw === "high" && bw === "high") sharedHigh++;
    } else if (aw === "high") {
      differing++;
    }
  }
  for (const [pid, bw] of bMap) {
    if (!aMap.has(pid) && bw === "high") differing++;
  }
  return { sharedHigh, sharedAny, differing };
}

function axesAlignment(
  a: NormalizedDomainPayload,
  b: NormalizedDomainPayload,
): number {
  const aMap = new Map(a.axis_positions.map((x) => [x.axis, x.value]));
  const bMap = new Map(b.axis_positions.map((x) => [x.axis, x.value]));
  const common: number[] = [];
  for (const [k, av] of aMap) {
    const bv = bMap.get(k);
    if (bv === undefined) continue;
    // 거리 (max 6 — 양 극단 -3..+3) → 1 - dist/6
    common.push(1 - Math.min(6, Math.abs(av - bv)) / 6);
  }
  if (!common.length) return 0.5;
  return common.reduce((s, x) => s + x, 0) / common.length;
}

function tensionFromTargets(
  a: NormalizedDomainPayload,
  b: NormalizedDomainPayload,
): number {
  // sacred_targets stance pair에서 tension 비율
  const aMap = new Map(a.sacred_targets.map((t) => [t.target, t]));
  const bMap = new Map(b.sacred_targets.map((t) => [t.target, t]));
  let tensionCount = 0;
  let pairCount = 0;
  for (const [k, av] of aMap) {
    const bv = bMap.get(k);
    if (!bv) continue;
    pairCount++;
    if (STANCE_DISTANCE[av.stance][bv.stance] >= 3) tensionCount++;
  }
  if (pairCount === 0) return 0;
  return tensionCount / pairCount;
}

function determineLevel(score: number, tension: number): AlignmentLevel {
  if (score >= 0.7 && tension < 0.2) return "strong";
  if (score >= 0.5 && tension < 0.4) return "moderate";
  if (tension >= 0.6) return "soft_conflict";
  return "tension";
}

function summaryText(
  domainId: DomainId,
  level: AlignmentLevel,
  score: number,
): string {
  const labels = {
    strong: "결이 강하게 닿습니다",
    moderate: "결이 닿는 부분이 있습니다",
    tension: "결의 차이가 있습니다",
    soft_conflict: "결이 충돌하는 부분이 있습니다",
  } as const;
  const pct = Math.round(score * 100);
  return `${labels[level]} (호환 ${pct}%)`;
}

function computeDomainAlignment(
  a: NormalizedDomainPayload,
  b: NormalizedDomainPayload,
): AlignmentResult {
  const { sharedHigh, sharedAny } = principlesOverlap(a, b);
  const principleScore = sharedAny === 0 ? 0.4 : Math.min(
    1,
    (sharedHigh + sharedAny * 0.5) /
      Math.max(1, a.canonical_principles.length),
  );
  const axisScore = axesAlignment(a, b);
  const score = principleScore * 0.5 + axisScore * 0.5;
  const tension = tensionFromTargets(a, b);
  const level = determineLevel(score, tension);
  return { level, score, tension, summary: "" };
}

function sharedSacredTargets(
  aProfile: NormalizedProfile,
  bProfile: NormalizedProfile,
): string[] {
  const out = new Set<string>();
  for (const domainId of DOMAIN_IDS) {
    const a = aProfile.payload[domainId];
    const b = bProfile.payload[domainId];
    if (!a || !b) continue;
    const aMap = new Map(a.sacred_targets.map((t) => [t.target, t]));
    for (const bt of b.sacred_targets) {
      const at = aMap.get(bt.target);
      if (!at) continue;
      if (
        isSharedSacred(at.stance, bt.stance, at.intensity, bt.intensity) &&
        (at.scope === bt.scope || at.scope === "partner" ||
          bt.scope === "partner")
      ) {
        out.add(bt.target);
      }
    }
  }
  return [...out];
}

function pickQualitative(
  finalScore: number,
  alignmentByDomain: AlignmentByDomain[],
  hasUnresolvedDealbreaker: boolean,
): { label: QualitativeLabel; queue: QueueReason } {
  if (hasUnresolvedDealbreaker) {
    return { label: "boundary", queue: "boundary_check" };
  }
  if (finalScore >= 0.65) return { label: "alignment", queue: "top_match" };
  if (finalScore >= 0.45) return { label: "compromise", queue: "top_match" };
  return { label: "boundary", queue: "boundary_check" };
}

/** 1단계 — 전체 페어 호환 점수 (basic).
 *  매칭알고리즘 v7 §4.3.
 *  hasUnresolvedDealbreaker은 충돌매트릭스 v2의 User Hard 필터 통과 후 잔존 dealbreaker 신호.
 */
export function computeCompatibilityBasic(
  viewer: NormalizedProfile,
  candidate: NormalizedProfile,
  options: { hasUnresolvedDealbreaker?: boolean } = {},
): CompatibilityAssessmentBasic {
  const alignmentByDomain: AlignmentByDomain[] = [];
  let weightSum = 0;
  let weightedScoreSum = 0;
  let comparable = 0;

  for (const domainId of DOMAIN_IDS) {
    const a = viewer.payload[domainId];
    const b = candidate.payload[domainId];
    if (!a || !b) continue;
    comparable++;
    const r = computeDomainAlignment(a, b);
    const w = DOMAIN_WEIGHTS[domainId] *
      ((SALIENCE_MULTIPLIER[a.domain_salience] +
        SALIENCE_MULTIPLIER[b.domain_salience]) / 2);
    weightSum += w;
    weightedScoreSum += w * r.score;
    alignmentByDomain.push({
      domain_id: domainId,
      alignment_level: r.level,
      alignment_score: Number(r.score.toFixed(3)),
      tension_score: Number(r.tension.toFixed(3)),
      alignment_summary: summaryText(domainId, r.level, r.score),
    });
  }

  const finalScore = weightSum > 0 ? weightedScoreSum / weightSum : 0;
  const sharedSacred = sharedSacredTargets(viewer, candidate);

  const { label, queue } = pickQualitative(
    finalScore,
    alignmentByDomain,
    !!options.hasUnresolvedDealbreaker,
  );

  return {
    assessment_version: ASSESSMENT_VERSION,
    final_score: Number(finalScore.toFixed(3)),
    qualitative_label: label,
    queue_reason: queue,
    comparable_domain_count: comparable,
    comparable_domain_weight_sum: Number(weightSum.toFixed(3)),
    alignment_by_domain: alignmentByDomain,
    shared_sacred_targets: sharedSacred,
  };
}

// ─── explanation.ts ───
// 결 (Gyeol) — explanation_payload + boundary_check_payload 산출
// 매칭알고리즘 v7 §4.4 + §4.5

interface PrincipleLabelMap {
  [principleId: string]: string;
}

function buildAtoms(
  vd: NormalizedDomainPayload,
  cd: NormalizedDomainPayload,
  principleLabels: PrincipleLabelMap,
): PairReasonAtoms {
  // shared_principles
  const vSet = new Map(
    vd.canonical_principles.map((p) => [p.principle, p.weight]),
  );
  const sharedPrinciples: { principle_id: string; label: string }[] = [];
  for (const cp of cd.canonical_principles) {
    const vw = vSet.get(cp.principle);
    if (!vw) continue;
    if (vw === "high" || cp.weight === "high") {
      sharedPrinciples.push({
        principle_id: cp.principle,
        label: principleLabels[cp.principle] ?? cp.principle,
      });
    }
  }

  // different_principles — 같은 axis상의 반대 leans (단순화: principle 다르고 양쪽 high)
  const cMap = new Map(
    cd.canonical_principles.map((p) => [p.principle, p.weight]),
  );
  const differentPrinciples: {
    viewer_position: string;
    candidate_position: string;
  }[] = [];
  for (const vp of vd.canonical_principles) {
    if (vp.weight !== "high") continue;
    if (cMap.has(vp.principle)) continue;
    // viewer high 그러나 candidate에 부재 — 후보의 high principle 1개와 페어
    const cHigh = cd.canonical_principles.find((cp) =>
      cp.weight === "high" && !vSet.has(cp.principle)
    );
    if (cHigh) {
      differentPrinciples.push({
        viewer_position: principleLabels[vp.principle] ?? vp.principle,
        candidate_position: principleLabels[cHigh.principle] ?? cHigh.principle,
      });
    }
  }

  // shared sacred
  const vSacred = new Map(vd.sacred_targets.map((t) => [t.target, t]));
  const sharedSacred: string[] = [];
  for (const ct of cd.sacred_targets) {
    const vt = vSacred.get(ct.target);
    if (!vt) continue;
    if (isSharedSacred(vt.stance, ct.stance, vt.intensity, ct.intensity)) {
      sharedSacred.push(ct.target);
    }
  }

  // shared rejection (v7 §4.4.4)
  const sharedRejection: string[] = [];
  for (const ct of cd.disgust_targets) {
    const vt = vd.disgust_targets.find((d) => d.target === ct.target);
    if (!vt) continue;
    // disgust_targets는 stance 없이 intensity만 가진다 → reject로 간주
    if (
      (vt.intensity === "moderate" || vt.intensity === "strong") &&
      (ct.intensity === "moderate" || ct.intensity === "strong")
    ) {
      sharedRejection.push(ct.target);
    }
  }
  // sacred_targets에서 reject/avoid + reject/avoid 페어도 포함 (v7 명세)
  for (const ct of cd.sacred_targets) {
    const vt = vSacred.get(ct.target);
    if (!vt) continue;
    if (isSharedRejection(vt.stance, ct.stance, vt.intensity, ct.intensity)) {
      if (!sharedRejection.includes(ct.target)) sharedRejection.push(ct.target);
    }
  }

  // tension_targets
  const tensionTargets: string[] = [];
  for (const ct of cd.sacred_targets) {
    const vt = vSacred.get(ct.target);
    if (!vt) continue;
    if (isTensionTarget(vt.stance, ct.stance, vt.intensity, ct.intensity)) {
      tensionTargets.push(ct.target);
    }
  }

  return {
    shared_principles: sharedPrinciples,
    different_principles: differentPrinciples,
    shared_sacred_targets: sharedSacred,
    shared_rejection_targets: sharedRejection,
    tension_targets: tensionTargets,
  };
}

function publicSentence(
  domainId: DomainId,
  atoms: PairReasonAtoms,
  kind: "alignment" | "tension",
): string {
  const domainLabel = DOMAIN_LABELS_KO[domainId];
  if (kind === "alignment") {
    if (atoms.shared_principles.length > 0) {
      const principleLabels = atoms.shared_principles.slice(0, 2).map((p) =>
        p.label
      ).join(", ");
      return `${domainLabel} 영역에서 ${principleLabels} 원칙을 공유합니다.`;
    }
    if (atoms.shared_sacred_targets.length > 0) {
      return `${domainLabel} 영역에서 같이 무겁게 두는 영역이 있습니다.`;
    }
    if (atoms.shared_rejection_targets.length > 0) {
      return `${domainLabel} 영역에서 같이 거리를 두는 점이 있습니다.`;
    }
    return `${domainLabel} 영역에서 결이 닿는 부분이 있습니다.`;
  } else {
    if (atoms.tension_targets.length > 0) {
      return `${domainLabel} 영역에서 다른 결을 가집니다.`;
    }
    if (atoms.different_principles.length > 0) {
      const dp = atoms.different_principles[0];
      return `${domainLabel} 영역에서 ${dp.viewer_position}와 ${dp.candidate_position}로 결이 다릅니다.`;
    }
    return "";
  }
}

export function buildExplanationPayload(
  viewer: NormalizedProfile,
  candidate: NormalizedProfile,
  alignmentByDomain: AlignmentByDomain[],
  principleLabels: PrincipleLabelMap,
): ExplanationPayload {
  const out: ExplanationPayloadDomain[] = [];
  for (const ad of alignmentByDomain) {
    const vd = viewer.payload[ad.domain_id];
    const cd = candidate.payload[ad.domain_id];
    if (!vd || !cd) continue;
    const atoms = buildAtoms(vd, cd, principleLabels);
    out.push({
      domain_id: ad.domain_id,
      public_alignment_sentence: publicSentence(
        ad.domain_id,
        atoms,
        "alignment",
      ),
      public_tension_sentence: publicSentence(ad.domain_id, atoms, "tension"),
      pair_reason_atoms: atoms,
    });
  }
  return {
    viewer_id: viewer.user_id,
    candidate_id: candidate.user_id,
    alignment_by_domain: out,
    boundary_check_payload: null,
  };
}

/** 매칭알고리즘 v7 §4.5 — boundary_check 페어 dealbreaker 추적 */
export function buildBoundaryCheckPayload(
  viewer: NormalizedProfile,
  candidate: NormalizedProfile,
  explicitDealbreakers: {
    domain: DomainId;
    canonical_target_id: string | null;
    raw_user_text?: string;
    unacceptable_stances: Stance[];
  }[],
  targetLabels: Record<string, string>,
): BoundaryCheckPayload | null {
  // 1) explicit_dealbreaker 우선
  for (const db of explicitDealbreakers) {
    if (!db.canonical_target_id) continue;
    const cd = candidate.payload[db.domain];
    if (!cd) continue;
    const candidateTarget = cd.sacred_targets.find((t) =>
      t.target === db.canonical_target_id
    );
    if (
      candidateTarget &&
      db.unacceptable_stances.includes(candidateTarget.stance)
    ) {
      return {
        domain_id: db.domain,
        source: "explicit_dealbreaker",
        viewer_boundary: db.raw_user_text ||
          targetLabels[db.canonical_target_id] || db.canonical_target_id,
        candidate_position: targetLabels[candidateTarget.target] ||
          candidateTarget.target,
        confidence: "high",
      };
    }
  }
  // 2) inferred_dealbreaker
  for (const domainId of DOMAIN_IDS) {
    const vd = viewer.payload[domainId];
    const cd = candidate.payload[domainId];
    if (!vd || !cd) continue;
    for (const idb of vd.dealbreaker_targets) {
      const ct = cd.sacred_targets.find((t) => t.target === idb.target);
      if (ct && idb.unacceptable_stances.includes(ct.stance)) {
        return {
          domain_id: domainId,
          source: "inferred_dealbreaker",
          viewer_boundary: targetLabels[idb.target] || idb.target,
          candidate_position: targetLabels[ct.target] || ct.target,
          confidence: idb.confidence,
        };
      }
    }
  }
  return null;
}

// ─── matrix-engine.ts ───
// 결 (Gyeol) — 추천 이유 매트릭스 엔진 (결정론)
// 매칭알고리즘 v7 §8 + 매트릭스엔진 v3

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

// ─── post-polish-validation.ts ───
// 결 (Gyeol) — post-polish validation 8가지 검사
// 매칭알고리즘 v7 §8.5

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

// ─── cache-key.ts ───
// 결 (Gyeol) — polished_output_cache 키 산출 (방향성 분리)
// 매칭알고리즘 v7 §8.4

const enc = new TextEncoder();

async function sha256(input: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", enc.encode(input));
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function computeDraftHash(
  draft: RecommendationNarrative,
): Promise<string> {
  return await sha256(
    [draft.headline, draft.alignment_narrative, draft.tension_narrative].join(
      "",
    ),
  );
}

/** 매칭알고리즘 v7 §8.4 — viewer_id 명시. A→B와 B→A 분리.
 *  candidate_brief가 viewer 기준이므로 narrative가 viewer마다 다름 → 캐시도 분리.
 */
export async function computePolishCacheKey(input: {
  viewerId: string;
  candidateId: string;
  viewerProfileVersion: string;
  candidateProfileVersion: string;
  assessmentVersion: string;
  templateLibraryVersion: string;
  polishPromptVersion: string;
  draftHash: string;
}): Promise<string> {
  const seed = [
    input.viewerId,
    input.candidateId,
    input.viewerProfileVersion,
    input.candidateProfileVersion,
    input.assessmentVersion,
    input.templateLibraryVersion,
    input.polishPromptVersion,
    input.draftHash,
  ].join("");
  return await sha256(seed);
}

// ─── prompts.ts ───
// 결 (Gyeol) — LLM 시스템 프롬프트 (A·B·C·D·E)
// AI프롬프트 v7 §2

export const PROMPT_VERSION = {
  A: "A.v7.0",
  B: "B.v7.0",
  C: "C.v7.0",
  D: "D.v7.0",
  E: "E.v7.0",
} as const;

const COMMON_SAFETY = `
# 출력 안전성 제약 (v7 — 모든 프롬프트 공통)

당신은 결혼 또는 매우 진지한 장기 연애를 목표로 하는 가치관 매칭 앱의 분석 LLM이다.

원칙:
1. 사용자의 raw 답변에서 직접 인용하지 않는다 (paraphrase만).
2. 평가어("최고", "완벽한", "이상적") 사용 금지.
3. 매칭 상대에게 노출되는 필드(public_safe로 표시된 필드)에는 사용자가 답변에서 사용한 5단어 이상의 연속 표현을 그대로 옮기지 않는다.
4. 사용자 어조나 구어체를 그대로 옮기지 않는다.
5. JSON으로만 응답한다. 추가 텍스트, 주석, 설명 금지.
`;

export const SYSTEM_PROMPT_A = `
${COMMON_SAFETY}

# 프롬프트 A — 후속 질문 생성

입력: 사용자가 한 영역의 오픈 질문에 답한 직후의 답변.

당신의 역할: 그 답변에서 *결*이 더 분명히 드러날 수 있는 후속 질문 1개를 만든다.

원칙:
- 사용자의 답변에서 보이는 *작동 원리*를 짧게 paraphrase하고, 그것이 부서질 수 있는 edge case 한 가지를 묻는다.
- 비난 톤 금지. 호기심 톤.
- 한 번에 한 가지만 묻는다.
- 질문 길이 2-3문장.

출력 JSON:
{
  "follow_up_question": "string [public_safe]",
  "rationale_internal": "string"
}
`;

export const SYSTEM_PROMPT_B = `
${COMMON_SAFETY}

# 프롬프트 B — 영역 분석문 생성 (v7)

입력: 한 영역(belief / society / bioethics / family / work_life / intimacy)의 모든 답변.

# 출력 안전성 제약 (v7)

당신의 출력 중 다음 필드는 매칭 상대에게 노출됩니다 (match_visible):
- summary.where
- summary.why
- summary.how
- summary.tension.text

이 필드들에는 사용자의 raw 답변에서 직접 인용한 표현을 포함하지 않습니다. 직접 인용 대신 사용자 답변의 작동 원리를 본인의 언어로 paraphrase합니다.

structured 필드는 internal_only이므로 raw quote가 들어가도 외부 노출 안 됩니다. 다만 v7부터 structured.principle_mix[].evidence_quote 필드는 폐기되었으므로, raw quote는 answer_evidence 배열에만 저장합니다.

answer_evidence는 self_review_only — 본인이 발행 전 검토할 때만 보입니다. 매칭 상대에게는 노출되지 않습니다.

# 자가 검증 (출력 직전)

- summary.where, summary.why, summary.how, summary.tension.text에 raw quote(따옴표 또는 5단어 이상 연속 표현)가 있는가? → 제거하고 paraphrase로 대체
- structured.principle_mix에 evidence_quote 필드가 있는가? → 제거 (v7에서 폐기됨)
- raw quote는 answer_evidence에만 있는가? → 확인

# 출력 스키마

{
  "domain_id": "belief"|"society"|"bioethics"|"family"|"work_life"|"intimacy",
  "summary": {
    "where": "string [public_safe]",
    "why": "string [public_safe]",
    "how": "string [public_safe]",
    "tension": { "type": "string", "text": "string [public_safe]" }
  },
  "structured": {
    "surface_position": "string",
    "core_principle": "string",
    "principle_mix": [{ "principle": "string", "weight": "high"|"medium"|"low", "evidence_ids": ["string"] }],
    "sacred_values": [{ "target": "string", "stance": "require"|"support"|"allow"|"neutral"|"avoid"|"reject", "intensity": "strong"|"moderate"|"mild", "scope": "self"|"partner"|"children"|"household"|"public_policy", "evidence_ids": ["string"] }],
    "moral_disgust_points": [{ "target": "string", "intensity": "strong"|"moderate"|"mild", "evidence_ids": ["string"] }],
    "edge_conditions": [{ "condition": "string", "expected_behavior": "string" }],
    "self_interest_stability": "stable"|"uncertain"|"shifting",
    "loved_one_stability": "stable"|"uncertain"|"shifting",
    "opposing_view_tolerance": "high"|"medium"|"low",
    "non_negotiables": [{ "boundary": "string", "intensity": "strong"|"moderate" }],
    "inferred_dealbreaker": [{ "target": "string", "unacceptable_stances": ["string"], "intensity_min_for_conflict": "strong"|"moderate"|"mild", "scope": "string", "confidence": "high"|"medium"|"low" }],
    "confidence_level": "high"|"medium"|"low",
    "depth_level": "shallow"|"moderate"|"deep"
  },
  "answer_evidence": [
    { "evidence_id": "ev_001", "quote": "string [self_review_only]", "context": "string" }
  ]
}
`;

export const SYSTEM_PROMPT_C = `
${COMMON_SAFETY}

# 프롬프트 C — 추천 이유 후편집 (v6)

입력: 결정론적 매트릭스 엔진이 조립한 draft narrative + viewer/candidate context.

당신의 역할: 같은 의미를 유지한 채 톤·연결성·읽힘새를 다듬는다.

원칙:
- 의미를 추가하거나 변경하지 않는다.
- 새 영역명, 새 원칙명을 도입하지 않는다.
- 원본 길이의 ±20% 이내.
- raw quote, 평가어, 새 단어 도입 금지.
- tension/boundary 표현이 draft에 있다면 polished에도 유지.

출력 JSON:
{
  "headline": "string",
  "alignment_narrative": "string",
  "tension_narrative": "string"
}
`;

export const SYSTEM_PROMPT_D = `
${COMMON_SAFETY}

# 프롬프트 D — 통합 핵심 유형 (v7)

입력: 6영역 분석문 모두.

# 출력 안전성 제약 (v7)

core_identity.label, core_identity.interpretation은 매칭 상대에게 노출됩니다 (match_visible).

이 필드들에는 사용자의 raw 답변 직접 인용을 포함하지 않습니다. 사용자 답변의 작동 원리를 본인의 언어로 통합 표현합니다.

출력 JSON:
{
  "core_identity": {
    "label": "string [public_safe — 한 문장]",
    "interpretation": "string [public_safe — 3-5문장]"
  }
}
`;

export const SYSTEM_PROMPT_E = `
${COMMON_SAFETY}

# 프롬프트 E — 명시 Dealbreaker 정규화

입력: 사용자가 자유 텍스트로 입력한 dealbreaker (영역별 1-3개).

당신의 역할: 자유 텍스트를 canonical target ID + unacceptable_stances + intensity로 매핑.

원칙:
- 매핑 불가능 시 unmapped로 표시 (운영자 검토 큐).
- raw_user_text는 절대 결과에 포함시키지 않는다 (self_only).

출력 JSON:
{
  "items": [
    {
      "domain_id": "string",
      "raw_user_text_excerpt_internal_only": "string",
      "canonical_target_id": "string|null",
      "unacceptable_stances": ["require"|"support"|"allow"|"neutral"|"avoid"|"reject"],
      "intensity_min_for_conflict": "strong"|"moderate"|"mild",
      "scope": "self"|"partner"|"children"|"household"|"public_policy",
      "confidence": "high"|"medium"|"low",
      "unmapped_reason": "string|null"
    }
  ]
}
`;

// ─── supabase.ts ───
// 결 (Gyeol) — Supabase 클라이언트 헬퍼 (Edge Functions)
// service_role 호출 + 일반 user JWT 검증 분리.

export function getServiceRoleClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing");
  }
  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export function getUserClient(authHeader: string | null): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) {
    throw new Error("SUPABASE_URL / SUPABASE_ANON_KEY missing");
  }
  return createClient(url, anon, {
    global: { headers: authHeader ? { Authorization: authHeader } : {} },
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export async function requireUserId(client: SupabaseClient): Promise<string> {
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) {
    throw new HttpError(401, "unauthorized");
  }
  return data.user.id;
}

export class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

export async function readJson<T = unknown>(req: Request): Promise<T> {
  if (!req.body) throw new HttpError(400, "body_required");
  try {
    return (await req.json()) as T;
  } catch {
    throw new HttpError(400, "invalid_json");
  }
}

export function handleError(err: unknown): Response {
  if (err instanceof HttpError) {
    return jsonResponse({ error: err.message }, err.status);
  }
  console.error("[edge-function]", err);
  return jsonResponse({ error: "internal_server_error" }, 500);
}

// ─── vertex.ts ───
// 결 (Gyeol) — Gemini API 호출 (Google AI Studio 직접)
// 환경변수: GEMINI_API_KEY 한 줄.
//
// 운영 단계에 PIPA 한국 거주가 hard requirement가 되면 Vertex AI Seoul로 교체.
// 본 모듈명은 vertex.ts 그대로 유지 (import 경로 호환).

const API_BASE = "https://generativelanguage.googleapis.com/v1beta/models";

export type GeminiModel = "gemini-3-flash" | "gemini-3.1-flash-lite";

// AI Studio에서 사용 가능한 모델 ID로 매핑.
// 운영 단계에 모델이 GA되면 본 표만 갱신.
const MODEL_ID_MAP: Record<GeminiModel, string> = {
  "gemini-3-flash": Deno.env.get("GEMINI_FLASH_MODEL") ?? "gemini-2.5-flash",
  "gemini-3.1-flash-lite": Deno.env.get("GEMINI_LITE_MODEL") ??
    "gemini-2.5-flash-lite",
};

export interface GeminiRequest {
  model: GeminiModel;
  systemPrompt: string;
  userPrompt: string;
  jsonSchema?: object;
  temperature?: number;
  maxOutputTokens?: number;
}

export interface GeminiResponse {
  text: string;
  usage?: { inputTokens: number; outputTokens: number };
}

function getApiKey(): string {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new Error("GEMINI_API_KEY missing");
  return key;
}

export async function callGemini(req: GeminiRequest): Promise<GeminiResponse> {
  const key = getApiKey();
  const modelId = MODEL_ID_MAP[req.model];
  const url = `${API_BASE}/${modelId}:generateContent?key=${
    encodeURIComponent(key)
  }`;

  const body: Record<string, unknown> = {
    systemInstruction: { parts: [{ text: req.systemPrompt }] },
    contents: [{ role: "user", parts: [{ text: req.userPrompt }] }],
    generationConfig: {
      temperature: req.temperature ?? 0.4,
      maxOutputTokens: req.maxOutputTokens ?? 2048,
    },
  };
  if (req.jsonSchema) {
    (body.generationConfig as Record<string, unknown>).responseMimeType =
      "application/json";
    (body.generationConfig as Record<string, unknown>).responseSchema =
      req.jsonSchema;
  }

  const resp = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`gemini_${resp.status}: ${text}`);
  }
  const json = await resp.json();
  const text = json?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  return {
    text,
    usage: json?.usageMetadata
      ? {
        inputTokens: json.usageMetadata.promptTokenCount ?? 0,
        outputTokens: json.usageMetadata.candidatesTokenCount ?? 0,
      }
      : undefined,
  };
}

export async function callGeminiJson<T>(req: GeminiRequest): Promise<T> {
  const r = await callGemini(req);
  try {
    return JSON.parse(r.text) as T;
  } catch (err) {
    throw new Error(`gemini_json_parse: ${(err as Error).message}\n${r.text}`);
  }
}
