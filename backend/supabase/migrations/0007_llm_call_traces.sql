-- 0007_llm_call_traces.sql — Test/staging LLM conversation trace (ADR-017)
--
-- Stores raw LLM input/output + Gemini 3 thought summary for quality monitoring.
-- Activated when Edge runtime has LLM_TRACE_MODE=full.
-- service_role only — no user-facing RLS policies.
-- Production runtime MUST keep LLM_TRACE_MODE unset/none.
--
-- See:
--   docs/specs/02-architecture.md ADR-017
--   docs/RUNBOOK.md §1.3, §5.4
--   CLAUDE.md "Logging Policy"

CREATE TABLE IF NOT EXISTS public.llm_call_traces (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at         timestamptz NOT NULL DEFAULT now(),

  -- Caller context
  user_id            uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  function_name      text NOT NULL,
  prompt_version     text NOT NULL,
  model_id           text NOT NULL,
  thinking_level     text,

  -- Optional context (per function)
  domain             text,
  interview_id       uuid,
  parent_answer_id   uuid,
  match_id           uuid,

  -- Raw LLM I/O — present only because trace mode is on
  user_prompt        text NOT NULL,
  response_text      text NOT NULL,
  thinking_summary   text,

  -- Usage / latency / status
  input_tokens       int,
  output_tokens      int,
  thinking_tokens    int,
  latency_ms         int,
  status_code        int NOT NULL DEFAULT 200,
  error_message      text,

  trace_mode         text NOT NULL DEFAULT 'full'
);

CREATE INDEX IF NOT EXISTS idx_llm_traces_user_created
  ON public.llm_call_traces (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_llm_traces_function_created
  ON public.llm_call_traces (function_name, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_llm_traces_interview
  ON public.llm_call_traces (interview_id) WHERE interview_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_llm_traces_match
  ON public.llm_call_traces (match_id) WHERE match_id IS NOT NULL;

ALTER TABLE public.llm_call_traces ENABLE ROW LEVEL SECURITY;
-- No policies: service_role bypass only. Future admin role can be added without
-- migration churn (CREATE POLICY ... FOR SELECT TO admin USING (true);).

COMMENT ON TABLE public.llm_call_traces IS
  'Test/staging LLM call traces (ADR-017). Raw user prompts + LLM responses + thought summaries. service_role only. Never enable LLM_TRACE_MODE=full in production.';
