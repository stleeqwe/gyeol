// 결 (Gyeol) — Edge Function: explanation-payload-builder (3단계 — 최종 큐 후보)
// 매칭알고리즘 v7 §1.2 + §4.4 + §4.5

import {
  getServiceRoleClient,
  handleError,
  HttpError,
  jsonResponse,
  readJson,
} from "../_shared/supabase.ts";
import {
  buildBoundaryCheckPayload,
  buildExplanationPayload,
} from "../_shared/explanation.ts";
import { loggerFor } from "../_shared/logger.ts";
import type {
  CompatibilityAssessmentBasic,
  NormalizedProfile,
  Stance,
} from "../_shared/types.ts";

interface RequestBody {
  match_id: string;
}

Deno.serve(async (req) => {
  const log = loggerFor("explanation-payload-builder");
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
    const reqLog = log.with({ match_id: body.match_id });
    reqLog.info("explanation.start");
    const service = getServiceRoleClient();

    const { data: m, error } = await service
      .from("matches")
      .select(
        "id, viewer_id, candidate_id, qualitative_label, compatibility_assessment_basic",
      )
      .eq("id", body.match_id)
      .single();
    if (error || !m) {
      reqLog.warn("match_not_found", { error: error?.message });
      throw new HttpError(404, "match_not_found");
    }

    const [{ data: viewer }, { data: candidate }] = await Promise.all([
      service.from("normalized_profiles").select(
        "user_id, profile_version, payload",
      ).eq("user_id", m.viewer_id).single(),
      service.from("normalized_profiles").select(
        "user_id, profile_version, payload",
      ).eq("user_id", m.candidate_id).single(),
    ]);
    if (!viewer || !candidate) {
      reqLog.warn("profile_missing", {
        viewer: !!viewer,
        candidate: !!candidate,
      });
      throw new HttpError(400, "profile_missing");
    }

    // principle 라벨 사전
    const { data: principles } = await service.from("canonical_principles")
      .select("id, label_korean");
    const principleLabels = Object.fromEntries(
      (principles ?? []).map((p) => [p.id, p.label_korean]),
    );

    // target 라벨 사전
    const { data: targets } = await service.from("canonical_targets").select(
      "id, label_korean",
    );
    const targetLabels = Object.fromEntries(
      (targets ?? []).map((t) => [t.id, t.label_korean]),
    );

    const basic = m
      .compatibility_assessment_basic as CompatibilityAssessmentBasic;

    const payload = buildExplanationPayload(
      viewer as NormalizedProfile,
      candidate as NormalizedProfile,
      basic.alignment_by_domain,
      principleLabels,
    );

    // boundary_check 페어인 경우 boundary_check_payload 산출
    if (m.qualitative_label === "boundary") {
      const { data: deal } = await service
        .from("explicit_dealbreakers")
        .select(
          "domain, canonical_target_id, raw_user_text_ciphertext, unacceptable_stances",
        )
        .eq("user_id", m.viewer_id);
      const dealRows = (deal ?? []).map((d) => ({
        domain: d.domain,
        canonical_target_id: d.canonical_target_id,
        raw_user_text: undefined,
        unacceptable_stances: (d.unacceptable_stances ?? []) as Stance[],
      }));
      const bcp = buildBoundaryCheckPayload(
        viewer as NormalizedProfile,
        candidate as NormalizedProfile,
        dealRows,
        targetLabels,
      );
      payload.boundary_check_payload = bcp;

      await service.from("matches").update({
        explanation_payload: payload,
        boundary_check_payload: bcp,
        explanation_built_at: new Date().toISOString(),
      }).eq("id", m.id);
      reqLog.info("explanation.ok", {
        qualitative_label: m.qualitative_label,
        boundary_check_built: bcp !== null,
        boundary_source: bcp?.source ?? null,
        domain_count: payload.alignment_by_domain.length,
      });
    } else {
      await service.from("matches").update({
        explanation_payload: payload,
        explanation_built_at: new Date().toISOString(),
      }).eq("id", m.id);
      reqLog.info("explanation.ok", {
        qualitative_label: m.qualitative_label,
        domain_count: payload.alignment_by_domain.length,
      });
    }

    return jsonResponse({ match_id: m.id, status: "explanation_built" });
  } catch (err) {
    return handleError(err);
  }
});
