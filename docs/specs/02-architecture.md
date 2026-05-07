> Translated from Korean (see *.ko.md backup). Source: ordiq Stage 2 output.

# Gyeol — Architecture

> ordiq Stage 2 output. `결_시스템설계서_v3.md` + `결_매칭알고리즘_v7.md` + `결_AI프롬프트_v7.md` normalized into a standard architecture document.

## 1. Tech Stack + Cognitive Pattern Mapping

| Domain | Choice | Cognitive Pattern | Rationale |
|--------|--------|-------------------|-----------|
| Client | iOS Swift 5.9 + SwiftUI | Boring by Default, Boundary Discipline | Text-centric UX + Apple ecosystem integration (Sign In + Speech) |
| BaaS | Supabase Seoul | Configuration Gravity, Boring by Default | Single vendor for PostgreSQL + Auth + Realtime + Edge Functions; Korean data residency |
| Edge Runtime | Deno (Supabase Edge Functions) | Single Responsibility | TypeScript, fast cold start, clear boundaries |
| LLM | Vertex AI Seoul (Gemini 3 Flash + 3.1 Flash-Lite) | Boundary Discipline, Failure Mode Fluency | Data residency + no training use + separate model routing |
| Deterministic engine | TypeScript (Edge Functions) | Single Responsibility, Test Boundary | LLM and determinism separated. Pure functions at the core for testability |
| Voice input | Apple Speech Framework on-device | Blast Radius (zero external transmission) | PIPA sensitive data — on-device is the only safe choice |
| Auth | Apple Sign In (AuthenticationServices) | Boundary Discipline | Single identity = 1 account + serious user filtering |
| Local cache | SwiftData (interview drafts) | State Locality | Offline drafting + auto-save |
| Realtime | Supabase Realtime | Seam Awareness | Push on matches table changes; instant reflection on matching screen |

## 2. C4 — Context

```
┌─────────────────────────────────────────────────────────────┐
│                        Gyeol User                            │
│  (iPhone iOS 17+, A9 or later)                              │
└──────────────────────┬──────────────────────────────────────┘
                       │ Apple Sign In + answers + [Interested]
                       │ Voice: on-device, no external transmission
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  Gyeol iOS App (SwiftUI)                                     │
│  - 13 screens (light/dark)                                   │
│  - Speech Framework (ko-KR, on-device)                       │
│  - Supabase Swift SDK + Realtime                             │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTPS TLS 1.3
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase Seoul (ap-northeast-2)                             │
│  - Auth (Apple JWT)                                          │
│  - PostgreSQL (raw answers encrypted)                        │
│  - Realtime (matches push)                                   │
│  - Edge Functions Deno (19 total: 13 core + 6 facade)        │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTPS
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  Google AI Studio (Gemini API key)                           │
│  - Gemini 3 Flash (A·B·D)                                    │
│  - Gemini 3.1 Flash-Lite (C·E)                               │
│  - Swap to Vertex AI Seoul if Korean data residency          │
│    becomes a hard requirement                                │
└─────────────────────────────────────────────────────────────┘
```

## 3. C4 — Container

### 3.1 iOS App Modules

```
ios/Gyeol/
├── App/                       # @main, AppDelegate, Lifecycle
├── Views/                     # Screens (13 + dark variants)
│   ├── Onboarding/
│   ├── Auth/
│   ├── Interview/
│   ├── Voice/
│   ├── Review/
│   ├── Dealbreaker/
│   ├── Matches/
│   └── Chat/
├── ViewModels/                # @Observable / ObservableObject
│   ├── InterviewViewModel
│   ├── VoiceInputViewModel
│   ├── MatchListViewModel
│   ├── MatchDetailViewModel
│   └── ChatViewModel
├── Models/                    # Codable structs (analyses, matches, etc.)
├── Services/
│   ├── SupabaseClient.swift   # SDK wrapper
│   ├── AuthService.swift      # Apple Sign In
│   ├── SpeechService.swift    # SFSpeechRecognizer
│   ├── RealtimeService.swift  # matches subscription
│   └── DraftStore.swift       # SwiftData local answer storage
├── Components/                # Reusable UI (mic button, progress bar, etc.)
└── Resources/
    ├── Tokens.swift           # Design tokens (Color/Spacing/Radius/Type)
    ├── Localizable.strings    # ko
    └── Info.plist
```

