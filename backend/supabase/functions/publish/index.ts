// 결 (Gyeol) — Edge Function: publish
// 사용자 발행 → 자기 분석 finalize + 매칭 풀 진입.
// 시스템설계 v3 §2.2

import {
  getServiceRoleClient,
  getUserClient,
  handleError,
  HttpError,
  jsonResponse,
  requireUserId,
} from "../_shared/supabase.ts";
import { loggerFor } from "../_shared/logger.ts";
import { missingFinishedDomains } from "../_shared/flow-state.ts";

Deno.serve(async (req) => {
  const log = loggerFor("publish");
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const reqLog = log.with({ user_id: userId });
    reqLog.info("publish.start");
    const service = getServiceRoleClient();

    // 6영역 인터뷰 상태 확인 — 모든 영역이 finalized/skipped/private_kept인지
    const { data: interviews } = await service
      .from("interviews")
      .select("domain, status")
      .eq("user_id", userId);
    const missing = missingFinishedDomains(interviews ?? []);
    if (missing.length > 0) {
      reqLog.warn("not_all_domains_finished", {
        missing_domains: missing,
        total_required: 6,
      });
      throw new HttpError(400, "not_all_domains_finished");
    }

    // 핵심 유형 + 명시 dealbreaker 정규화 미완료 시 차단
    const { data: core } = await service.from("core_identities").select(
      "user_id",
    ).eq("user_id", userId).maybeSingle();
    if (!core) {
      reqLog.warn("core_identity_missing");
      throw new HttpError(400, "core_identity_missing");
    }

    const { data: pendingDealbreakers } = await service
      .from("explicit_dealbreakers")
      .select("id")
      .eq("user_id", userId)
      .is("canonical_target_id", null)
      .limit(1);
    if ((pendingDealbreakers?.length ?? 0) > 0) {
      reqLog.warn("dealbreakers_not_normalized");
      throw new HttpError(400, "dealbreakers_not_normalized");
    }

    await service.from("users")
      .update({ profile_published_at: new Date().toISOString() })
      .eq("id", userId)
      .is("deleted_at", null);

    // 매칭 알고리즘 1단계 트리거 (비동기)
    const internalToken = Deno.env.get("INTERNAL_CALL_TOKEN") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    reqLog.info("matching_algorithm.trigger");
    fetch(`${supabaseUrl}/functions/v1/matching-algorithm`, {
      method: "POST",
      headers: {
        "x-internal-call": internalToken,
        "content-type": "application/json",
      },
      body: JSON.stringify({ user_id: userId }),
    }).catch((e) =>
      reqLog.error("matching_algorithm.trigger_failed", {
        error_message: (e as Error).message,
      })
    );

    reqLog.info("publish.ok", { finished_domains: 6 });
    return jsonResponse({ status: "publishing", user_id: userId });
  } catch (err) {
    return handleError(err);
  }
});
