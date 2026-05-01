> Translated from Korean (see .ko.md backup). Authoritative source: code + Korean spec docs.

# Gyeol — Backend Dependency Map

> ordiq Stage 5 artifact (auto-updated: 2026-05-01 — logger / crypto-scaffold / Logging.swift / 29 tests reflected).
> Authoritative sources: system design v3 + matching algorithm v7 + AI prompts v7 + screen design v2 + Architecture §5.

---

## 1. Resources

### 1.1 PostgreSQL Tables (17 tables)

| Table | Migration | RLS | Notes |
|-------|-----------|-----|-------|
| users | 0001 | self read/update | apple_sub UNIQUE |
| consents | 0001 | self read/insert | Separate consent per PIPA Article 23 |
| interviews | 0001 | self read/write | (user_id, domain) UNIQUE |
| interview_answers | 0001 | self only | text_ciphertext bytea |
| analyses | 0001 | self read + match_visible + chat_partner_visible | structured has column-level restriction |
| answer_evidence | 0001 | self read only | self_review_only |
| core_identities | 0001 | self read + match_visible + chat_partner_visible | label/interpretation public_safe |
| explicit_dealbreakers | 0001 | self only | raw_user_text_ciphertext |
| canonical_principles / targets / axes | 0002 | **public read** (strengthened in 0006) | Operator dictionary |
| normalized_profiles | 0002 | service_role only | RLS enabled, no policy |
| matches | 0003 | viewer-self read + candidate-after-chat | trigger sync_pair_interest |
| polished_output_cache | 0003 | service_role only | RLS enabled, no policy |
| chat_rooms | 0003 | participants only | match-id unique |
| chat_messages | 0003 | participants read + insert | sender=auth.uid() check |
| operator_review_queue | 0003 | service_role only | RLS enabled, no policy |

> 0006 security hardening: canonical_* RLS public_read policy added + function search_path fixed + sync_pair_interest REVOKE EXECUTE + pg_trgm extension schema moved.

### 1.2 Edge Functions (19 — 13 core + 6 user-facing facade)

| Function | Input | Output | LLM | Caller | verify_jwt |
|----------|-------|--------|-----|--------|------------|
| llm-prompt-a | interview_id, domain_id, parent_answer_id | follow_up_question | Gemini 3 Flash | iOS InterviewService.generateFollowUp | ✓ |
| llm-prompt-b | interview_id, domain_id | summary, structured, answer_evidence (insert) | Gemini 3 Flash | finalize-domain | ✓ |
| llm-prompt-c-postedit | draft, viewer_core, candidate_core | polished | Gemini 3.1 Flash-Lite | recommendation-matrix-engine (internal) | ✗ (INTERNAL_CALL_TOKEN) |
| llm-prompt-d | (none) | core_identity (upsert) | Gemini 3 Flash | iOS InterviewService.generateCoreIdentity | ✓ |
| llm-prompt-e | (none) | explicit_dealbreakers (update) + operator_review_queue | Gemini 3.1 Flash-Lite | iOS InterviewService.normalizeDealbreakers | ✓ |
| normalization-worker | user_id, domain_id | normalized_profiles (upsert) | (none) | triggered by llm-prompt-b | ✗ |
| matching-algorithm | user_id | matches (upsert × N) | (none) | triggered by publish | ✗ |
| explanation-payload-builder | match_id | matches.explanation_payload (update) | (none) | (pre-computation queue) | ✗ |
| recommendation-matrix-engine | match_id | matches.recommendation_narrative (update) | Gemini 3.1 Flash-Lite (conditional) | (pre-computation queue) | ✗ |
| post-polish-validation | draft, polished, raw_answers, is_boundary_check | valid + reason | (none) | matrix-engine inline + standalone external | ✗ |
| raw-quote-detector | text or fields, raw_answers | detected + reason | (none) | standalone external | ✗ |
| publish | (none) | status: publishing | (none) | iOS InterviewService.publish | ✓ |
| finalize-domain | interview_id, domain_id | summary | (triggers: llm-prompt-b) | iOS InterviewService.finalizeDomain | ✓ |
| **bootstrap-user** | (none) | users row upsert (Apple JWT sub → public.users) | (none) | iOS immediately after Apple Sign In | ✓ |
| **submit-answer** | interview_id, domain, seq, text_plain, depth_level, voice_input_seconds | interview_answers row (text_ciphertext = encodeMvpCiphertext) | (none) | iOS InterviewService.submitAnswer | ✓ |
| **set-domain-status** | interview_id, domain_id, action(skip/private), skip_reason? | interviews status update + skip/private placeholder analyses created | (none) | iOS InterviewService.skip/keepPrivate | ✓ |
| **submit-dealbreakers** | domain, raw_texts[] | explicit_dealbreakers insert (raw_user_text_ciphertext) | (none) | iOS DealbreakerInputScreen | ✓ |
| **prepare-review** | (none) | triggers llm-prompt-d if core_identity absent + triggers llm-prompt-e if dealbreaker not yet normalized | indirect (Gemini 3 Flash + 3.1 Lite) | iOS SelfReviewScreen on entry | ✓ |
| **request-explanation** | match_id? OR limit? | lazy trigger of explanation-payload-builder + recommendation-matrix-engine | indirect (Gemini 3.1 Lite) | iOS MatchListScreen entry / card expand | ✓ |

