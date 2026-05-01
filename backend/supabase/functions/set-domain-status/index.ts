// 결 (Gyeol) — Edge Function: set-domain-status
// Handles skip/private choices and creates self-review-safe analysis placeholders.

import {
  getServiceRoleClient,
  getUserClient,
  handleError,
  HttpError,
  jsonResponse,
  readJson,
  requireUserId,
} from "../_shared/supabase.ts";
import { encodeMvpCiphertext } from "../_shared/crypto-scaffold.ts";
import type { DomainId } from "../_shared/types.ts";

type DomainAction = "skip" | "private";
type SkipReason =
  | "do_not_want_public"
  | "not_settled"
  | "not_important"
  | "other";

interface RequestBody {
  interview_id: string;
  domain_id: DomainId;
  action: DomainAction;
  skip_reason?: SkipReason | null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const body = await readJson<RequestBody>(req);
    if (body.action === "skip" && !body.skip_reason) {
      throw new HttpError(400, "skip_reason_required");
    }

    const service = getServiceRoleClient();
    const { data: interview } = await service
      .from("interviews")
      .select("id, domain")
      .eq("id", body.interview_id)
      .eq("user_id", userId)
      .single();
    if (!interview || interview.domain !== body.domain_id) {
      throw new HttpError(404, "interview_not_found");
    }

    const now = new Date().toISOString();
    if (body.action === "skip") {
      await service.from("interviews").update({
        status: "skipped",
        skip_reason_value: body.skip_reason,
        is_private_kept: false,
        finalized_at: now,
      }).eq("id", body.interview_id).eq("user_id", userId);
      await upsertPlaceholderAnalysis(
        service,
        userId,
        body.interview_id,
        body.domain_id,
        {
          where: "이 영역은 답변하지 않았습니다.",
          why: `선택한 사유: ${body.skip_reason}`,
          how: "매칭 상대에게 건너뜀 상태와 사유만 표시됩니다.",
          isFromSkip: true,
          isFromPrivateKept: false,
        },
      );
    } else {
      await service.from("interviews").update({
        status: "private_kept",
        skip_reason_value: null,
        is_private_kept: true,
        finalized_at: now,
      }).eq("id", body.interview_id).eq("user_id", userId);
      await upsertPlaceholderAnalysis(
        service,
        userId,
        body.interview_id,
        body.domain_id,
        {
          where: "이 영역은 비공개로 보관되었습니다.",
          why:
            "자기 분석에는 남기되 매칭 상대에게 분석 내용은 공개하지 않습니다.",
          how: "매칭 상대에게는 비공개 보관 상태만 표시됩니다.",
          isFromSkip: false,
          isFromPrivateKept: true,
        },
      );
    }

    return jsonResponse({
      status: body.action === "skip" ? "skipped" : "private_kept",
    });
  } catch (err) {
    return handleError(err);
  }
});

async function upsertPlaceholderAnalysis(
  service: ReturnType<typeof getServiceRoleClient>,
  userId: string,
  interviewId: string,
  domainId: DomainId,
  summary: {
    where: string;
    why: string;
    how: string;
    isFromSkip: boolean;
    isFromPrivateKept: boolean;
  },
): Promise<void> {
  await service.from("analyses").upsert({
    user_id: userId,
    interview_id: interviewId,
    domain: domainId,
    profile_version: "v7",
    assessment_version: "v7.1.0",
    summary_where: summary.where,
    summary_why: summary.why,
    summary_how: summary.how,
    summary_tension_type: null,
    summary_tension_text: null,
    structured_ciphertext: encodeMvpCiphertext(JSON.stringify({
      skipped: summary.isFromSkip,
      private_kept: summary.isFromPrivateKept,
    })),
    depth_level: 1,
    is_from_skip: summary.isFromSkip,
    is_from_private_kept: summary.isFromPrivateKept,
  }, { onConflict: "user_id,domain" });
}
