> Translated from Korean (see .ko.md backup). Authoritative source: code + Korean spec docs.

# Gyeol — Operational RUNBOOK

> Operational procedures manual. Covers onboarding, incident response, and day-to-day tasks in a single document.
> Authoritative sources: `02-architecture.md` + `backend-dependency-map.md` + code.

---

## 1. Environment

| Item | Value |
|------|-------|
| Supabase project ref | `xkgffegenrvitalgncnt` |
| URL | `https://xkgffegenrvitalgncnt.supabase.co` |
| Region | `ap-northeast-2` (Seoul) |
| PostgreSQL | 17.6 |
| Migrations | Local reproducible 0001..0006 |
| Edge Functions | 19 ACTIVE (13 core + 6 facade) |
| LLM provider | Google AI Studio (key configured) — gemini-3-flash-preview / gemini-3.1-flash-lite-preview |

---

## 2. Secrets Management

### 2.1 Required secrets

```bash
cd backend
supabase secrets list
```

| Key | Status | Source |
|-----|--------|--------|
| `INTERNAL_CALL_TOKEN` | ✅ set | `openssl rand -hex 32` |
| `GEMINI_API_KEY` | ✅ set | https://aistudio.google.com/apikey |
| `GEMINI_FLASH_MODEL` | ✅ `gemini-3-flash-preview` | (optional override) |
| `GEMINI_LITE_MODEL` | ✅ `gemini-3.1-flash-lite-preview` | (optional override) |
| `SUPABASE_URL` | ✅ auto-injected by Edge runtime | (automatic) |
| `SUPABASE_SERVICE_ROLE_KEY` | ✅ auto-injected by Edge runtime | (automatic) |
| `SUPABASE_ANON_KEY` | ✅ auto-injected by Edge runtime | (automatic) |
| `LOG_LEVEL` | (optional, default `info`) | `debug` enables detailed tracing beyond trust boundary |

### 2.2 Key rotation (PIPA compliance)

```bash
# INTERNAL_CALL_TOKEN key rotation (affects all internal-only Edge Function calls)
NEW=$(openssl rand -hex 32)
cd backend && supabase secrets set INTERNAL_CALL_TOKEN="$NEW"
# → Edge Function restart is automatic (takes effect from next cold start, ~1-2 min)
# → All user-facing facade Edge Functions (publish/finalize-domain/...) pick up automatically
```

> Gemini API key is rotated separately in the Google AI Studio console → update via secrets set.

---

## 3. Deployment Procedures

### 3.1 Edge Function deployment

```bash
cd backend
# Single function
supabase functions deploy llm-prompt-b
# All functions (config.toml verify_jwt mapping applied automatically)
supabase functions deploy
```

Post-deploy verification:
```bash
# List functions and status
supabase functions list
# Or: Supabase Studio Dashboard → Edge Functions
```

### 3.2 Applying migrations

```bash
cd backend
supabase db push        # Apply local → remote (after dry-run)
supabase db diff        # Check diff between local and remote
```

### 3.3 iOS app

1. `cd ios && xcodegen generate`
2. Open `ios/Gyeol.xcodeproj` in Xcode
3. Select the `GyeolApp` scheme + iPhone Simulator → Run
4. For device distribution, set an Apple Developer Team and verify the Sign in with Apple capability

---

## 4. User Flow Trace (happy path)