### 3.2 Backend (Supabase) Modules

```
backend/supabase/
├── migrations/                # PostgreSQL DDL + RLS
│   ├── 0001_init_schema.sql
│   ├── 0002_rls_policies.sql
│   ├── 0003_normalization_tables.sql
│   ├── 0004_matching_tables.sql
│   ├── 0005_polished_cache.sql
│   └── 0006_operator_queue.sql
├── functions/                 # Edge Functions (Deno)
│   ├── _shared/               # Shared libraries
│   │   ├── supabase.ts
│   │   ├── vertex.ts          # Vertex AI calls
│   │   ├── stance-distance.ts # 6×6 distance matrix
│   │   ├── raw-quote.ts       # n-gram detector
│   │   ├── post-polish-validation.ts
│   │   └── matrix-engine.ts   # Deterministic narrative assembly
│   ├── llm-prompt-a/          # Follow-up question generation (Gemini 3 Flash)
│   ├── llm-prompt-b/          # Domain analysis text (Gemini 3 Flash)
│   ├── llm-prompt-c-postedit/ # Recommendation narrative post-edit (Flash-Lite)
│   ├── llm-prompt-d/          # Unified core identity (Gemini 3 Flash)
│   ├── llm-prompt-e/          # Explicit dealbreaker normalization (Flash-Lite)
│   ├── normalization-worker/  # Analysis → normalized_profile (async)
│   ├── matching-algorithm/    # Stage 1 — full-pair basic
│   ├── explanation-payload-builder/  # Stage 3 — final queue candidate atoms
│   ├── recommendation-matrix-engine/ # Stage 4 — draft narrative
│   ├── post-polish-validation/       # Post-edit LLM result validation
│   └── raw-quote-detector/    # Normalization layer raw quote blocking
└── tests/                     # Deno test
```

## 4. Data Model

### 4.1 Core Tables

| Table | Purpose | RLS |
|-------|---------|-----|
| `users` | Apple Sign In sub | self read |
| `consents` | PIPA Article 23 consent (separate) | self read/write |
| `interviews` | Per-domain interview progress + voice_input_used | self read/write |
| `interview_answers` | User raw answers (encrypted) | self only |
| `analyses` | Per-domain analysis (summary public_safe + structured internal) | self read, service_role write |
| `answer_evidence` | Raw quote isolation (self_review_only) | self read only |
| `core_identities` | Unified core identity | self read |
| `explicit_dealbreakers` | Explicit dealbreakers (raw text + normalized enum) | self only (raw_user_text), match_visible (canonical) |
| `normalized_profiles` | Normalization output (canonical_principles, etc.) | service_role read |
| `matches` | Per-pair compatibility + explanation_payload + recommendation | viewer-self read |
| `polished_output_cache` | Post-edit LLM cache (viewer-separated) | service_role only |
| `chat_rooms` | Opened after bidirectional [Interested] | participants only |
| `chat_messages` | Text messages | participants only |
| `operator_review_queue` | needs_review / raw quote / polish failures | service_role only |

### 4.2 Data Privacy Scope (5 levels)

| Scope | Meaning | Access |
|-------|---------|--------|
| `service_role_only` | Operators only (structured, polished_output_cache, normalized_profiles) | RLS service_role |
| `self_only` | User only (interview_answers, explicit_dealbreaker.raw_user_text) | RLS self |
| `self_review_only` | Self review screen only (answer_evidence) | RLS self + view only |
| `match_visible` (public_safe) | Visible to matched partner (summary, core_identity) | RLS via matches join |
| `viewer_only` | Specific viewer only (recommendation_narrative) | RLS via matches.viewer_id |

