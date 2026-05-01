> Authoritative agent guide. All documentation MUST be in English (see "Documentation Language Policy" below).

# CLAUDE.md

This file is referenced by Claude Code (or other coding agents) when working in this directory. The same content exists in `AGENTS.md` — other agents (Codex/Cursor, etc.) refer to that file. Keep both files in sync when making changes.

## Project Identity

**Gyeol** — A *value-alignment matching* iOS app for users considering marriage or a long-term committed relationship.

Core decisions (see Architecture ADR-001 ~ ADR-015):

1. **iOS only** — Apple Sign In only, one account per person
2. **Deterministic + LLM separation** — matching itself is deterministic; only narrative post-editing uses LLM
3. **On-device speech** — Apple Speech Framework, 0 external transmission
4. **Raw quote isolation triple defense** — LLM self-validation + normalization n-gram + matrix engine detect
5. **PIPA Article 23** — separate consent, Korea data residency (currently Google AI Studio; replace with Vertex AI Seoul if hard requirement arises)
6. **User-facing facade Edge Functions** (ADR-015) — iOS sends plaintext only; ciphertext conversion and service_role triggers handled at the Edge

## Documentation Language Policy

**All documentation files in this repository MUST be written in English.**

- Korean source specs (`결_*_v*.md`) are preserved as immutable history. Their English translations live in `결_*_v*_en.md`.
- All other `.md` files (README, CLAUDE.md, AGENTS.md, RUNBOOK, ordiq specs, dependency map) — English only.
- Korean backup of previously-Korean docs is preserved as `*.ko.md` for reference, but `*.md` (without `.ko`) is the authoritative version.
- When you create new `.md` files, write them in English.
- When you update existing `.md` files, keep them in English. Do not introduce Korean prose.
- Inline Korean is allowed only for: (a) UI strings shown to users, (b) raw quote examples for clarity, (c) original Korean spec filenames as immutable identifiers.
- This policy applies to AI agents (Claude Code, Codex, Cursor) and human contributors equally.

## Directory Guide

| Location | Responsibility |
|----------|----------------|
| `결_*_v*.md` | Original Korean spec. Do not modify (history preserved) |
| `docs/specs/01-prd.md` | PRD — Vision / target / 6 domains / matching mechanic / Scope IN/OUT |
| `docs/specs/02-architecture.md` | C4 + 15 ADRs + Fitness Function |
| `docs/specs/03-design-system.md` | Color/Type/Space/Motion + 13 screen mapping |
| `docs/backend-dependency-map.md` | 6 Data Flow Contracts + Cross-Domain Chains + RLS trust boundary + Observability |
| `docs/RUNBOOK.md` | Operations runbook — secrets, deploy, matching trigger, incident response |
| `backend/supabase/config.toml` | supabase CLI deploy + verify_jwt mapping |
| `backend/supabase/migrations/0001..0006.sql` | DDL+RLS+seed+security hardening |
| `backend/supabase/functions/_shared/` | Deterministic library + logger + crypto-scaffold |
| `backend/supabase/functions/<name>/` | One directory per Edge Function (19 total) |
| `ios/Gyeol/Models/` | Codable structs — consistent with Edge `_shared/types.ts` |
| `ios/Gyeol/Services/` | Supabase / Auth / Speech / InterviewService / MatchService / ChatService / DraftStore + **Logging.swift** (OSLog 7 categories) |
| `ios/Gyeol/ViewModels/` | InterviewViewModel and others |
| `ios/Gyeol/Views/` | 13 screens (+ 4 required flow screens) |
| `ios/Gyeol/Components/` | Tokens + Primary/Secondary Button + Mic + Recording + Waveform + ProgressBar + Modal + ChoiceChip + MatchCard + ChatBubble |
| `.claude/ordiq/` | Pipeline state + quality reports (gitignored) |

## Edge Functions — 19 (= 13 core + 6 facade)

| Core (specified in system design v3) | User-facing facade (ADR-015) |
|--------------------------------------|------------------------------|
| llm-prompt-a/b/c-postedit/d/e | bootstrap-user — Apple JWT → public.users |
| matching-algorithm | submit-answer — text_plain → encodeMvpCiphertext → bytea |
| explanation-payload-builder | set-domain-status — skip/private unified |
| recommendation-matrix-engine | submit-dealbreakers — raw_texts → bytea |
| post-polish-validation | prepare-review — core_identity + dealbreaker normalization guaranteed |
| raw-quote-detector | request-explanation — lazy queue trigger |
| normalization-worker | (all 6 above have verify_jwt=true, user call entry point) |
| publish, finalize-domain | |

## Consistency Checklist When Changing