### 1.3 _shared Libraries (12 + 2 newly added)

| Module | Responsibility | LLM dependency |
|--------|----------------|----------------|
| types.ts | DomainId/Stance/Intensity/AlignmentLevel + analysis schema | X |
| stance-distance.ts | STANCE_DISTANCE 6×6 + isTension/isSharedSacred/isSharedRejection | X |
| raw-quote.ts | detectRawQuoteInSummary (quote marks + n-gram 8 chars) | X |
| scoring.ts | computeCompatibilityBasic (step 1, 5-10ms/pair) | X |
| explanation.ts | buildExplanationPayload + buildBoundaryCheckPayload (step 3) | X |
| matrix-engine.ts | assembleDraftNarrative + evaluateDraftQuality (step 4 deterministic) | X |
| post-polish-validation.ts | validatePolishOutput 8 rules + buildValidationContext | X |
| cache-key.ts | computePolishCacheKey (viewer-isolated) | X |
| prompts.ts | SYSTEM_PROMPT_A·B·C·D·E + PROMPT_VERSION | X (prompt definitions only) |
| supabase.ts | getServiceRoleClient / getUserClient / HttpError / readJson / handleError | X |
| vertex.ts | callGemini / callGeminiJson (direct Google AI Studio call) | ✓ |
| **logger.ts** [new] | Logger class + JSON single-line console output + correlation id | X |
| **crypto-scaffold.ts** [new] | encodeMvpCiphertext / decodeMvpCiphertext (bytea round trip with plaintext fallback) | X |

### 1.4 iOS Modules (Services + ViewModels)

| Module | Responsibility |
|--------|----------------|
| GyeolClient | Supabase SDK wrapper (Auth/Realtime/Functions) |
| AuthService | Apple Sign In + nonce/SHA256 + consent recording |
| SpeechService | SFSpeechRecognizer on-device + 1-min workaround + 60-second silence stop |
| InterviewService | submitAnswer/finalizeDomain/skip/keepPrivate/publish/loadOwnAnalyses/loadOwnCoreIdentity |
| MatchService | loadInitial + Realtime channel `matches:{userId}` filter `viewer_id=eq` + setInterest |
| ChatService | loadRooms + Realtime + send (200-char cap) |
| DraftStore | SwiftData AnswerDraft (offline-first) |
| **Logging.swift** [new] | OSLog Logger — 7 categories (auth/interview/speech/match/chat/realtime/api) + GyLogger.trace stopwatch + UUID.short |

---

## 2. Data Flow Contracts (mutation → DB → push → client → UI)

Each contract: COMPLETE or GAP. Stage 5 gate guarantees GAP=0 (MVP scope).

### Contract C1: Answer saved → drafts + server sync

