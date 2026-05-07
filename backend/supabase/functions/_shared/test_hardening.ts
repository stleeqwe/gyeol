// Backend hardening behavior tests.
// deno test --allow-net=none backend/supabase/functions/_shared/test_hardening.ts

import {
  assert,
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.220.1/assert/mod.ts";
import type { DomainId, NormalizedProfile, Stance } from "./types.ts";
import {
  finishedDomains,
  isFinishedInterviewStatus,
  missingFinishedDomains,
} from "./flow-state.ts";
import {
  buildDealbreakerNormalizationInputs,
  mapNormalizedDealbreakerItems,
} from "./dealbreaker-normalization.ts";
import { buildDirectionalMatchRows } from "./matching-hardening.ts";

Deno.test("flow state — analyzing is not treated as finished", () => {
  assert(isFinishedInterviewStatus("finalized"));
  assert(isFinishedInterviewStatus("skipped"));
  assert(isFinishedInterviewStatus("private_kept"));
  assert(!isFinishedInterviewStatus("in_progress"));
  assert(!isFinishedInterviewStatus("analyzing"));
});

Deno.test("flow state — all six domains must be completed", () => {
  const rows = [
    { domain: "belief", status: "finalized" },
    { domain: "society", status: "skipped" },
    { domain: "bioethics", status: "private_kept" },
    { domain: "family", status: "analyzing" },
    { domain: "work_life", status: "finalized" },
  ] as const;

  assertEquals(
    finishedDomains(rows),
    new Set(["belief", "society", "bioethics", "work_life"]),
  );
  assertEquals(missingFinishedDomains(rows), ["family", "intimacy"]);
});

Deno.test("dealbreaker normalization — maps reordered LLM items by input_id", () => {
  const rows = [
    {
      id: "row-a",
      domain: "belief" as DomainId,
      seq: 1,
      raw_user_text_ciphertext: "\\x61",
    },
    {
      id: "row-b",
      domain: "belief" as DomainId,
      seq: 2,
      raw_user_text_ciphertext: "\\x62",
    },
  ];
  const inputs = buildDealbreakerNormalizationInputs(rows);
  const mapped = mapNormalizedDealbreakerItems(inputs, [
    {
      input_id: "db_002",
      canonical_target_id: "family.children",
      unacceptable_stances: ["reject" as Stance],
      intensity_min_for_conflict: "moderate",
      scope: "partner",
    },
    {
      input_id: "db_001",
      canonical_target_id: "religion.devotion",
      unacceptable_stances: ["require" as Stance],
      intensity_min_for_conflict: "strong",
      scope: "household",
    },
  ]);

  assertEquals(mapped.map((m) => m.row.id), ["row-b", "row-a"]);
  assertEquals(mapped[0].item.canonical_target_id, "family.children");
  assertEquals(mapped[1].item.scope, "household");
});

Deno.test("dealbreaker normalization — rejects missing, duplicate, or unknown input_id", async () => {
  const inputs = buildDealbreakerNormalizationInputs([
    {
      id: "row-a",
      domain: "belief" as DomainId,
      seq: 1,
      raw_user_text_ciphertext: "\\x61",
    },
    {
      id: "row-b",
      domain: "belief" as DomainId,
      seq: 2,
      raw_user_text_ciphertext: "\\x62",
    },
  ]);

  await assertRejects(
    async () =>
      mapNormalizedDealbreakerItems(inputs, [
        {
          input_id: "db_001",
          canonical_target_id: "religion.devotion",
          unacceptable_stances: ["require" as Stance],
          intensity_min_for_conflict: "strong",
          scope: "partner",
        },
      ]),
    Error,
    "dealbreaker_normalization_count_mismatch",
  );

  await assertRejects(
    async () =>
      mapNormalizedDealbreakerItems(inputs, [
        {
          input_id: "db_001",
          canonical_target_id: "religion.devotion",
          unacceptable_stances: ["require" as Stance],
          intensity_min_for_conflict: "strong",
          scope: "partner",
        },
        {
          input_id: "db_001",
          canonical_target_id: "religion.devotion",
          unacceptable_stances: ["reject" as Stance],
          intensity_min_for_conflict: "moderate",
          scope: "partner",
        },
      ]),
    Error,
    "dealbreaker_normalization_duplicate_input_id",
  );

  await assertRejects(
    async () =>
      mapNormalizedDealbreakerItems(inputs, [
        {
          input_id: "db_001",
          canonical_target_id: "religion.devotion",
          unacceptable_stances: ["require" as Stance],
          intensity_min_for_conflict: "strong",
          scope: "partner",
        },
        {
          input_id: "db_999",
          canonical_target_id: "religion.devotion",
          unacceptable_stances: ["reject" as Stance],
          intensity_min_for_conflict: "moderate",
          scope: "partner",
        },
      ]),
    Error,
    "dealbreaker_normalization_unknown_input_id",
  );
});

Deno.test("matching hardening — candidate hard filter only removes candidate direction", () => {
  const viewer = profile("viewer", "religion.devotion", "reject");
  const candidate = profile("candidate", "religion.devotion", "support");

  const result = buildDirectionalMatchRows({
    viewer,
    candidate,
    viewerDealbreakers: [],
    candidateDealbreakers: [{
      canonical_target_id: "religion.devotion",
      unacceptable_stances: ["reject"],
      scope: "partner",
    }],
  });

  assertEquals(result.rows.length, 1);
  assertEquals(result.rows[0].viewer_id, "viewer");
  assertEquals(result.rows[0].candidate_id, "candidate");
  assertEquals(result.skipped_by_viewer_hard, 0);
  assertEquals(result.skipped_by_candidate_hard, 1);
});

function profile(
  userId: string,
  sacredTarget: string,
  stance: Stance,
): NormalizedProfile {
  return {
    user_id: userId,
    profile_version: "v7",
    payload: {
      belief: {
        canonical_principles: [{ principle: "belief.balance", weight: "high" }],
        axis_positions: [{ axis: "belief.axis", value: 0 }],
        sacred_targets: [{
          target: sacredTarget,
          stance,
          intensity: "strong",
          scope: "partner",
          evidence_ids: [],
        }],
        disgust_targets: [],
        dealbreaker_targets: [],
        domain_salience: "important",
      },
    },
  };
}
