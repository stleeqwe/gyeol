// 결 (Gyeol) — explanation_payload + boundary_check_payload 산출
// 매칭알고리즘 v7 §4.4 + §4.5

import type {
  AlignmentByDomain,
  BoundaryCheckPayload,
  DomainId,
  ExplanationPayload,
  ExplanationPayloadDomain,
  InferredDealbreaker,
  NormalizedDomainPayload,
  NormalizedProfile,
  PairReasonAtoms,
  PrincipleMix,
  Stance,
} from "./types.ts";
import { DOMAIN_IDS, DOMAIN_LABELS_KO } from "./types.ts";
import {
  isSharedRejection,
  isSharedSacred,
  isTensionTarget,
  STANCE_DISTANCE,
} from "./stance-distance.ts";

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
