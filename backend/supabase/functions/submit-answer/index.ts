// 결 (Gyeol) — Edge Function: submit-answer
// User JWT input -> service-role insert that satisfies interview_answers contract.

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

interface RequestBody {
  interview_id: string;
  domain: DomainId;
  seq: number;
  is_open_question_answer: boolean;
  parent_answer_id?: string | null;
  follow_up_question_text?: string | null;
  text_plain: string;
  text_length: number;
  depth_level: number;
  voice_input_seconds?: number | null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  try {
    const userClient = getUserClient(req.headers.get("authorization"));
    const userId = await requireUserId(userClient);
    const body = await readJson<RequestBody>(req);
    const text = body.text_plain.trim();
    if (!text) throw new HttpError(400, "answer_empty");
    if (body.depth_level < 1 || body.depth_level > 3) {
      throw new HttpError(400, "invalid_depth");
    }

    const service = getServiceRoleClient();
    const { data: interview, error: interviewErr } = await service
      .from("interviews")
      .select("id, user_id, domain, status, voice_input_session_count")
      .eq("id", body.interview_id)
      .eq("user_id", userId)
      .single();
    if (interviewErr || !interview || interview.domain !== body.domain) {
      throw new HttpError(404, "interview_not_found");
    }
    if (interview.status !== "in_progress") {
      throw new HttpError(409, "interview_not_in_progress");
    }

    const existingQuery = service.from("interview_answers")
      .select(
        "id, interview_id, domain, seq, is_open_question_answer, parent_answer_id, follow_up_question_text, depth_level",
      )
      .eq("interview_id", body.interview_id)
      .eq("user_id", userId)
      .eq("domain", body.domain)
      .eq("seq", body.seq);
    const { data: existing } = await (
      body.parent_answer_id
        ? existingQuery.eq("parent_answer_id", body.parent_answer_id)
        : existingQuery.is("parent_answer_id", null)
    ).maybeSingle();
    if (existing) {
      return jsonResponse({ ...existing, text_plain: text });
    }

    const { data: saved, error } = await service.from("interview_answers")
      .insert({
        interview_id: body.interview_id,
        user_id: userId,
        domain: body.domain,
        seq: body.seq,
        is_open_question_answer: body.is_open_question_answer,
        parent_answer_id: body.parent_answer_id ?? null,
        follow_up_question_text: body.follow_up_question_text ?? null,
        text_ciphertext: encodeMvpCiphertext(text),
        text_length: body.text_length || text.length,
        depth_level: body.depth_level,
        voice_input_seconds: body.voice_input_seconds ?? null,
      })
      .select(
        "id, interview_id, domain, seq, is_open_question_answer, parent_answer_id, follow_up_question_text, depth_level",
      )
      .single();
    if (error || !saved) {
      if (error?.code === "23505") {
        const retryQuery = service.from("interview_answers")
          .select(
            "id, interview_id, domain, seq, is_open_question_answer, parent_answer_id, follow_up_question_text, depth_level",
          )
          .eq("interview_id", body.interview_id)
          .eq("user_id", userId)
          .eq("domain", body.domain)
          .eq("seq", body.seq);
        const { data: retryExisting } = await (
          body.parent_answer_id
            ? retryQuery.eq("parent_answer_id", body.parent_answer_id)
            : retryQuery.is("parent_answer_id", null)
        ).maybeSingle();
        if (retryExisting) {
          return jsonResponse({ ...retryExisting, text_plain: text });
        }
      }
      throw new HttpError(500, "answer_insert_failed");
    }

    if ((body.voice_input_seconds ?? 0) > 0) {
      await service.from("interviews")
        .update({
          voice_input_used: true,
          voice_input_session_count:
            (interview.voice_input_session_count ?? 0) + 1,
        })
        .eq("id", body.interview_id)
        .eq("user_id", userId);
    }

    return jsonResponse({
      ...saved,
      text_plain: text,
    });
  } catch (err) {
    return handleError(err);
  }
});
