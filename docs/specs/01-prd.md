> Translated from Korean (see *.ko.md backup). Source: ordiq Stage 1 output.

# Gyeol — PRD

> This document is an ordiq pipeline Stage 1 output. PRD-relevant sections extracted and normalized from five Korean specs (`결_시스템설계서_v3.md`, `결_매칭알고리즘_v7.md`, `결_AI프롬프트_v7.md`, `결_핵심질문체계_v7.md`, `결_화면설계_v2.md`). Source files preserved as `결_*_v*.md`.

**Scope Dial: HOLD** — The app's identity is a *matching app that confronts hard questions while leaving room to step back*. Expanding into casual dating (EXPAND) or reducing to simple appearance/spec matching (REDUCE) would both compromise that identity. Therefore: HOLD.

**Anti-Mediocrity Finding**: The pattern *marriage matching = appearance/spec/income + card swipe* is exactly the mediocrity the entire Korean market was stuck in before this app. Elevating *values, beliefs, the sacred, and moral aversion* as matching signals; isolating raw quotes while exposing only paraphrase; and keeping both axes — *hard questions + an escape hatch* — together in one design is this app's core differentiation.

**Idea Quality Score (self-assessment, handoff-ready)**:
- Specificity: 9 (6-domain core questions, stance distance matrix, post-polish validation, and other deterministic specs fully defined)
- Differentiation: 9 (values matching + deterministic engine + LLM isolation + on-device speech + raw quote isolation)
- Feasibility: 7 (LLM cost ~$720/mo @ 10K users, MVP 30 weeks, tech stack validated)
- User Clarity: 8 (serious marriage/long-term relationship candidates, non-casual)

---

## 1. Vision

Gyeol is a **values-based matching iOS app for users pursuing marriage or a deeply serious long-term relationship**.

It asks not about appearance or credentials, but *what you believe and where you will not retreat*. The questions are not light; some are uncomfortable. In that discomfort, a person's *grain* — their gyeol — reveals itself.

For users seeking casual dating or new friends, the app will feel burdensome by design — the entry bar is intentionally narrow.

## 2. Target Users

- **Age**: Late 20s to mid-40s
- **Relationship intent**: Marriage or a deeply serious long-term relationship
- **Self-awareness of values**: Reasonably formed. Can spend 30 minutes to 1 hour articulating *why* they hold their positions across belief, morality, family, life, work, and relationship domains
- **Device**: iPhone (iOS 17+, A9 or later), Korean data residency (Korean)
- **Sensitivity**: Mature enough to *articulate* their own position on sensitive topics (religion, politics, family, sex, abortion, etc.) and *recognize* the possibility of conflict with a match partner's views

## 3. Core Mechanics

### 3.1 6-Domain Values Interview

| Domain | Example Question |
|--------|------------------|
| Belief system | Do you believe something exists after death? How does that belief affect your daily life? |
| Society & the individual | How do you weigh social structures vs. individual responsibility? |
| Bioethics | Self-determination vs. the moral status of life |
| Family & authority | How far does your own decision-making authority extend in your relationships with parents and children? |
| Work & life | The balance between ambition and time/relationships |
| Intimacy | The priority of trust, conflict, honesty, and boundaries |

Each domain has *one open question + N follow-up questions*. Answers can be entered via keyboard or *voice input* (Apple Speech Framework, on-device).

### 3.2 Analysis (LLM-A·B·D·E + Normalization)

- **A — Follow-up question generation** (Gemini 3 Flash, per answer)
- **B — Domain analysis text generation** (Gemini 3 Flash, once per domain): summary (public_safe) + structured (internal_only) + answer_evidence (self_review_only)
- **D — Unified core identity** (Gemini 3 Flash, once per user)
- **E — Explicit dealbreaker normalization** (Gemini 3.1 Flash-Lite, once per user)

**Key data privacy principle**:
- summary.* / core_identity.* — match_visible, **public_safe** (raw quotes prohibited)
- structured.* — internal_only (operators only via service_role)
- answer_evidence — self_review_only (user only)

### 3.3 Matching (3-stage deterministic)

1. **Full-pair compatibility score computation** (batch, 5–10ms/pair): System Hard / User Hard filtering + final_score + alignment_level + compatibility_assessment_basic
2. **Score ranking + filtered candidate generation** (on user entry to matching screen)
3. **Final queue of 30 candidates** → explanation_payload + boundary_check_payload + matrix engine + post-edit (LLM-C optional, Gemini 3.1 Flash-Lite) + 8 post-polish validations

### 3.4 Avoidance Options

Gyeol is an app that *confronts hard questions while leaving room to step back*.

- **Explain more simply** (reduces depth level, up to 3 times)
- **Skip this domain** (4-value enum for reason; user is notified in advance that the *reason will be visible* to their match partner)
- **Keep private** (self-analysis proceeds, but excluded from the matching pool; disclosure is communicated in advance)

### 3.5 Bidirectional [Interested] → Instant Chat Room

Match cards display *alignment / compromise / boundary check* labels. When both parties tap [Interested], a chat room opens immediately.

## 4. Scope

### 4.1 IN — MVP

#### Core Features
- Apple Sign In only (one account per person)
- 6-domain values interview (open questions + follow-up questions)
- Keyboard input + **voice input (on-device Speech Framework, ko-KR)**
- 3 avoidance options + pre-disclosure modal (aligned with PIPA Article 23)
- Per-domain analysis text + unified core identity auto-generated
- Self review screen (before publishing — preview of what match partners will see)
- Explicit dealbreaker input + normalization
- Deterministic matching algorithm (basic + explanation_payload separated)
- Stance distance matrix
- shared_rejection_targets
- boundary_check_payload
- Matrix engine v3 (ALIGNMENT/TENSION multiplier, etc.)
- LLM post-edit + 8 post-polish validations
- Match candidate card list + card expansion
- Bidirectional [Interested] → chat room
- 1:1 text chat (no images/files; first screen)