```
1. Apple Sign In
   iOS AuthService.startAppleSignIn
   → ASAuthorizationController
   → GyeolClient.signInWithApple(idToken, nonce)
   → bootstrap-user Edge Function (auth.users → public.users)
   → AuthService.recordConsent (consents row, PIPA 5 items)
   ✓ logger: GyLog.auth.apple_sign_in.start/ok

2. 6-domain interview
   InterviewViewModel.bootstrap → InterviewService.getOrCreateInterview
   → InterviewIntroScreen (open question)
   → AnswerInputScreen (keyboard or voice)
     - voice: SpeechService.start (on-device, 1-min workaround)
   → submit-answer Edge Function (text_plain → encodeMvpCiphertext)
   → llm-prompt-a synchronous call (next follow-up question)
   ✓ logger: GyLog.interview.submit_answer.start/ok + Edge follow_up.start/ok

3. Domain close
   DomainEndScreen → InterviewService.finalizeDomain
   → finalize-domain Edge Function
   → llm-prompt-b synchronous call (analysis + raw_quote first-pass validation)
   → analyses + answer_evidence INSERT (encodeMvpCiphertext)
   → normalization-worker synchronous trigger (raw_quote second-pass + canonical mapping)
   ✓ logger: analysis.start/llm.ok/raw_quote_detected/analysis.ok

4. Pre-publish self-review
   SelfReviewScreen → prepare-review Edge Function
   → triggers llm-prompt-d if core_identity absent
   → triggers llm-prompt-e if dealbreaker not yet normalized
   → InterviewService.loadOwnAnalyses (RLS self)

5. Publish
   InterviewService.publish → publish Edge Function
   → validates 6 domains finalized + core_identity present
   → triggers matching-algorithm asynchronously (bidirectional matches.upsert × N)
   ✓ logger: publish.start/matching_algorithm.trigger/publish.ok + batch.ok (avg_per_pair_ms)

6. Match candidate display
   MatchListScreen → MatchService.loadInitial + subscribeRealtime
   → request-explanation Edge Function (lazy queue)
     - explanation-payload-builder (atoms + boundary_check_payload)
     - recommendation-matrix-engine (draft + needs_polish evaluation + cache or LLM-C + post-polish-validation)
   → matches.recommendation_status='ready' UPDATE
   → Realtime postgres_changes broadcast → MatchListScreen refresh
   ✓ logger: matrix.ok / polish.cache_hit·miss / polish.validation

7. mutual [Interested] → chat room
   MatchService.setInterest(matchId, true)
   → matches.viewer_interest='interested' UPDATE
   → trigger sync_pair_interest (search_path fixed, REVOKE EXECUTE)
   → if mutual: chat_rooms INSERT + system message INSERT ("결을 통해 연결되었습니다" / Connected through Gyeol)
   → ChatService Realtime auto-refresh
```

---

## 5. Monitoring

### 5.1 Live monitoring log query

```bash
# Supabase Studio Dashboard → Logs Explorer
# Or MCP: get_logs(service: "edge-function" | "postgres" | "auth" | "realtime")
```

Example JSON log line search query (Supabase Logs UI):
```
metadata->>level = "error"
metadata->>fn = "recommendation-matrix-engine"
metadata->>match_id = "273658b7"
```

### 5.2 Key metrics (operational fitness)

| Fitness | Measurement source | Threshold |
|---------|--------------------|-----------|
| `polish.validation valid=false` rate | recommendation-matrix-engine logs | < 5% (reinforce prompt C or evaluator if exceeded) |
| `raw_quote_detected` rate | llm-prompt-b + normalization-worker logs | < 5% (reinforce prompt B if exceeded) |
| `batch.ok avg_per_pair_ms` | matching-algorithm logs | p95 < 15ms |
| LLM `llm.ok llm_latency_ms` | llm-prompt-* logs | p95 < 5000ms |
| Realtime `matches.change_received` frequency | iOS device logs | review filter if flood detected |

### 5.3 operator_review_queue processing

Operator admin screen (Phase 2):
```sql
SELECT issue_type, count(*), max(created_at)
FROM operator_review_queue
WHERE status = 'pending'
GROUP BY issue_type
ORDER BY count(*) DESC;
```

| issue_type | Action |
|-----------|--------|
| `raw_quote_in_summary` | Reinforce LLM-B prompt then re-invoke, or operator manual paraphrase |
| `unmapped_dealbreaker` | Expand canonical_targets dictionary + re-invoke |
| `polish_validation_failed` | Accumulate stats; reinforce prompt C if > 5% |
| `normalization_failed` | Inspect normalization-worker code (axis_positions mapping dictionary) |

---

## 6. Incident Response

### 6.1 Gemini API failure / key expiry

**Symptoms**: `llm.ok` log stream stops; `polish.llm_call_failed http_status=401/429/500`

**Response**:
1. Google AI Studio console — verify key activation / quota
2. Rotate `GEMINI_API_KEY`: `supabase secrets set GEMINI_API_KEY="..."`
3. In-flight users: `recommendation-matrix-engine` auto-falls back to draft → partial matching flow recovery
4. If `llm-prompt-b` fails: `finalize-domain` auto-rolls back `interviews.status` to `in_progress` → user can retry