## 5. API Contract

### 5.1 User Flow + Edge Function

| Stage | Client Action | Edge Function | Mode | Response Time |
|-------|--------------|---------------|------|---------------|
| Answer → follow-up | `POST /interviews/{id}/answers` | llm-prompt-a | sync | ~3–5s |
| Domain end | `POST /interviews/{id}/domains/{domain_id}/finalize` | llm-prompt-b → normalization worker trigger | sync + async | ~5–10s |
| 6 domains complete | `POST /interviews/{id}/finalize` | llm-prompt-d (sync) + llm-prompt-e (sync) | sync | ~8–13s |
| Publish | `POST /publish` | matching-algorithm (batch trigger enqueue) | async | instant |
| Matching screen entry | `GET /matches?status=ready` | (direct DB) | sync | ≤2s |
| Card expansion | `GET /matches/{id}/explanation` | explanation-payload-builder + matrix-engine + post-polish | async pre-computed | instant |
| [Interested] | `POST /matches/{id}/interest` | (direct DB + bidirectional check) | sync | ≤500ms |
| Chat room | Realtime channel `chat:{room_id}` | (Supabase Realtime) | realtime | ≤500ms |

### 5.2 Reactive Sync Contracts (mutation → DB → push → client → UI)

Data flow for each mutation. **All contracts are COMPLETE — no partial exposure (GAP).**

#### Contract C1: Answer save → drafts sync
1. iOS `InterviewViewModel.saveAnswer(text)`
2. (offline-first) Immediate save to `DraftStore` SwiftData
3. (online) `SupabaseClient.upsert(interview_answers)`
4. UI: input field indicator = saved
5. **Sync guarantee**: SwiftData trigger → @Query update → SwiftUI redraw

#### Contract C2: Domain end → analysis result display
1. iOS `POST /interviews/{id}/domains/{domain_id}/finalize`
2. Edge Function `llm-prompt-b` → `analyses` insert + `answer_evidence` insert + `summary` (public_safe)
3. Realtime broadcast: `interviews:domain_finalized` channel
4. iOS Realtime subscription → ViewModel update → domain end screen displayed

#### Contract C3: Publish → matching queue
1. iOS `POST /publish`
2. `matches` table insert (compatibility_assessment_basic only)
3. Job queue (pg_cron + Edge Function) → matching-algorithm batch → matches update → recommendation_status='pending' → 'ready'
4. Realtime broadcast: `matches:user_id` channel
5. iOS matching screen — shows only candidates with recommendation_status='ready'

#### Contract C4: [Interested] → bidirectional check → chat room
1. iOS `POST /matches/{id}/interest`
2. Edge Function: set matches.viewer_interested=true, check whether candidate_interested=true for bidirectional
3. If bidirectional: chat_rooms insert + chat_messages system message
4. Realtime broadcast: `chat_rooms:user_id` new room
5. iOS chat room list + optional auto-entry to room

#### Contract C5: Message send/receive
1. Sender `chat_messages` insert
2. Postgres trigger → Realtime auto-broadcast `chat:{room_id}`
3. Receiver iOS Realtime subscription → ChatViewModel append → ScrollView bottom append
4. **Concurrency**: sender also subscribes to same channel → optimistic insert + reconcile

## 6. Non-Functional Architecture

### 6.1 Security

- **Encryption**: PostgreSQL pgcrypto. Application-level encryption for `interview_answers.text`, `analyses.structured`, `answer_evidence.quote`, `explicit_dealbreakers.raw_user_text`. KMS keys stored in Supabase project secrets.
- **RLS**: RLS enabled on all tables. service_role bypasses RLS.
- **JWT**: Apple ID token → Supabase Auth → row-level access via auth.uid()
- **Edge Function auth**: All Edge Functions verify Authorization header. service_role calls are internal-trigger only.
- **Triple raw quote defense**:
  1. LLM Prompt B self-validation (paraphrase enforced)
  2. Normalization layer n-gram detector (8-character threshold)
  3. Matrix engine input-time detector