| Step | Location |
|------|----------|
| 1. iOS InterviewViewModel.submitOpenAnswer / submitFollowUpAnswer | ios/Gyeol/ViewModels/InterviewViewModel.swift |
| 2. SwiftData AnswerDraft.upsert (offline-first) | ios/Gyeol/Services/DraftStore.swift |
| 3. InterviewService.submitAnswer → POST interview_answers | ios/Gyeol/Services/InterviewService.swift (GyLog.interview.trace) |
| 4. RLS check (auth.uid() = user_id) | migrations/0004_rls_policies.sql:answers_self_all |
| 5. iOS @Published answers updated → SwiftUI redraw | InterviewViewModel.answers |

**Sync Status: COMPLETE**

### Contract C2: Domain close → analysis result displayed

| Step | Location |
|------|----------|
| 1. iOS finalize-domain call | InterviewViewModel.finalizeDomain (GyLog.interview.trace) |
| 2. Edge finalize-domain → llm-prompt-b → analyses + answer_evidence + raw quote isolation | functions/finalize-domain + llm-prompt-b (logger: analysis.start/llm.ok/raw_quote_detected/analysis.ok) |
| 3. analyses updated (Realtime optional) | DB |
| 4. InterviewService.loadOwnAnalyses on self-review screen entry → analyses SELECT (RLS self) | SelfReviewScreen.task |

**Sync Status: COMPLETE**

### Contract C3: Publish → matching pool entry → candidate display

| Step | Location |
|------|----------|
| 1. iOS InterviewService.publish | ios/Gyeol/Services/InterviewService.swift |
| 2. Edge publish → validates 6 domains + core_identity → triggers matching-algorithm asynchronously | functions/publish (logger: publish.start/matching_algorithm.trigger/publish.ok) |
| 3. matching-algorithm: computes basic score for all pairs → matches.upsert × N bidirectional | functions/matching-algorithm (logger: batch.start/candidates.loaded/batch.ok with avg_per_pair_ms) |
| 4. explanation-payload-builder + recommendation-matrix-engine called on user entering match screen (queue) | (queue, lazy in MVP) |
| 5. matches.recommendation_status='ready' update | functions/recommendation-matrix-engine (logger: matrix.ok/polish.cache_hit·miss/polish.validation) |
| 6. **Realtime broadcast**: postgres_changes on matches WHERE viewer_id=auth.uid() | Supabase Realtime publication |
| 7. iOS MatchService.subscribeRealtime → channel "matches:{userId}" | ios/Gyeol/Services/MatchService.swift (GyLog.realtime.matches.subscribe.start/ok/change_received) |
| 8. handleChange → loadInitial() refetch → @Published matches updated → MatchListScreen redraw | MatchService |

**Sync Status: COMPLETE**

### Contract C4: mutual [Interested] → chat room auto-created

| Step | Location |
|------|----------|
| 1. iOS MatchService.setInterest(matchId, true) | MatchService (GyLog.match.set_interest) |
| 2. matches.viewer_interest='interested' UPDATE (RLS viewer-self) | matches RLS matches_viewer_interest_update |
| 3. **Trigger sync_pair_interest** (BEFORE UPDATE OF viewer_interest) — search_path = public, pg_temp (0006 security) + REVOKE EXECUTE | migrations/0004 + 0006 |
|   - Syncs candidate_interest on the reverse-direction pair row |
|   - If both sides 'interested': chat_rooms INSERT + system message INSERT |
| 4. **Realtime broadcast**: postgres_changes on chat_rooms WHERE user_a_id OR user_b_id = auth.uid() | Realtime |
| 5. iOS ChatService.subscribeRooms → channel "chat_rooms:{userId}" → handleChange → loadRooms refetch | ChatService |
| 6. ChatRoomsScreen auto-refreshes | ChatRoomsScreen |

**Sync Status: COMPLETE**

### Contract C5: Message send/receive

