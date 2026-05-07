// 결 (Gyeol) — Edge Function: matching-algorithm (1단계 — 전체 페어 basic)
// 호출 트리거: 사용자 발행(publish) 직후 + 일일 배치.

import {
  getServiceRoleClient,
  handleError,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/supabase.ts";
import { loggerFor } from "../_shared/logger.ts";
import type { NormalizedProfile } from "../_shared/types.ts";
import { missingFinishedDomains } from "../_shared/flow-state.ts";
import {
  buildDirectionalMatchRows,
  type ExplicitDealbreaker,
} from "../_shared/matching-hardening.ts";

interface RequestBody {
  user_id: string;
  batch_size?: number;
}

type DealbreakerRow = ExplicitDealbreaker & { user_id: string };

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
    const batchSize = Math.min(Math.max(body.batch_size ?? 500, 1), 500);
    const reqLog = log.with({ user_id: body.user_id });
    reqLog.info("batch.start", { batch_size: batchSize });

    const service = getServiceRoleClient();

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

    const { data: eligibleUsers } = await service
      .from("users")
      .select("id")
      .neq("id", body.user_id)
      .is("deleted_at", null)
      .not("profile_published_at", "is", null)
      .limit(batchSize);
    const candidateIds = (eligibleUsers ?? []).map((user) => user.id);
    if (candidateIds.length === 0) {
      return jsonResponse({
        inserted: 0,
        skipped_by_viewer_hard: 0,
        skipped_by_candidate_hard: 0,
        candidate_count: 0,
      });
    }

    const { data: candidates } = await service
      .from("normalized_profiles")
      .select("user_id, profile_version, payload, raw_quote_detected")
      .in("user_id", candidateIds)
      .eq("raw_quote_detected", false);

    const candidatesById = new Map(
      (candidates ?? []).map((profile) => [profile.user_id, profile]),
    );
    const normalizedCandidateIds = candidateIds.filter((id) =>
      candidatesById.has(id)
    );
    const allRelevantUserIds = [body.user_id, ...normalizedCandidateIds];

    const { data: coreRows } = await service
      .from("core_identities")
      .select("user_id")
      .in("user_id", allRelevantUserIds);
    const coreUserIds = new Set((coreRows ?? []).map((row) => row.user_id));

    const { data: interviews } = await service
      .from("interviews")
      .select("user_id, domain, status")
      .in("user_id", allRelevantUserIds);
    const interviewsByUser = groupByUser(interviews ?? []);

    if (
      !coreUserIds.has(body.user_id) ||
      missingFinishedDomains(interviewsByUser.get(body.user_id) ?? []).length >
        0
    ) {
      reqLog.warn("viewer_not_publishable");
      throw new HttpError(400, "viewer_not_publishable");
    }

    const eligibleProfiles = normalizedCandidateIds
      .filter((id) =>
        coreUserIds.has(id) &&
        missingFinishedDomains(interviewsByUser.get(id) ?? []).length === 0
      )
      .map((id) => candidatesById.get(id)!)
      .filter(Boolean);

    const { data: dealbreakerRows } = await service
      .from("explicit_dealbreakers")
      .select("user_id, canonical_target_id, unacceptable_stances, scope")
      .in("user_id", [body.user_id, ...eligibleProfiles.map((p) => p.user_id)]);
    const dealbreakersByUser = groupDealbreakers(dealbreakerRows ?? []);

    const startCompute = performance.now();
    const upsertRows = [];
    let skippedByViewerHard = 0;
    let skippedByCandidateHard = 0;

    for (const candidate of eligibleProfiles) {
      const result = buildDirectionalMatchRows({
        viewer: toProfile(viewer),
        candidate: toProfile(candidate),
        viewerDealbreakers: dealbreakersByUser.get(body.user_id) ?? [],
        candidateDealbreakers: dealbreakersByUser.get(candidate.user_id) ?? [],
      });
      skippedByViewerHard += result.skipped_by_viewer_hard;
      skippedByCandidateHard += result.skipped_by_candidate_hard;
      upsertRows.push(...result.rows);
    }

    if (upsertRows.length > 0) {
      const { error } = await service.from("matches").upsert(upsertRows, {
        onConflict: "viewer_id,candidate_id",
      });
      if (error) {
        reqLog.error("matches.upsert_failed", { error: error.message });
        throw new HttpError(500, "matches_upsert_failed");
      }
    }

    const durationMs = Math.round(performance.now() - startCompute);
    reqLog.info("batch.ok", {
      inserted: upsertRows.length,
      skipped_by_viewer_hard: skippedByViewerHard,
      skipped_by_candidate_hard: skippedByCandidateHard,
      candidate_count: eligibleProfiles.length,
      duration_ms: durationMs,
    });

    return jsonResponse({
      inserted: upsertRows.length,
      skipped_by_viewer_hard: skippedByViewerHard,
      skipped_by_candidate_hard: skippedByCandidateHard,
      candidate_count: eligibleProfiles.length,
    });
  } catch (err) {
    return handleError(err);
  }
});

function toProfile(row: {
  user_id: string;
  profile_version: string;
  payload: unknown;
}): NormalizedProfile {
  return {
    user_id: row.user_id,
    profile_version: row.profile_version,
    payload: row.payload as NormalizedProfile["payload"],
  };
}

function groupByUser<T extends { user_id: string }>(
  rows: T[],
): Map<string, T[]> {
  const map = new Map<string, T[]>();
  for (const row of rows) {
    const group = map.get(row.user_id) ?? [];
    group.push(row);
    map.set(row.user_id, group);
  }
  return map;
}

function groupDealbreakers(
  rows: DealbreakerRow[],
): Map<string, ExplicitDealbreaker[]> {
  const map = new Map<string, ExplicitDealbreaker[]>();
  for (const row of rows) {
    const group = map.get(row.user_id) ?? [];
    group.push({
      canonical_target_id: row.canonical_target_id,
      unacceptable_stances: row.unacceptable_stances,
      scope: row.scope,
    });
    map.set(row.user_id, group);
  }
  return map;
}