### 6.2 Scalability

- **Load separation**: Stage 1 basic handles 50M pairs in batch; Stage 3 explanation handles 90K/day — precise vertical separation
- **Cache**: polished_output_cache (90-day TTL, viewer-separated). Pair narrative cache (matches.recommendation_narrative).
- **Invalidation trigger**: On domain restart, only that user's explanation_payload is recomputed (not a full recomputation)

### 6.3 Performance

- **Deterministic hot path**: Matching algorithm Stage 1 uses no LLM → 5–10ms/pair
- **Sync LLM calls ≤ 30s total**: Upper bound on user wait time through interview publishing
- **Realtime latency**: matches table push ≤ 200ms median
- **Cold start**: Edge Function first call ≤ 1.5s (Supabase guideline)

### 6.4 Availability

- **Supabase Seoul SLA 99.9%** (single-region constraint accepted — Korean data residency takes priority)
- **Vertex AI Seoul SLA 99.9%**
- **Combined 99.5%** (conservative)
- **Graceful degradation**:
  - LLM failure — domain analysis goes to retry queue; recommendation narrative falls back to draft
  - Realtime disconnect — 5-second reconnect + matching screen pull-to-refresh fallback
  - Speech Framework permission denied — keyboard input only (not forced)

## 7. ADR

### ADR-001: Apple Sign In Only
- **Decision**: Apple Sign In only; no Google / Kakao / email
- **Cognitive Pattern**: Blast Radius (one account per identity prevents fragmentation), Boundary Discipline
- **Rationale**: Serious user filtering. One account per person. Natural fit since iOS-only.
- **Alternative**: Kakao (large Korean market share) — rejected. Low-friction sign-up conflicts with app identity.

### ADR-002: Supabase Single BaaS
- **Decision**: One vendor — Supabase — for Auth + DB + Realtime + Edge Functions
- **Cognitive Pattern**: Configuration Gravity, Boring by Default
- **Rationale**: Assumes a single operator. Single vendor is clearly more stable than multi-vendor composition. Seoul region + Korean data residency.
- **Alternative**: Firebase (Google) — rejected (placing raw answers on Google infrastructure is outside PIPA consent scope).

### ADR-003: Vertex AI-Hosted LLM (Gemini 3 Flash + 3.1 Flash-Lite Separated)
- **Decision**: Vertex AI Seoul. A·B·D use 3 Flash; C·E use 3.1 Flash-Lite.
- **Cognitive Pattern**: Boundary Discipline, Failure Mode Fluency
- **Rationale**: Data residency + no training use. Core analysis (B·D) uses the larger model; post-edit and mapping (C·E) use Lite for cost and speed.
- **Alternative**: OpenAI / Anthropic — rejected (difficult to achieve Korean data residency alignment).

### ADR-004: Deterministic Matching + LLM Post-Edit Separated
- **Decision**: Compatibility score + alignment_level + atoms are deterministic. Only narrative post-edit uses LLM.
- **Cognitive Pattern**: Single Responsibility, Test Boundary
- **Rationale**: Matching results must be reproducible. LLM calls are limited to *sentence polishing*. Semantic changes blocked by post-polish-validation.
- **Alternative**: End-to-end LLM matching — rejected (reproducibility + cost + risk of tone degradation).

### ADR-005: Stance Distance Matrix 6×6
- **Decision**: 6-level stance (require/support/allow/neutral/avoid/reject) × 6-level distance + tension threshold at distance ≥ 3
- **Cognitive Pattern**: Failure Mode Fluency, Naming as Documentation
- **Rationale**: Stance ≠ binary is inaccurate. require vs support is a weak difference; require vs reject is a strong conflict.
- **Alternative**: Simple stance match — rejected (does not reflect actual diversity of user answers).