| Step | Location |
|------|----------|
| 1. ChatService.send(roomId, body) → chat_messages INSERT (RLS sender=auth.uid()) | ChatService (GyLog.chat.send_message) |
| 2. **Trigger bump_room_last_message** → chat_rooms.last_message_at UPDATE — search_path fixed (0006) | migrations/0003 + 0006 |
| 3. **Realtime postgres_changes INSERT** on chat_messages WHERE room_id=eq.{roomId} | Realtime |
| 4. ChatService.openRoom → channel "chat:{roomId}" subscribe → both sender and receiver receive INSERT | ChatService.openRoom (GyLog.realtime.chat.subscribe.ok / chat.message_received) |
| 5. messages append → ScrollViewReader scrollTo(last.id) | ChatRoomScreen |

**Sync Status: COMPLETE**

### Contract C6: Domain restart → explanation_payload recomputed

| Step | Location |
|------|----------|
| 1. iOS Me screen → domain restart (TODO: post-MVP) | (not implemented) |
| 2. interviews.restarted_count++ + status reset | (not implemented) |
| 3. matches WHERE viewer_id=user OR candidate_id=user → explanation_payload=NULL | (operator trigger) |
| 4. explanation-payload-builder re-invoked on re-entering match screen | (queue) |

**Sync Status: GAP** — MVP-out-of-scope, deferred to Phase 2.

---

## 3. Cross-Domain Chains

| Chain | Description |
|-------|-------------|
| Answer text change | interview_answers → analyses → answer_evidence → normalized_profiles → matches.compatibility_assessment_basic → matches.explanation_payload → matches.recommendation_narrative |
| Apple Sign In registration | auth.users → users (Edge Function trigger) → consents (explicit user consent) → interviews can be created |
| Explicit dealbreaker added | explicit_dealbreakers (raw_user_text_ciphertext) → llm-prompt-e → canonical_target_id mapping → matching-algorithm User Hard filter |
| raw quote detection | llm-prompt-b (first-pass self-validation) → normalization-worker (second-pass n-gram detect) → operator_review_queue (insert) → analyses blocked / re-invoke |
| mutual [Interested] | matches.viewer_interest UPDATE → trigger sync_pair_interest → reverse pair row UPDATE → chat_rooms INSERT → chat_messages INSERT (system) |
| polish cache hit | matches.polish_cache_key (computed via cache-key.ts) → polished_output_cache (viewer-isolated) → recommendation_narrative used directly |
| ciphertext bytea round trip [new] | iOS plaintext → Edge POST → encodeMvpCiphertext (\\x...) → bytea column → decodeMvpCiphertext → LLM input |

---

## 4. RLS / Trust Boundary

### 4.1 Column-level access restriction

| Table | Columns blocked for regular users |
|-------|-----------------------------------|
| analyses | structured_ciphertext (app code does not access structured directly; only summary is used) |
| explicit_dealbreakers | raw_user_text_ciphertext (only canonical_target_id and unacceptable_stances are used for matching) |
| answer_evidence | quote_ciphertext (self only; RLS blocks all other users) |

### 4.2 service_role only

- normalized_profiles (normalization results are used only internally by the matching algorithm)
- polished_output_cache (cache results are copied to matches only)
- operator_review_queue (operator admin tooling only)

### 4.3 Trust boundary

- iOS app holds only the Supabase Auth JWT. Cannot access any row other than the user's own.
- Internal Edge Function calls are first validated with the INTERNAL_CALL_TOKEN header.
- service_role key lives only in Supabase secrets — never exposed to clients.
- sync_pair_interest function: REVOKE EXECUTE FROM anon, authenticated, public (0006).

---

## 5. Reactive Sync GAPS

| # | Contract | Status | Decision |
|---|----------|--------|----------|
| 1 | C6 domain restart → explanation_payload recomputed | GAP | MVP-out-of-scope, deferred to Phase 2 |

**MVP scope GAP count: 0.** 1 Phase 2 item tracked separately.

---

## 6. Observability (Logging)

### 6.1 Edge Functions structured logger

`loggerFor(fn, ctx?)` from `_shared/logger.ts` → `Logger` instance. Single-line JSON console output → automatically collected by Supabase Edge Logs.

