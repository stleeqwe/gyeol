// 결 (Gyeol) — Edge Function: matching-algorithm (1단계 — 전체 페어 basic)
// 매칭알고리즘 v7 §1.2 + §4.3
// 호출 트리거: 사용자 발행(publish) 직후 + 일일 배치.

import {
  getServiceRoleClient,
  handleError,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/supabase.ts";
import { computeCompatibilityBasic } from "../_shared/scoring.ts";
import { loggerFor } from "../_shared/logger.ts";
import type { NormalizedProfile } from "../_shared/types.ts";

interface RequestBody {
  user_id: string; // 새로 발행한 사용자 — 전체 풀과 페어링
  batch_size?: number;
}

Deno.serve(async (req) => {
  const log = loggerFor("matching-algorithm");
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    if (
      req.headers.get("x-internal-call") !== Deno.env.get("INTERNAL_CALL_TOKEN")
    ) {
      log.warn("unauthorized.internal_call_token_mismatch");
      throw new HttpError(401, "internal_only");
    }
    const body = await readJson<RequestBody>(req);
    const reqLog = log.with({ user_id: body.user_id });
    reqLog.info("batch.start", { batch_size: body.batch_size ?? 5000 });

    const service = getServiceRoleClient();

    // 새 사용자 normalized_profile
    const { data: viewer } = await service
      .from("normalized_profiles")
      .select("user_id, profile_version, payload, raw_quote_detected")
      .eq("user_id", body.user_id)
      .single();
    if (!viewer || viewer.raw_quote_detected) {
      reqLog.warn("viewer_profile_not_ready", {
        raw_quote_detected: viewer?.raw_quote_detected ?? null,
      });
      throw new HttpError(400, "viewer_profile_not_ready");
    }

    // 매칭 풀 진입 자격 후보들 — 1차 단순화: 모든 active user
    const { data: candidates } = await service
      .from("normalized_profiles")
      .select("user_id, profile_version, payload, raw_quote_detected")
      .neq("user_id", body.user_id)
      .eq("raw_quote_detected", false)
      .limit(body.batch_size ?? 5000);

    // 사용자의 명시 dealbreaker (User Hard 필터에 사용)
    const { data: deal } = await service
      .from("explicit_dealbreakers")
      .select("canonical_target_id, unacceptable_stances, scope")
      .eq("user_id", body.user_id);

    reqLog.info("candidates.loaded", {
      candidate_count: candidates?.length ?? 0,
      explicit_dealbreaker_count: deal?.length ?? 0,
    });

    let inserted = 0;
    let skipped = 0;
    const startCompute = performance.now();

    for (const c of candidates ?? []) {
      // User Hard 필터: candidate가 viewer의 명시 dealbreaker stance면 매칭 풀 제외
      if (failsUserHard(viewer.payload, c.payload, deal ?? [])) {
        skipped++;
        continue;
      }
      const hasUnresolvedDealbreaker = hasInferredDealbreakerConflict(
        viewer.payload,
        c.payload,
      );

      const basic = computeCompatibilityBasic(
        viewer as NormalizedProfile,
        c as NormalizedProfile,
        { hasUnresolvedDealbreaker },
      );

      // viewer→candidate insert
      await service.from("matches").upsert({
        viewer_id: body.user_id,
        candidate_id: c.user_id,
        final_score: basic.final_score,
        qualitative_label: basic.qualitative_label,
        queue_reason: basic.queue_reason,
        comparable_domain_count: basic.comparable_domain_count,
        comparable_domain_weight_sum: basic.comparable_domain_weight_sum,
        compatibility_assessment_basic: basic,
        shared_sacred_targets: basic.shared_sacred_targets,
        assessment_version: basic.assessment_version,
        recommendation_status: "pending",
      }, { onConflict: "viewer_id,candidate_id" });

      // 양방향: candidate→viewer도 insert (canidate가 viewer를 본 시점 대비)
      await service.from("matches").upsert({
        viewer_id: c.user_id,
        candidate_id: body.user_id,
        final_score: basic.final_score,
        qualitative_label: basic.qualitative_label,
        queue_reason: basic.queue_reason,
        comparable_domain_count: basic.comparable_domain_count,
        comparable_domain_weight_sum: basic.comparable_domain_weight_sum,
        compatibility_assessment_basic: basic,
        shared_sacred_targets: basic.shared_sacred_targets,
        assessment_version: basic.assessment_version,
        recommendation_status: "pending",
      }, { onConflict: "viewer_id,candidate_id" });

      inserted++;
    }

    const duration_ms = Math.round(performance.now() - startCompute);
    reqLog.info("batch.ok", {
      inserted,
      skipped,
      total_candidates: candidates?.length ?? 0,
      duration_ms,
      avg_per_pair_ms: inserted > 0 ? Math.round(duration_ms / inserted) : 0,
    });

    return jsonResponse({
      inserted,
      skipped,
      total_candidates: candidates?.length ?? 0,
    });
  } catch (err) {
    return handleError(err);
  }
});

function failsUserHard(
  _viewerPayload: unknown,
  candidatePayload: Record<string, unknown>,
  dealbreakers: {
    canonical_target_id: string | null;
    unacceptable_stances: string[] | null;
    scope: string;
  }[],
): boolean {
  const cdAll = Object.values(
    candidatePayload as Record<
      string,
      { sacred_targets?: { target: string; stance: string }[] }
    >,
  );
  for (const cd of cdAll) {
    if (!cd.sacred_targets) continue;
    for (const t of cd.sacred_targets) {
      for (const db of dealbreakers) {
        if (!db.canonical_target_id || !db.unacceptable_stances) continue;
        if (
          t.target === db.canonical_target_id &&
          db.unacceptable_stances.includes(t.stance)
        ) {
          return true;
        }
      }
    }
  }
  return false;
}

function hasInferredDealbreakerConflict(
  viewerPayload: Record<string, unknown>,
  candidatePayload: Record<string, unknown>,
): boolean {
  const v = viewerPayload as Record<
    string,
    {
      dealbreaker_targets?: {
        target: string;
        unacceptable_stances: string[];
      }[];
    }
  >;
  const c = candidatePayload as Record<
    string,
    { sacred_targets?: { target: string; stance: string }[] }
  >;
  for (const domainId of Object.keys(v)) {
    const idbList = v[domainId]?.dealbreaker_targets ?? [];
    const cTargets = c[domainId]?.sacred_targets ?? [];
    for (const idb of idbList) {
      const ct = cTargets.find((x) => x.target === idb.target);
      if (ct && idb.unacceptable_stances.includes(ct.stance)) return true;
    }
  }
  return false;
}