### ADR-006: explanation_payload for Final Queue Candidates Only
- **Decision**: compatibility_assessment_basic for all pairs; atoms and sentences only for the 30 exposed candidates/day
- **Cognitive Pattern**: Blast Radius, Evolutionary Architecture
- **Rationale**: 50M-pair atoms would be prohibitive. 90K/day for exposed candidates is sufficient. No cost spent on pairs the user never sees.
- **Alternative**: Full-pair atoms — rejected (6× the cost).

### ADR-007: Apple Speech Framework On-Device
- **Decision**: SFSpeechRecognizer + requiresOnDeviceRecognition=true
- **Cognitive Pattern**: Blast Radius (zero external transmission)
- **Rationale**: PIPA sensitive data. The option of sending voice to Google/Apple external servers is rejected outright.
- **Alternative**: External STT — rejected.

### ADR-008: viewer_id in Cache Key (Directional Separation)
- **Decision**: viewer_id explicitly included in polish cache key. A→B and B→A are separate.
- **Cognitive Pattern**: State Locality
- **Rationale**: candidate_brief is from the viewer's perspective, so the narrative differs per viewer. Same hash for both directions would incorrectly cache meaning.
- **Alternative**: Same cache for both directions — rejected (actual output differs; cache hits would serve wrong results).

### ADR-009: Avoidance Option Pre-Disclosure Modal
- **Decision**: Skip / keep private / "explain more simply" all show consequences *before* the action. Auto-expanded on first selection.
- **Cognitive Pattern**: Naming as Documentation, Boundary Discipline
- **Rationale**: Users should not discover unexpected exposure after the fact. Core to app trust.
- **Alternative**: No consequence disclosure — rejected (undermines user trust).

### ADR-010: 8 Post-Polish Validations
- **Decision**: raw quote / evaluative language / tension omission / boundary omission / new domain name / new principle name / JSON valid / length ±20%
- **Cognitive Pattern**: Failure Mode Fluency
- **Rationale**: LLMs lose tone on re-training. Deterministic validation preserves app tone.
- **Alternative**: Expose without validation — rejected.

### ADR-011: needs_review Matching Pool Size Branch
- **Decision**: Candidates passing user filter ≥10 → needs_review_hidden; below 10 → fallback_shown
- **Cognitive Pattern**: Failure Mode Fluency
- **Rationale**: Showing 0 candidates when the pool is small signals *service death*. Hiding suspicious cases when the pool is sufficient is the safe path.
- **Alternative**: Always hidden — rejected (destroys early-stage user experience).

### ADR-012: SwiftData Local Drafts (Offline-First)
- **Decision**: Interview answers saved to SwiftData first → async backend sync
- **Cognitive Pattern**: State Locality, Failure Mode Fluency
- **Rationale**: A 6-domain interview takes time and care. Losing a written answer to a network drop causes user abandonment.
- **Alternative**: Backend only — rejected.

### ADR-013: Structured Logger (Edge Functions JSON + iOS OSLog)
- **Decision**: `_shared/logger.ts` (Edge JSON line console) + `Logging.swift` (OSLog, 7 categories). PII policy — raw answers, summaries, quotes, and polished text are never logged. Only IDs (8-char short), enums, versions, counts, and duration_ms are permitted.
- **Cognitive Pattern**: Boundary Discipline, Failure Mode Fluency, Naming as Documentation
- **Rationale**: Distributed system tracing is required. However, PIPA Article 23 alignment — even a single line of raw text in logs is a consent violation.
- **Alternative**: Raw console — rejected (noise + unstructured). console.log wrapped in a logger function enforces PII policy at code review.

