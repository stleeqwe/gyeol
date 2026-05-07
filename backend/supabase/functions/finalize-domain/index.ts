// 결 (Gyeol) — Edge Function: finalize-domain
// 영역 인터뷰 종료 → llm-prompt-b 호출 → analyses + answer_evidence 저장.

import {
  getServiceRoleClient,
  getUserClient,
  handleError,
  HttpError,
  jsonResponse,
  readJson,
  requireUserId,
} from "../_shared/supabase.ts";
import { loggerFor } from "../_shared/logger.ts";
import type { DomainId } from "../_shared/types.ts";

interface RequestBody {
  interview_id: string;
  domain_id: DomainId;
}

Deno.serve(async (req) => {
  const log = loggerFor("finalize-domain");
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const body = await readJson<RequestBody>(req);
    const reqLog = log.with({ user_id: userId, domain_id: body.domain_id });
    reqLog.info("finalize.start", { interview_id: body.interview_id });

    const service = getServiceRoleClient();

    // 인터뷰 상태 → analyzing. Only in-progress rows for this domain can move.
    const { data: interview, error: statusErr } = await service.from(
      "interviews",
    )
      .update({ status: "analyzing" })
      .eq("id", body.interview_id)
      .eq("user_id", userId)
      .eq("domain", body.domain_id)
      .eq("status", "in_progress")
      .select("id")
      .maybeSingle();
    if (statusErr || !interview) {
      throw new HttpError(409, "interview_not_in_progress");
    }
    reqLog.info("status.analyzing");

    // llm-prompt-b 호출 — 사용자 JWT를 그대로 forward
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const auth = req.headers.get("authorization") ?? "";
    const llmStart = performance.now();
    const resp = await fetch(`${supabaseUrl}/functions/v1/llm-prompt-b`, {
      method: "POST",
      headers: { "authorization": auth, "content-type": "application/json" },
      body: JSON.stringify({
        interview_id: body.interview_id,
        domain_id: body.domain_id,
      }),
    });
    if (!resp.ok) {
      reqLog.error("llm_prompt_b.failed", {
        http_status: resp.status,
        latency_ms: Math.round(performance.now() - llmStart),
        retained_status: "analyzing",
      });
      const text = await resp.text();
      throw new HttpError(resp.status, `analysis_failed: ${text}`);
    }
    const analysisResult = await resp.json();

    // finalized
    await service.from("interviews")
      .update({ status: "finalized", finalized_at: new Date().toISOString() })
      .eq("id", body.interview_id)
      .eq("user_id", userId)
      .eq("domain", body.domain_id)
      .eq("status", "analyzing");
    reqLog.info("finalize.ok", {
      analysis_id: analysisResult.analysis_id,
      total_latency_ms: Math.round(performance.now() - llmStart),
    });

    return jsonResponse({
      status: "finalized",
      analysis_id: analysisResult.analysis_id,
      summary: analysisResult.summary,
    });
  } catch (err) {
    return handleError(err);
  }
});
