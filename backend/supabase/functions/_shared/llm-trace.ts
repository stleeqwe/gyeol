// 결 (Gyeol) — LLM call trace persistence (ADR-017)
//
// Activated only when Edge runtime has LLM_TRACE_MODE=full.
// Writes raw LLM I/O + Gemini 3 thought summary to public.llm_call_traces.
// service_role only access.
//
// PROHIBITED in production. See:
//   docs/specs/02-architecture.md ADR-017
//   docs/RUNBOOK.md §1.3, §5.4
//   CLAUDE.md "Logging Policy"

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import type { GeminiUsage } from "./vertex.ts";

export interface TraceContext {
  userId: string;
  functionName: string;
  promptVersion: string;
  modelId: string;
  thinkingLevel?: string;
  domain?: string;
  interviewId?: string;
  parentAnswerId?: string;
  matchId?: string;
}

export interface TraceRecord {
  userPrompt: string;
  responseText: string;
  thinkingSummary?: string;
  usage?: GeminiUsage;
  latencyMs: number;
  statusCode?: number;
  errorMessage?: string;
}

export function isTraceEnabled(): boolean {
  return Deno.env.get("LLM_TRACE_MODE") === "full";
}

/**
 * Persists one LLM call to public.llm_call_traces.
 * No-op when LLM_TRACE_MODE is not "full".
 * Trace write failures are swallowed and logged via console.warn — they
 * must never break the calling Edge Function flow.
 */
export async function writeLlmTrace(
  service: SupabaseClient,
  ctx: TraceContext,
  rec: TraceRecord,
): Promise<void> {
  if (!isTraceEnabled()) return;
  try {
    await service.from("llm_call_traces").insert({
      user_id: ctx.userId,
      function_name: ctx.functionName,
      prompt_version: ctx.promptVersion,
      model_id: ctx.modelId,
      thinking_level: ctx.thinkingLevel ?? null,
      domain: ctx.domain ?? null,
      interview_id: ctx.interviewId ?? null,
      parent_answer_id: ctx.parentAnswerId ?? null,
      match_id: ctx.matchId ?? null,
      user_prompt: rec.userPrompt,
      response_text: rec.responseText,
      thinking_summary: rec.thinkingSummary ?? null,
      input_tokens: rec.usage?.inputTokens ?? null,
      output_tokens: rec.usage?.outputTokens ?? null,
      thinking_tokens: rec.usage?.thinkingTokens ?? null,
      latency_ms: rec.latencyMs,
      status_code: rec.statusCode ?? 200,
      error_message: rec.errorMessage ?? null,
      trace_mode: "full",
    });
  } catch (err) {
    console.warn(JSON.stringify({
      level: "warn",
      msg: "llm_trace.write_failed",
      fn: ctx.functionName,
      user_id: ctx.userId.slice(0, 8),
      error_class: (err as Error)?.constructor?.name ?? "Error",
    }));
  }
}
