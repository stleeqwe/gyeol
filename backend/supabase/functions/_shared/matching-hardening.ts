import { computeCompatibilityBasic } from "./scoring.ts";
import type {
  CompatibilityAssessmentBasic,
  NormalizedProfile,
} from "./types.ts";

export interface ExplicitDealbreaker {
  canonical_target_id: string | null;
  unacceptable_stances: string[] | null;
  scope: string;
}

export interface MatchUpsertRow {
  viewer_id: string;
  candidate_id: string;
  final_score: number;
  qualitative_label: CompatibilityAssessmentBasic["qualitative_label"];
  queue_reason: CompatibilityAssessmentBasic["queue_reason"];
  comparable_domain_count: number;
  comparable_domain_weight_sum: number;
  compatibility_assessment_basic: CompatibilityAssessmentBasic;
  shared_sacred_targets: string[];
  assessment_version: string;
  recommendation_status: "pending";
}

export interface DirectionalMatchResult {
  rows: MatchUpsertRow[];
  skipped_by_viewer_hard: number;
  skipped_by_candidate_hard: number;
}

export function buildDirectionalMatchRows(input: {
  viewer: NormalizedProfile;
  candidate: NormalizedProfile;
  viewerDealbreakers: ExplicitDealbreaker[];
  candidateDealbreakers: ExplicitDealbreaker[];
}): DirectionalMatchResult {
  const rows: MatchUpsertRow[] = [];
  let skippedByViewerHard = 0;
  let skippedByCandidateHard = 0;

  if (
    failsUserHard(input.candidate.payload, input.viewerDealbreakers)
  ) {
    skippedByViewerHard++;
  } else {
    rows.push(buildMatchRow(input.viewer, input.candidate));
  }

  if (
    failsUserHard(input.viewer.payload, input.candidateDealbreakers)
  ) {
    skippedByCandidateHard++;
  } else {
    rows.push(buildMatchRow(input.candidate, input.viewer));
  }

  return {
    rows,
    skipped_by_viewer_hard: skippedByViewerHard,
    skipped_by_candidate_hard: skippedByCandidateHard,
  };
}

export function buildMatchRow(
  viewer: NormalizedProfile,
  candidate: NormalizedProfile,
): MatchUpsertRow {
  const basic = computeCompatibilityBasic(viewer, candidate, {
    hasUnresolvedDealbreaker: hasInferredDealbreakerConflict(
      viewer.payload,
      candidate.payload,
    ),
  });

  return {
    viewer_id: viewer.user_id,
    candidate_id: candidate.user_id,
    final_score: basic.final_score,
    qualitative_label: basic.qualitative_label,
    queue_reason: basic.queue_reason,
    comparable_domain_count: basic.comparable_domain_count,
    comparable_domain_weight_sum: basic.comparable_domain_weight_sum,
    compatibility_assessment_basic: basic,
    shared_sacred_targets: basic.shared_sacred_targets,
    assessment_version: basic.assessment_version,
    recommendation_status: "pending",
  };
}

export function failsUserHard(
  candidatePayload: NormalizedProfile["payload"],
  dealbreakers: ExplicitDealbreaker[],
): boolean {
  const domains = Object.values(candidatePayload);
  for (const domain of domains) {
    for (const target of domain?.sacred_targets ?? []) {
      for (const dealbreaker of dealbreakers) {
        if (
          dealbreaker.canonical_target_id &&
          dealbreaker.unacceptable_stances?.includes(target.stance) &&
          target.target === dealbreaker.canonical_target_id
        ) {
          return true;
        }
      }
    }
  }
  return false;
}

export function hasInferredDealbreakerConflict(
  viewerPayload: NormalizedProfile["payload"],
  candidatePayload: NormalizedProfile["payload"],
): boolean {
  for (const domainId of Object.keys(viewerPayload)) {
    const domain = domainId as keyof typeof viewerPayload;
    const inferred = viewerPayload[domain]?.dealbreaker_targets ?? [];
    const candidateTargets = candidatePayload[domain]?.sacred_targets ?? [];
    for (const dealbreaker of inferred) {
      const target = candidateTargets.find((item) =>
        item.target === dealbreaker.target
      );
      if (
        target &&
        dealbreaker.unacceptable_stances.includes(target.stance)
      ) {
        return true;
      }
    }
  }
  return false;
}
