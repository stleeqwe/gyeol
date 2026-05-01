// 결 (Gyeol) — stance distance matrix
// 매칭알고리즘 v7 §4.4.5

import type { Intensity, Stance } from "./types.ts";

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