### 6.2 Realtime disconnection (iOS)

**Symptoms**: Match candidates or chat rooms not auto-refreshing

**Response**:
1. iOS app auto-reconnects — Supabase SDK 5-second backoff
2. Fallback: match screen pull-to-refresh / manual loadRooms on chat room entry
3. Supabase Studio → Realtime → confirm channel `matches:{userId}` is active

### 6.3 Cache invalidation required

```sql
-- Expire polish cache for a specific viewer
UPDATE polished_output_cache SET expires_at = now() WHERE viewer_id = '...';

-- Full purge (when prompt C version changes)
DELETE FROM polished_output_cache WHERE polish_prompt_version != 'C.v7.1';
```

> `polish_prompt_version` is included in the cache key, so `GEMINI_API_KEY` / model changes do not auto-invalidate. Model ID change → manual cache purge recommended.

### 6.4 raw quote detection rate spike

**Symptoms**: `operator_review_queue WHERE issue_type='raw_quote_in_summary'` frequency spikes

**Response**:
1. Pattern analysis — which domain (`payload->>'domain_id'`) has the highest frequency?
2. Reinforce LLM-B prompt §"self-validation" — add examples for that domain
3. Adjust n-gram threshold (`raw-quote.ts` `ngramMinLength` 8 → 10) — be conservative (risk of false negatives)

### 6.5 Inactive matching pool (0 users)

`needs_review_hidden` handling assumes a sufficient matching pool (≥ 10 users). When initial users < 10, all `needs_review` are marked `fallback_shown` (matching-algorithm v7 §8.6).

---

## 7. Day-to-Day Tasks

### 7.1 Adding a new LLM prompt

1. `_shared/prompts.ts` — add `SYSTEM_PROMPT_X` + `PROMPT_VERSION.X`
2. `backend/supabase/functions/llm-prompt-x/index.ts` — write entry point
3. `backend/supabase/config.toml` — `[functions.llm-prompt-x] verify_jwt = true|false`
4. `supabase functions deploy llm-prompt-x`
5. Update `dependency-map.md` table
6. Add call in iOS Service + wrap with `GyLog.interview.trace`

### 7.2 Adding a new domain (e.g. 7th domain)

1. `migrations/0007_new_domain.sql` — `ALTER TYPE domain_id ADD VALUE 'new_domain'`
2. `_shared/types.ts` — DOMAIN_IDS array + DOMAIN_LABELS_KO
3. `migrations/0005_seed_canonical.sql` — add migration seeding principles/targets/axes for the new domain
4. iOS `DomainID` enum + `OpenQuestion.all` + `Domain.swift indexNumber`
5. Check RLS (analyses/normalized_profiles have no per-domain logic — pass)
6. Add domain name to `prompts.ts` SYSTEM_PROMPT_B (so LLM is aware)
7. UI — `DomainID.allCases.count == 7` auto-updates ProgressBar

### 7.3 User data deletion (PIPA Article 21 right to erasure)

```sql
-- Soft delete
UPDATE users
SET deleted_at = now(), deletion_purges_at = now() + interval '30 days'
WHERE id = '<user_id>';

-- Hard delete after 30 days (cron job recommended)
DELETE FROM users WHERE deletion_purges_at < now();
-- → cascade: consents, interviews, answers, analyses, evidence, core_identities,
--   explicit_dealbreakers, normalized_profiles, matches, chat_rooms, messages
```

> PIPA Article 22 — on consent withdrawal, update `consents.revoked_at` (audit log preserved); service_role only.

---

## 8. References

- System design: `결_시스템설계서_v3.md`
- Matching algorithm: `결_매칭알고리즘_사양_v7.md`
- AI prompts: `결_AI프롬프트_데이터계약_v7.md`
- Core question framework: `결_핵심질문체계_설계문서_v7.md`
- Screen design: `결_화면설계서_v2.md`
- Normalization PRD: `docs/specs/01-prd.md`
- Architecture: `docs/specs/02-architecture.md` (15 ADRs)
- Design system: `docs/specs/03-design-system.md`
- Dependency map: `docs/backend-dependency-map.md`