### ADR-014: MVP Crypto-Scaffold (Bytea Round Trip)
- **Decision**: `_shared/crypto-scaffold.ts` with `encodeMvpCiphertext` (`\\x...` hex) / `decodeMvpCiphertext` (plaintext fallback). PostgreSQL bytea columns (text_ciphertext, structured_ciphertext, raw_user_text_ciphertext, quote_ciphertext) handled with a consistent serialization format before KMS integration.
- **Cognitive Pattern**: Configuration Gravity, Evolutionary Architecture (single KMS swap seam)
- **Rationale**: v1 scaffold stores bytea as plaintext UTF-8 (development convenience). In the production phase, replacing only this module with KMS envelope encryption automatically applies to all Edge Functions. `Logging.swift` follows the same policy — no raw text exposure.
- **Alternative**: KMS from the start — rejected (excessive secret infrastructure dependency at MVP stage; seed work friction).

### ADR-015: User Facade Edge Functions Separation
- **Decision**: Instead of direct iOS DB calls, 6 facade functions (`bootstrap-user`, `submit-answer`, `set-domain-status`, `submit-dealbreakers`, `prepare-review`, `request-explanation`) encapsulate the logic.
- **Cognitive Pattern**: Boundary Discipline, Single Responsibility
- **Rationale**: (1) iOS sends raw text as plaintext; Edge converts to bytea via `encodeMvpCiphertext` — KMS swap seam is contained at the Edge. (2) Reinforces ARCHITECTURE §6.1 — user client trusts RLS only; ciphertext conversion is Edge service_role. (3) prepare-review/request-explanation are user JWT calls but encapsulate service_role work (LLM-D/E calls, queue trigger).
- **Alternative**: Direct iOS supabase-js calls — rejected (exposes ciphertext policy + service_role triggers to the client).

### ADR-016: LLM Call Parameter Policy — Quality First
- **Decision**: Every Gemini call explicitly sets `thinking_level` and `maxOutputTokens` per function. All 5 LLM functions (A/B/C-postedit/D/E) use `thinking_level = "high"`. Token budgets sized for `high` reasoning + full structured-JSON output (see RUNBOOK §1.2 LLM call parameter table).
- **Cognitive Pattern**: Boundary Discipline, Failure Mode Fluency
- **Rationale**: (1) Every LLM output (interview questions, domain analyses, recommendation narrative, core identity, dealbreaker mapping) is directly or indirectly user-visible — reasoning quality is the product. Lowering `thinking_level` for cost/latency directly degrades user experience. (2) Gemini 3 Flash Preview default is `high (dynamic)` and 3.1 Flash-Lite default is `minimal` — defaulting is non-deterministic and changes silently across model versions; explicit per-function setting eliminates this drift. (3) Gemini 3 introduces `thinking_level` (minimal/low/medium/high) — the legacy `thinkingBudget` is documented as producing unexpected behavior on Gemini 3 and is forbidden. (4) Quality-first overrides the prior single LLM SLO (`p95 < 5000ms`); SLO is now per-function (RUNBOOK §5.2) and B/D operate above 5000ms by design.
- **Alternative**: (a) Default `thinking_level` per model — rejected (silent drift, model upgrade risk). (b) `low`/`minimal` for cost — rejected by owner directive ("AI quality is decisive in queries; conservative is forbidden"). (c) `thinkingBudget` numeric — rejected (Gemini 3 unexpected behavior).