#### Infrastructure
- Supabase Seoul (PostgreSQL + Auth + Realtime + Edge Functions Deno)
- Vertex AI Seoul (asia-northeast3) — Gemini 3 Flash + 3.1 Flash-Lite
- iOS 17+, Swift 5.9+, SwiftUI

#### Compliance
- PIPA Article 23 sensitive information processing consent (separate consent)
- Voice on-device processing explicitly stated
- Raw quote isolation (answer_evidence separated; summary is public_safe)
- Korean data residency
- AI training data use prohibited

#### Operations
- Normalization layer raw quote detection + operator review queue
- Domain restart (recalculates explanation_payload for that user)
- needs_review handling branch (depending on matching pool size)
- Operational metrics: alignment_pattern distribution, voice input usage rate, polish validation failure rate, raw quote detection rate

### 4.2 OUT — Explicitly Excluded

- **Android** — iOS-only for v1
- **Non-Apple authentication** — to filter for serious users
- **Image/photo uploads** — conflicts with app identity
- **External STT APIs** (Google Cloud, Whisper) — cost + external transmission burden
- **Ads / in-app purchases** (free for v1; breakeven possible with 0.5% user subscriptions later)
- **Group matching, friend recommendations** — outside app identity
- **Location-based matching / distance display** — excluded in v1 (values first)
- **Option to expose detailed answer_evidence to match partner** — always self_review_only
- **User-defined freeform dealbreakers** — normalized via enum + paraphrase

### 4.3 [auto-enriched] — Production Standards Gap-Fill

Items already specified in the source specs but at high risk of being dropped later — tagged auto-enrich.

- Account deletion + full data erasure (PIPA)
- Per-domain data deletion (beyond the 3 avoidance options)
- Session expiry + re-login flow
- Push notification permissions + on/off (new chat messages, new matches)
- Block + report (chat room / candidate card)
- Terms of service / privacy policy consent (voice data processing explicitly stated)
- App lock (FaceID/passcode) — sensitive data protection option
- Auto-save interview answers on background/foreground transition (drafts)
- Answer drafting possible offline + recovery on reconnect
- Private domain preview + modification

### 4.4 [user-enriched] — Deferred to Next Cycle

To be added after separate discussion with user in the next phase:

- Matching screen refresh frequency / debounce policy
- Matching pool dormancy policy for 1-week / 1-month inactivity
- Operator admin screen (operator_review_queue handling)
- App icon/splash / App Store metadata

## 5. Non-Functional Requirements

| Domain | Requirement |
|--------|-------------|
| Performance | Total LLM wait for self-analysis ≤ 30s. Entry to matching screen → candidates visible ≤ 2s. Chat message send/receive ≤ 500ms. |
| Cost | Steady state at 10K users ≤ $720/mo |
| Availability | 99.5% (combined Supabase Seoul + Vertex AI Seoul SLA) |
| Security | Aligned with PIPA. All raw answers encrypted at rest and in transit. Users isolated via RLS. Only service_role can access structured data. |
| Data residency | Korea (Supabase ap-northeast-2 + Vertex AI asia-northeast3) |
| Accessibility | Korean, VoiceOver support, Dynamic Type support, dark mode support |

## 6. Release Phases

- **MVP** (~30 weeks): All IN items above + core operational metrics
- **Phase 2** (~6 weeks): Operator admin, inactivity dormancy handling, push branching
- **Phase 3** (~12 weeks): Android, partial monetization review, multilingual (English)

## 7. Risks

| Risk | Mitigation |
|------|------------|
| Raw quote leakage from LLM output | Triple defense: Prompt B self-validation + normalization layer n-gram detection + matrix engine detection |
| Post-edit LLM degrading app tone | 8 post-polish validations. On failure: draft fallback + no cache write |
| 6 domains = response burden → drop-off | 3 avoidance options + incremental save + voice input |
| needs_review exposure at low pool size | §8.6 matching pool size branch (≥10 candidates: hidden; below: fallback_shown) |
| Apple Speech 1-minute limit | Auto session restart at 50s; appears as continuous recording to the user |
| Values domain = political polarization → operator burden | Deterministic matching + operators handle only needs_review and raw quote cases |

## 8. Source Mapping

| PRD Section | Source Spec |
|-------------|-------------|
| §1 Vision | 결_핵심질문체계_v7.md §1, 결_화면설계_v2.md Screen 1 |
| §2 Target Users | 결_시스템설계서_v3.md §1, 결_핵심질문체계_v7.md §1 |
| §3.1 6 Domains | 결_핵심질문체계_v7.md §2–§9 |
| §3.2 LLM | 결_AI프롬프트_v7.md §1.2, §2 |
| §3.3 Matching | 결_매칭알고리즘_v7.md §1.2, §4 |
| §3.4 Avoidance | 결_핵심질문체계_v7.md §11 |
| §3.5 [Interested] | 결_시스템설계서_v3.md §2.2 |
| §4 Scope | 결_시스템설계서_v3.md §11 + this normalization |
| §5 Non-Functional | 결_시스템설계서_v3.md §4.3, §7, §9 |
| §6 Phases | 결_시스템설계서_v3.md §11 |