**Environment variable**: `LOG_LEVEL=debug|info|warn|error` (default: info).

**Boundary pattern**:
- `{action}.start` / `{action}.ok` / `{action}.fail` (or trace stopwatch)
- request_id (12-char short UUID), user_id (if needed), match_id, domain_id

**Example log lines (recommendation-matrix-engine)**:
```
matrix.start match_id=273658b7
draft.assembled qualitative_label=alignment headline_chars=18 alignment_chars=86 tension_chars=42
polish.evaluation needs_polish=true reasons=["too_short","generic_headline"]
polish.cache_miss cache_key_prefix=a3f1c2d8
polish.llm_call_ok latency_ms=2340 prompt_version=C.v7.0
polish.validation valid=false reason=new_domain_introduced
matrix.ok polish_applied=false polish_validation_passed=false
```

### 6.2 iOS OSLog (Logging.swift)

`GyLog.{category}` → `GyLogger` (OSLog-based). 7 categories.

| Category | subsystem | Caller |
|----------|-----------|--------|
| auth | com.gyeol.app | AuthService |
| interview | com.gyeol.app | InterviewService + InterviewViewModel |
| speech | com.gyeol.app | SpeechService (session lifecycle, 1-min workaround, silence stop) |
| match | com.gyeol.app | MatchService (load, set_interest) |
| chat | com.gyeol.app | ChatService |
| realtime | com.gyeol.app | MatchService/ChatService Realtime channels |
| api | com.gyeol.app | (reserved) |

### 6.3 PII policy (regulated profile compliance)

| Strictly prohibited | Allowed |
|--------------------|---------|
| raw answers, summary text, raw_user_text, polished narrative, evidence quote, LLM input/output text | user_id/match_id (8-char short), enum, version, latency_ms, duration_ms, *_chars, *_count |

> Verification: `grep -E "(text_plain|raw_answer|summary_where|interpretation|quote)"` on added log lines = 0 hits (see `.claude/ordiq/reports/ordiq-log-health.json`)

---

## 7. Deterministic Unit Tests (29 tests, 100% PASS)

`backend/supabase/functions/_shared/test_scoring.ts` — `deno test --allow-net=none`

| Category | Function | Test count |
|----------|----------|------------|
| crypto-scaffold | encode/decode round trip + plaintext fallback | 2 |
| stance-distance | STANCE_DISTANCE 6×6, isTensionTarget, isSharedSacred, isSharedRejection | 7 |
| raw-quote | quote mark patterns, n-gram 8 chars, paraphrase pass | 3 |
| scoring | computeCompatibilityBasic match/dealbreaker conflict | 2 |
| matrix-engine | evaluateDraftQuality short/long, assembleDraftNarrative alignment/boundary check | 4 |
| post-polish-validation | raw quote/evaluative language/length/valid polish | 4 |
| explanation | buildExplanationPayload shared principles/rejection, buildBoundaryCheckPayload explicit/null | 4 |
| cache-key | computeDraftHash consistency, computePolishCacheKey directional isolation, version-change invalidation | 3 |

---

## 8. Map Health Self-Score

| Dimension | Score | Basis |
|-----------|-------|-------|
| Completeness (0.30) | 9 | All 17 tables + 19 Edge Functions (13 core + 6 facade) + 12+2 libs + 6 contracts traced |
| Accuracy (0.25) | 9 | Consistent with code. RLS, triggers, channel filters, logger calls all specified. logger.ts/crypto-scaffold.ts additions reflected |
| Reactive Sync (0.25) | 8 | 5 contracts COMPLETE, 1 contract MVP-out-of-scope, 0 unresolved GAPs |
| Cross-Domain (0.20) | 9 | 7 chains specified (ciphertext bytea round trip added) |

**Map Health Score = (9×0.30)+(9×0.25)+(8×0.25)+(9×0.20) = 2.70+2.25+2.00+1.80 = 8.75 → PASS (≥7).**

Hard-fail gate — Completeness ≥5, Accuracy ≥4 required.