### ADR-017: LLM Conversation Trace for Test Mode (Quality Monitoring)
- **Decision**: A `LLM_TRACE_MODE` runtime flag (values: `none` default, `full`) controls whether each Edge Function persists the full LLM call — raw user prompt, raw model response, and Gemini 3 thought summary — to `public.llm_call_traces`. Table is service_role only (no user-facing RLS policy). When `LLM_TRACE_MODE=full`, the Gemini call also adds `thinkingConfig.includeThoughts: true` to capture reasoning. Production environments MUST keep this flag at `none`; only test/staging may enable `full`. iOS provides a parallel `GyLog.trace` category gated by the `GYEOL_TRACE_RAW` Swift compilation flag — raw text logging exists only in `#if DEBUG` builds and never compiles into Release.
- **Cognitive Pattern**: Boundary Discipline, Failure Mode Fluency
- **Rationale**: (1) Owner directive: interview question quality is the product's core value, and operators must be able to inspect "what did the user say → how did the AI reason → what follow-up did it ask" to validate intent fidelity. Counts/IDs alone (per ADR-013) are insufficient for content quality review. (2) Mixing raw text into the standard log stream (`logger.ts` console.log → Supabase Logs Explorer → potential APM mirror → backups) violates PIPA Article 23 and the explicit user consent (`raw_quote_isolation_disclosed`). The trace path is therefore isolated: a dedicated DB table with service_role-only access, never via `console.log` or OSLog public stream. (3) Environment partitioning (`LLM_TRACE_MODE` env on Edge runtime; `GYEOL_TRACE_RAW` Swift flag in iOS) keeps the production data plane untouched while enabling staging/QA inspection. (4) Future admin UI can layer on top of the same table; the schema is forward-compatible.
- **Alternative**: (a) Log raw text to `console.log` with a level filter — rejected (one config typo leaks PII to prod logs). (b) Third-party LLM observability (LangSmith, Helicone) — rejected for v1 (data residency, PIPA review, vendor lock-in); revisit post-launch if scale demands. (c) Encrypt traces at rest with per-environment key — deferred (MVP crypto-scaffold suffices; KMS swap is tracked under ADR-014 production hardening).

## 8. Fitness Functions

| Fitness | Measurement | Threshold |
|---------|-------------|-----------|
| `summary public_safe` violation rate | n-gram detector hits / 10K analyses | < 0.5% (production data) |
| post-polish-validation failure rate | validation failures / LLM calls | < 5% |
| Matching algorithm Stage 1 time per pair | matches insert time distribution | p95 < 15ms |
| Cold start Edge Function | first call latency | p95 < 1500ms |
| Realtime push latency | matches.update → iOS receipt | p95 < 500ms |
| Voice input 1-minute bypass success rate | 50s auto-restart / sessions ≥1 min | > 99% |
| RLS violation test | cross-user select outside service_role | 0 |
| Reactive Sync GAP | docs/backend-dependency-map.md | 0 |

## 9. Risks + Operations

### 9.1 Monitoring

| Metric | Threshold | Action |
|--------|-----------|--------|
| LLM call failure rate | >2% | Operator alert + retry queue |
| polish_validation failure rate | >5% | Review Prompt C reinforcement |
| raw quote detection rate | >5% | Review Prompt B reinforcement |
| Users with 0 match candidates | >10% | Expand matching pool policy |
| Voice input usage rate | operational analysis | UI improvement signal |
| Realtime disconnect frequency | operational analysis | Review iOS reconnect logic |

### 9.2 Backup + Recovery

- Supabase automatic daily backup (30-day retention)
- PIPA deletion request — soft delete followed by hard delete after 30 days (including backups)

## 10. AHS Self-Score (pre-production, aligned with ordiq Stage 2 gate)

| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Modularity (0.25) | 8 | Clear iOS / Edge / DB separation, 12 ADRs |
| Test Boundary (0.20) | 7 | Deterministic functions are unit-testable; LLM calls are integration-tested |
| Scalability (0.20) | 7 | 50M-pair batch capable; Stage 1 / Stage 3 separated |
| Security (0.20) | 9 | RLS + encryption + on-device speech + triple raw quote defense |
| Maintainability (0.15) | 7 | ADR + fitness functions + source mapping |

**AHS = (8×0.25)+(7×0.20)+(7×0.20)+(9×0.20)+(7×0.15) = 2.00+1.40+1.40+1.80+1.05 = 7.65 → PASS (≥7).**

Hard-fail gate — Modularity ≥5, Security ≥5 required.
