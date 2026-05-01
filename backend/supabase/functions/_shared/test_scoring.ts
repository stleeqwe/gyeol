// 결 (Gyeol) — 결정론 함수 단위 테스트
// deno test --allow-net=none backend/supabase/functions/_shared/test_scoring.ts

import {
  assert,
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.220.1/assert/mod.ts";
import {
  isSharedRejection,
  isSharedSacred,
  isTensionTarget,
  STANCE_DISTANCE,
} from "./stance-distance.ts";
import { detectRawQuoteInSummary } from "./raw-quote.ts";
import { computeCompatibilityBasic } from "./scoring.ts";
import {
  buildBoundaryCheckPayload,
  buildExplanationPayload,
} from "./explanation.ts";
import {
  assembleDraftNarrative,
  evaluateDraftQuality,
} from "./matrix-engine.ts";
import {
  buildValidationContext,
  validatePolishOutput,
} from "./post-polish-validation.ts";
import { computeDraftHash, computePolishCacheKey } from "./cache-key.ts";
import { decodeMvpCiphertext, encodeMvpCiphertext } from "./crypto-scaffold.ts";
import type {
  AlignmentByDomain,
  CompatibilityAssessmentBasic,
  DomainId,
  NormalizedProfile,
  Stance,
} from "./types.ts";

// ─────────────────────────────────────────────────────────────
// MVP crypto scaffold
// ─────────────────────────────────────────────────────────────

Deno.test("crypto scaffold — bytea hex round trip preserves Korean text", () => {
  const plain = "신념과 가족에 대해 길게 답했습니다.";
  const encoded = encodeMvpCiphertext(plain);
  assert(encoded.startsWith("\\x"));
  assertEquals(decodeMvpCiphertext(encoded), plain);
});

Deno.test("crypto scaffold — legacy plain strings remain readable", () => {
  assertEquals(decodeMvpCiphertext("plain text"), "plain text");
});

// ─────────────────────────────────────────────────────────────
// stance distance
// ─────────────────────────────────────────────────────────────

Deno.test("stance distance — require↔reject = 5", () => {
  assertEquals(STANCE_DISTANCE.require.reject, 5);
  assertEquals(STANCE_DISTANCE.reject.require, 5);
});

Deno.test("stance distance — require↔support = 1 (약한 차이)", () => {
  assertEquals(STANCE_DISTANCE.require.support, 1);
});

Deno.test("isTension — require/reject + strong → true", () => {
  assert(isTensionTarget("require", "reject", "strong", "strong"));
});

Deno.test("isTension — require/support 약한 차이는 false", () => {
  assert(!isTensionTarget("require", "support", "strong", "strong"));
});

Deno.test("isTension — distance >=3이지만 mild면 false", () => {
  assert(!isTensionTarget("require", "neutral", "mild", "mild"));
});

Deno.test("shared sacred — 양측 require + strong → true", () => {
  assert(isSharedSacred("require", "support", "strong", "moderate"));
});

Deno.test("shared rejection — 양측 reject + strong → true (v7 §4.4.4)", () => {
  assert(isSharedRejection("reject", "avoid", "strong", "moderate"));
});

// ─────────────────────────────────────────────────────────────
// raw quote detector
// ─────────────────────────────────────────────────────────────

Deno.test("raw quote — 따옴표 패턴 감지", () => {
  const r = detectRawQuoteInSummary(
    `사용자는 "본인의 몸이고 본인의 인생"이라고 말했다.`,
    `본인의 몸이고 본인의 인생`,
  );
  assert(r.detected);
  assertEquals(r.reason, "quote_pattern");
});

Deno.test("raw quote — 8자 n-gram overlap 감지", () => {
  const r = detectRawQuoteInSummary(
    `정말 미친듯이 답답한 상황이었습니다`,
    `정말 미친듯이 답답한`,
  );
  assert(r.detected);
});

Deno.test("raw quote — paraphrase는 통과", () => {
  const r = detectRawQuoteInSummary(
    `신체적 자기결정권을 우선하는 결을 가진다.`,
    `본인의 몸이고 본인의 인생`,
  );
  assert(!r.detected);
});

// ─────────────────────────────────────────────────────────────
// scoring — basic
// ─────────────────────────────────────────────────────────────

function profile(
  userId: string,
  beliefPrinciples: { principle: string; weight: "high" | "medium" | "low" }[],
): NormalizedProfile {
  return {
    user_id: userId,
    profile_version: "v7",
    payload: {
      belief: {
        canonical_principles: beliefPrinciples,
        axis_positions: [{ axis: "belief.transcendent", value: 0 }],
        sacred_targets: [],
        disgust_targets: [],
        dealbreaker_targets: [],
        domain_salience: "important",
      },
      society: {
        canonical_principles: [{
          principle: "society.balanced",
          weight: "high",
        }],
        axis_positions: [{ axis: "society.responsibility", value: 0 }],
        sacred_targets: [],
        disgust_targets: [],
        dealbreaker_targets: [],
        domain_salience: "important",
      },
    },
  };
}

Deno.test("computeCompatibilityBasic — 완전 동일 → high score", () => {
  const a = profile("a", [{
    principle: "belief.secular_morality",
    weight: "high",
  }]);
  const b = profile("b", [{
    principle: "belief.secular_morality",
    weight: "high",
  }]);
  const r = computeCompatibilityBasic(a, b);
  assert(r.final_score > 0.5);
  assertEquals(r.qualitative_label, "alignment");
});

Deno.test("computeCompatibilityBasic — dealbreaker 충돌 → boundary", () => {
  const a = profile("a", [{
    principle: "belief.secular_morality",
    weight: "high",
  }]);
  const b = profile("b", [{
    principle: "belief.secular_morality",
    weight: "high",
  }]);
  const r = computeCompatibilityBasic(a, b, { hasUnresolvedDealbreaker: true });
  assertEquals(r.qualitative_label, "boundary");
  assertEquals(r.queue_reason, "boundary_check");
});

// ─────────────────────────────────────────────────────────────
// matrix-engine — evaluateDraftQuality
// ─────────────────────────────────────────────────────────────

Deno.test("evaluateDraftQuality — 너무 짧으면 needs_polish=true", () => {
  const r = evaluateDraftQuality({
    headline: "결",
    alignment_narrative: "닿음.",
    tension_narrative: "",
  });
  assert(r.needsPolish);
  assert(r.reasons.includes("too_short"));
});

Deno.test("evaluateDraftQuality — 충분 길이는 false", () => {
  const r = evaluateDraftQuality({
    headline: "사회 합의 기반 도덕을 공유하는 사람",
    alignment_narrative:
      "두 분 모두 사회 합의 기반 도덕 원칙을 공유합니다. 신념 체계 영역에서 결이 강하게 닿습니다.",
    tension_narrative: "가족과 권위 영역에서 결의 차이가 있습니다.",
  });
  assert(!r.needsPolish);
});

// ─────────────────────────────────────────────────────────────
// post-polish validation
// ─────────────────────────────────────────────────────────────

Deno.test("validatePolishOutput — raw quote 도입 차단", () => {
  const draft = {
    headline: "결을 공유하는 사람",
    alignment_narrative: "신념 영역에서 닿습니다.",
    tension_narrative: "가족 영역에서 다릅니다.",
  };
  const polished = {
    headline: "결을 공유하는 사람",
    alignment_narrative:
      '사용자가 "본인의 몸이고 본인의 인생"이라고 했듯이 닿습니다.',
    tension_narrative: "가족 영역에서 다릅니다.",
  };
  const ctx = buildValidationContext(draft, "본인의 몸이고 본인의 인생", false);
  const r = validatePolishOutput(draft, polished, ctx);
  assert(!r.valid);
  assertEquals(r.reason, "raw_quote_introduced");
});

Deno.test("validatePolishOutput — 평가어 도입 차단", () => {
  const draft = {
    headline: "결을 공유하는 사람",
    alignment_narrative: "신념 영역에서 닿습니다.",
    tension_narrative: "가족 영역에서 다릅니다.",
  };
  const polished = {
    headline: "완벽한 사람",
    alignment_narrative: "신념 영역에서 닿습니다.",
    tension_narrative: "가족 영역에서 다릅니다.",
  };
  const ctx = buildValidationContext(draft, "", false);
  const r = validatePolishOutput(draft, polished, ctx);
  assert(!r.valid);
  assertEquals(r.reason, "evaluative_word_introduced");
});

Deno.test("validatePolishOutput — 길이 +25% → range out", () => {
  const draft = {
    headline: "결을 공유하는 사람",
    alignment_narrative: "신념 영역에서 닿습니다.",
    tension_narrative: "가족 영역에서 다릅니다.",
  };
  const polished = {
    headline:
      "결을 공유하는 사람으로서 두 분은 매우 닮은 부분이 많습니다 그 점이 좋습니다",
    alignment_narrative:
      "신념 영역에서 닿습니다 그 점이 분명합니다 강하게 드러납니다 입니다",
    tension_narrative: "가족 영역에서 다릅니다 차이가 있습니다 입니다",
  };
  const ctx = buildValidationContext(draft, "", false);
  const r = validatePolishOutput(draft, polished, ctx);
  assert(!r.valid);
  assert(
    r.reason === "length_out_of_range" ||
      r.reason === "evaluative_word_introduced",
  );
});

Deno.test("validatePolishOutput — 적합한 polish는 통과", () => {
  const draft = {
    headline: "사회 합의 기반 도덕을 공유하는 사람",
    alignment_narrative:
      "신념 영역에서 결이 닿는 부분이 있습니다. 사회 합의 기반 도덕 원칙을 공유합니다.",
    tension_narrative: "가족 영역에서 결의 차이가 있습니다.",
  };
  const polished = {
    headline: "사회 합의 기반 도덕을 공유하는 사람",
    alignment_narrative:
      "신념 영역에서 두 분의 결이 닿습니다. 사회 합의 기반 도덕 원칙이 같습니다.",
    tension_narrative: "가족 영역에서 결이 다릅니다.",
  };
  const ctx = buildValidationContext(draft, "", false);
  const r = validatePolishOutput(draft, polished, ctx);
  assert(
    r.valid,
    `Expected valid, got reason=${r.reason} details=${r.details}`,
  );
});

// ─────────────────────────────────────────────────────────────
// explanation — buildExplanationPayload + buildBoundaryCheckPayload
// 매칭알고리즘 v7 §4.4 + §4.5
// ─────────────────────────────────────────────────────────────

function profileFull(
  userId: string,
  beliefSecularWeight: "high" | "medium",
): NormalizedProfile {
  return {
    user_id: userId,
    profile_version: "v7",
    payload: {
      belief: {
        canonical_principles: [
          { principle: "belief.secular_morality", weight: beliefSecularWeight },
        ],
        axis_positions: [{ axis: "belief.transcendent", value: -2 }],
        sacred_targets: [
          {
            target: "bioethics.abortion.choice",
            stance: "support",
            intensity: "moderate",
            scope: "partner",
            evidence_ids: [],
          },
        ],
        disgust_targets: [
          {
            target: "belief.religion.proselytizing",
            intensity: "moderate",
            evidence_ids: [],
          },
        ],
        dealbreaker_targets: [],
        domain_salience: "core",
      },
    },
  };
}

Deno.test("buildExplanationPayload — shared principles 추출", () => {
  const a = profileFull("a", "high");
  const b = profileFull("b", "high");
  const ad: AlignmentByDomain[] = [{
    domain_id: "belief",
    alignment_level: "strong",
    alignment_score: 0.9,
    tension_score: 0,
    alignment_summary: "결이 강하게 닿습니다",
  }];
  const labels = { "belief.secular_morality": "사회 합의 기반 도덕" };
  const payload = buildExplanationPayload(a, b, ad, labels);
  assertEquals(payload.viewer_id, "a");
  assertEquals(payload.candidate_id, "b");
  assertEquals(payload.alignment_by_domain.length, 1);
  const beliefAtoms = payload.alignment_by_domain[0].pair_reason_atoms;
  assertEquals(beliefAtoms.shared_principles.length, 1);
  assertEquals(
    beliefAtoms.shared_principles[0].principle_id,
    "belief.secular_morality",
  );
  assert(
    payload.alignment_by_domain[0].public_alignment_sentence.includes(
      "사회 합의 기반 도덕",
    ),
  );
});

Deno.test("buildExplanationPayload — shared rejection (disgust_targets) 추출", () => {
  const a = profileFull("a", "high");
  const b = profileFull("b", "high");
  const ad: AlignmentByDomain[] = [{
    domain_id: "belief",
    alignment_level: "strong",
    alignment_score: 0.9,
    tension_score: 0,
    alignment_summary: "",
  }];
  const payload = buildExplanationPayload(a, b, ad, {});
  const atoms = payload.alignment_by_domain[0].pair_reason_atoms;
  assertEquals(atoms.shared_rejection_targets, [
    "belief.religion.proselytizing",
  ]);
});

Deno.test("buildBoundaryCheckPayload — explicit_dealbreaker 우선 매칭", () => {
  const viewer = profileFull("v", "high");
  const candidate: NormalizedProfile = {
    user_id: "c",
    profile_version: "v7",
    payload: {
      belief: {
        canonical_principles: [],
        axis_positions: [],
        sacred_targets: [
          {
            target: "belief.religion.strong_devotion",
            stance: "require",
            intensity: "strong",
            scope: "partner",
            evidence_ids: [],
          },
        ],
        disgust_targets: [],
        dealbreaker_targets: [],
        domain_salience: "core",
      },
    },
  };
  const eds = [{
    domain: "belief" as DomainId,
    canonical_target_id: "belief.religion.strong_devotion",
    raw_user_text: "강한 종교 신앙이 삶의 중심인 사람",
    unacceptable_stances: ["require", "support"] as Stance[],
  }];
  const targetLabels = {
    "belief.religion.strong_devotion": "강한 종교적 신앙",
  };
  const bcp = buildBoundaryCheckPayload(viewer, candidate, eds, targetLabels);
  assert(bcp !== null);
  assertEquals(bcp!.source, "explicit_dealbreaker");
  assertEquals(bcp!.confidence, "high");
  assertEquals(bcp!.viewer_boundary, "강한 종교 신앙이 삶의 중심인 사람");
});

Deno.test("buildBoundaryCheckPayload — 충돌 없으면 null", () => {
  const viewer = profileFull("v", "high");
  const candidate = profileFull("c", "high"); // 같은 결, 충돌 없음
  const bcp = buildBoundaryCheckPayload(viewer, candidate, [], {});
  assertEquals(bcp, null);
});

// ─────────────────────────────────────────────────────────────
// matrix-engine — assembleDraftNarrative
// 매칭알고리즘 v7 §8.2
// ─────────────────────────────────────────────────────────────

Deno.test("assembleDraftNarrative — alignment 페어 헤드라인 + narrative", () => {
  const basic: CompatibilityAssessmentBasic = {
    assessment_version: "v7.1.0",
    final_score: 0.75,
    qualitative_label: "alignment",
    queue_reason: "top_match",
    comparable_domain_count: 1,
    comparable_domain_weight_sum: 1.5,
    alignment_by_domain: [{
      domain_id: "belief",
      alignment_level: "strong",
      alignment_score: 0.9,
      tension_score: 0,
      alignment_summary: "결이 강하게 닿습니다",
    }],
    shared_sacred_targets: [],
  };
  const a = profileFull("a", "high");
  const b = profileFull("b", "high");
  const labels = { "belief.secular_morality": "사회 합의 기반 도덕" };
  const payload = buildExplanationPayload(
    a,
    b,
    basic.alignment_by_domain,
    labels,
  );
  const draft = assembleDraftNarrative(basic, payload, {
    viewerCoreLabel: "viewer",
    candidateCoreLabel: "candidate",
    candidateCoreInterpretation: "",
    candidateSummariesByDomain: {},
  });
  assert(draft.headline.includes("사회 합의 기반 도덕"));
  assert(draft.alignment_narrative.length > 0);
});

Deno.test("assembleDraftNarrative — boundary 페어는 경계 헤드라인", () => {
  const basic: CompatibilityAssessmentBasic = {
    assessment_version: "v7.1.0",
    final_score: 0.3,
    qualitative_label: "boundary",
    queue_reason: "boundary_check",
    comparable_domain_count: 1,
    comparable_domain_weight_sum: 1.5,
    alignment_by_domain: [{
      domain_id: "belief",
      alignment_level: "tension",
      alignment_score: 0.3,
      tension_score: 0.8,
      alignment_summary: "",
    }],
    shared_sacred_targets: [],
  };
  const payload = {
    viewer_id: "a",
    candidate_id: "b",
    alignment_by_domain: [],
    boundary_check_payload: null,
  };
  const draft = assembleDraftNarrative(basic, payload, {
    viewerCoreLabel: "v",
    candidateCoreLabel: "c",
    candidateCoreInterpretation: "",
    candidateSummariesByDomain: {},
  });
  assert(draft.headline.includes("경계"));
});

// ─────────────────────────────────────────────────────────────
// cache-key — 방향성 분리
// 매칭알고리즘 v7 §8.4
// ─────────────────────────────────────────────────────────────

Deno.test("computeDraftHash — 같은 입력 → 같은 hash", async () => {
  const draft1 = {
    headline: "A",
    alignment_narrative: "B",
    tension_narrative: "C",
  };
  const draft2 = {
    headline: "A",
    alignment_narrative: "B",
    tension_narrative: "C",
  };
  const h1 = await computeDraftHash(draft1);
  const h2 = await computeDraftHash(draft2);
  assertEquals(h1, h2);
  assertEquals(h1.length, 64); // SHA-256 hex
});

Deno.test("computePolishCacheKey — A→B와 B→A 분리 (v7 §8.4 정합)", async () => {
  const draftHash = "deadbeef";
  const base = {
    viewerProfileVersion: "v7",
    candidateProfileVersion: "v7",
    assessmentVersion: "v7.1.0",
    templateLibraryVersion: "v3.1.0",
    polishPromptVersion: "C.v7.0",
    draftHash,
  };
  const aToB = await computePolishCacheKey({
    viewerId: "A",
    candidateId: "B",
    ...base,
  });
  const bToA = await computePolishCacheKey({
    viewerId: "B",
    candidateId: "A",
    ...base,
  });
  assertNotEquals(aToB, bToA); // A→B와 B→A는 별도 캐시
});

Deno.test("computePolishCacheKey — 버전 변경 시 다른 hash", async () => {
  const base = {
    viewerId: "A",
    candidateId: "B",
    viewerProfileVersion: "v7",
    candidateProfileVersion: "v7",
    assessmentVersion: "v7.1.0",
    templateLibraryVersion: "v3.1.0",
    polishPromptVersion: "C.v7.0",
    draftHash: "h1",
  };
  const k1 = await computePolishCacheKey(base);
  const k2 = await computePolishCacheKey({
    ...base,
    polishPromptVersion: "C.v7.1",
  });
  assertNotEquals(k1, k2); // 프롬프트 버전 변경 → 캐시 무효화
});