| Change | Also update |
|--------|-------------|
| Add new domain | DomainID enum (iOS) + DOMAIN_IDS (Edge `_shared/types.ts`) + canonical seed (0005) + OpenQuestion.all (iOS Models) + review RLS |
| Add new LLM prompt | `_shared/prompts.ts` PROMPT_VERSION + new Edge Function directory + `config.toml` verify_jwt + update this table |
| Add matches column | new migration + review matches RLS + iOS Match struct + ExplanationPayload/RecommendationNarrative update |
| Add polish validation item | `_shared/post-polish-validation.ts` 8 checks → 9 checks + add unit test in `test_scoring.ts` |
| New Reactive Sync flow | add Contract in `docs/backend-dependency-map.md` (ensure sync_status: COMPLETE) |
| New boundary log | verify logger policy PII (never expose raw text, only ID/enum/version/count) |
| New Edge Function | declare verify_jwt in `supabase/config.toml` + update dependency map table + RUNBOOK operations |

## Deterministic Core Functions (No LLM Dependency)

- `_shared/stance-distance.ts` — STANCE_DISTANCE 6×6 + isTensionTarget / isSharedSacred / isSharedRejection
- `_shared/raw-quote.ts` — detectRawQuoteInSummary (n-gram 8 chars + quote pattern)
- `_shared/scoring.ts` — computeCompatibilityBasic (step 1, 5-10ms/pair)
- `_shared/explanation.ts` — buildExplanationPayload + buildBoundaryCheckPayload (step 3)
- `_shared/matrix-engine.ts` — assembleDraftNarrative + evaluateDraftQuality (step 4)
- `_shared/post-polish-validation.ts` — validatePolishOutput (8 checks, draft fallback)
- `_shared/cache-key.ts` — computePolishCacheKey (viewer-isolated)
- `_shared/crypto-scaffold.ts` — encodeMvpCiphertext / decodeMvpCiphertext (bytea round trip)

When modifying these functions, always update unit tests in `_shared/test_scoring.ts`. **Currently 29 tests / 100% PASS.**

## Logging Policy (PII Compliance)

| Never log | Allowed |
|-----------|---------|
| raw answers / summary_* / raw_user_text / polished narrative / evidence quote / LLM input/output text | user_id/match_id (8-char short), enum (stance/qualitative/alignment_level), version, latency_ms, duration_ms, *_chars, *_count |

- Edge: `_shared/logger.ts` `loggerFor(fn).info/warn/error/trace`. Single-line JSON console → Supabase Logs.
- iOS: `GyLog.{auth,interview,speech,match,chat,realtime,api}.info/warn/error`. OSLog → Console.app.
- Policy check: `grep -E "(text_plain|raw_answer|summary_where|interpretation|quote)"` added log lines = 0 automated check.

## Common Tasks

```bash
# Run deterministic tests (no Vertex AI key needed)
deno test --allow-net=none backend/supabase/functions/_shared/test_scoring.ts
# Type-check Edge Functions
deno check backend/supabase/functions/**/*.ts
# Deploy single / all functions
cd backend && supabase functions deploy <name>
cd backend && supabase functions deploy
# Manage secrets
cd backend && supabase secrets list
cd backend && supabase secrets set GEMINI_API_KEY="..." INTERNAL_CALL_TOKEN="$(openssl rand -hex 32)"
# Apply migrations (via MCP or CLI)
cd backend && supabase db push
# iOS build (requires Xcode)
xcodebuild -scheme Gyeol -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Never Do

- Direct raw quote citation in `summary` field ✗ (paraphrase only — public_safe constraint)
- Expose `structured` data as `match_visible` ✗ (internal_only)
- Expose `answer_evidence` to match partner ✗ (self_review_only)
- Call external STT API ✗ (Apple Speech on-device only)
- Store bidirectional same hash in `polished_output_cache` ✗ (viewer isolation required)
- Cache results when `polish_validation` fails ✗ (failures must not be reused)
- Include LLM call results in unit tests ✗ (deterministic only for unit tests)
- Add free-form text outside skip reason enum ✗
- **Expose any raw text in logs ✗** (PII compliance. ID/enum/count/duration only)
- Direct INSERT from iOS to `interview_answers`/`explicit_dealbreakers`/`analyses` ✗ (use facade Edge Functions — `submit-answer` / `submit-dealbreakers`, etc.)

## Production Phase TODO Items

Code marked with `[1차 스캐폴드]` or `[운영 단계 보강 필요]`:

- `_shared/crypto-scaffold.ts` — replace with KMS envelope encryption (currently \\x hex plaintext)
- `_shared/vertex.ts` — switch to Vertex AI Seoul if PIPA hard requirement (currently Google AI Studio)
- `normalization-worker` mapToNormalizedDomain.axis_positions — explicit principle ↔ axis mapping dictionary
- `post-polish-validation` new principle name checks — too conservative; supplement with production data
- `matching-algorithm` failsUserHard — assumes payload structure match; strengthen consistency
- `request-explanation` — currently lazy queue; production phase pg_cron batch
