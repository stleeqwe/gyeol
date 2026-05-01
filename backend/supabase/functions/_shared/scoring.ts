// 결 (Gyeol) — 호환 점수 계산 결정론
// 매칭알고리즘 v5 §4 (호환 점수) + v7 §4.3 (basic 산출)

import type {
  AlignmentByDomain,
  AlignmentLevel,
  CompatibilityAssessmentBasic,
  DomainId,
  NormalizedDomainPayload,
  NormalizedProfile,
  QualitativeLabel,
  QueueReason,
  SacredValue,
  Stance,
} from "./types.ts";
import { DOMAIN_IDS } from "./types.ts";
import { isSharedSacred, STANCE_DISTANCE } from "./stance-distance.ts";

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
