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
