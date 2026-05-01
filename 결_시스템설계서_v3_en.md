> English translation of 결_시스템설계서_v3.md. Korean original is the authoritative source — this version is a faithful translation for non-Korean-speaking maintainers.

# Gyeol — System Design Document (v3)

> This document is v3, incorporating the following changes from v2: (1) Matrix Engine v3 + Matching Algorithm v7, (2) cost estimate correction (~$720/month for 10K users), (3) PostgreSQL schema updates (polish_cache_key separated, polished_output_cache as a standalone table, evidence_quote deprecated), (4) Apple Speech Framework voice input integration, (5) explicit mention of voice data processing in the PIPA consent form.

> Core decisions from v2 (iOS native, Supabase Seoul, Apple Sign In, Vertex AI, Gemini 3 Flash + 3.1 Flash-Lite split) remain unchanged.

> **Key changes v2 → v3**: see §15.

---

## 1. Summary of Key Decisions

| Area | Choice | Rationale |
|---|---|---|
| Platform | iOS only (Phase 1) | High iOS market share among Korean target users |
| iOS tech stack | Swift + SwiftUI native | Text-centric UX, matches app tone |
| Backend | Supabase (Seoul, AWS ap-northeast-2) | PostgreSQL + Auth + Realtime + Edge Functions in one |
| Auth | Apple Sign In only | Filters for serious users |
| LLM (A·B·D) | Gemini 3 Flash | Core analysis quality |
| LLM (C·E) | Gemini 3.1 Flash-Lite Preview | Sufficient for post-editing and mapping |
| Matrix Engine | Deterministic (no LLM) | First-pass assembly of recommendation rationale |
| LLM hosting | Vertex AI (asia-northeast3 Seoul) | Data residency, no training use |
| **Voice input** [v3 new] | **Apple Speech Framework on-device** | Free, Korean, no external transmission |

---

## 2. System Architecture

### 2.1 Overall Structure (updated in v3)

```
┌─────────────────────────────────────┐
│  iOS App (Swift + SwiftUI)          │
│                                      │
│  + Speech Framework (voice input)    │ [v3 new]
│  + AuthenticationServices (Apple)    │
└─────────────────────────────────────┘
              ↕ HTTPS (TLS 1.3)
              ↕ Supabase Swift SDK
┌─────────────────────────────────────┐
│  Supabase (Seoul ap-northeast-2)    │
│                                      │
│  - Auth (Apple Sign In)              │
│  - PostgreSQL                        │
│    + polished_output_cache (v3)      │
│    + boundary_check_payload (v3)     │
│  - Realtime                          │
│  - Edge Functions (Deno)             │
│    - llm-prompt-a                    │
│    - llm-prompt-b                    │
│    - llm-prompt-c-postedit           │
│    - llm-prompt-d                    │
│    - llm-prompt-e                    │
│    - matching-algorithm              │
│    - explanation-payload-builder     │ [v3 new]
│    - recommendation-matrix-engine    │
│    - post-polish-validation          │ [v3 new]
│    - normalization-worker            │
│    - raw-quote-detector              │ [v3 new]
└─────────────────────────────────────┘
              ↕ HTTPS
┌─────────────────────────────────────┐
│  Vertex AI (asia-northeast3 Seoul)  │
│  - Gemini 3 Flash (A·B·D)            │
│  - Gemini 3.1 Flash-Lite (C·E)       │
└─────────────────────────────────────┘
```

**New Edge Functions in v3**:
- `explanation-payload-builder`: invoked only for final queue candidates. Produces pair_reason_atoms, public sentences, and boundary_check_payload.
- `post-polish-validation`: validates post-editing LLM output against 8 checks.
- `raw-quote-detector`: detects raw quotes in summaries at the normalization layer.

### 2.2 Data Flow (updated in v3)

**(1) Interview → domain analysis → core identity type → explicit dealbreakers**:

Same base flow as v2, with the following additions:
- **Voice input option**: when the user taps the microphone button, the Speech Framework is invoked → the transcribed text is automatically populated into the answer input area.
- Voice is processed *on-device only*. Only the resulting text is sent to the backend.

**(2) Matching flow (updated in v3)**:

```
User taps [Publish as-is]
  ↓
matching-algorithm Edge Function
  - System Hard / User Hard filtering
  - Compatibility score calculation
  - alignment_by_domain computation (alignment_level only)
  - compatibility_assessment_basic finalized
  ↓
Stored in matches table (basic only; explanation_payload is NULL)
  ↓
[Step 2: score ranking + candidate shortlisting]
  ↓
[Step 3: final queue candidates — for UI display]
  ↓ Edge Function trigger (async)
explanation-payload-builder Edge Function (per pair)
  - pair_reason_atoms computed
  - public_alignment_sentence / public_tension_sentence generated
  - boundary_check_payload computed (for this pair)
  - explanation_payload written into matches table
  ↓ Edge Function trigger
recommendation-matrix-engine Edge Function (per pair)
  - draft_narrative assembled deterministically
  - candidate_brief structured (sorted by pair relevance)
  - post-editing quality evaluation
  ↓
needs_polish == true ?
  ├─ Yes → check polished_output_cache
  │         ├─ hit → cached result + post-polish-validation
  │         └─ miss → llm-prompt-c-postedit (Vertex AI)
  │                   ↓
  │                 post-polish-validation (8 checks)
  │                   ├─ pass → save to cache + use
  │                   └─ fail → fall back to draft
  └─ No → use draft_narrative as-is
  ↓
matches table updated (recommendation_narrative)
  ↓
List shown when user enters matching screen
```

**Key v3 changes**:
- The matching algorithm now only runs through *final queue candidate selection*. explanation_payload is built by a separate Edge Function.
- Post-editing results are cached in `polished_output_cache`.
- New `post-polish-validation` Edge Function.

---

## 3. Data Model

### 3.1 PostgreSQL Schema (updated in v3)

Same as v2 §3.1, with the following changes:

#### 3.1.1 `analyses` table — evidence_quote deprecated (v3)

```sql
ALTER TABLE analyses DROP COLUMN structured_evidence_quote;
-- In v6, structured.principle_mix.evidence_quote was stored as JSONB,
-- but deprecated from v7 onward. Only evidence_ids remain in structured;
-- actual quotes are stored separately in the answer_evidence table.

CREATE TABLE answer_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id UUID NOT NULL REFERENCES analyses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    domain_id TEXT NOT NULL,
    
    evidence_id TEXT NOT NULL, -- ev_001, ev_002 ...
    quote TEXT NOT NULL, -- raw quote (self_review_only)
    context TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_answer_evidence_user ON answer_evidence(user_id);
```

Accessible only from the self review screen. The matching algorithm and matrix engine use only evidence_ids.

#### 3.1.2 `matches` table — explanation_payload separated (v3)

```sql
-- v3: explanation_payload stored as jsonb column in matches
ALTER TABLE matches ADD COLUMN compatibility_assessment_basic JSONB;
ALTER TABLE matches ADD COLUMN explanation_payload JSONB; -- may be NULL
ALTER TABLE matches ADD COLUMN boundary_check_payload JSONB; -- may be NULL
ALTER TABLE matches ADD COLUMN polish_cache_key TEXT;
ALTER TABLE matches ADD COLUMN polish_applied BOOLEAN DEFAULT FALSE;
ALTER TABLE matches ADD COLUMN polish_validation_passed BOOLEAN DEFAULT TRUE;
ALTER TABLE matches ADD COLUMN matrix_pattern TEXT;
ALTER TABLE matches ADD COLUMN matrix_template_id TEXT;
ALTER TABLE matches ADD COLUMN recommendation_status TEXT DEFAULT 'pending';
-- pending / ready / needs_review_hidden / fallback_shown

CREATE INDEX idx_matches_recommendation_status ON matches(recommendation_status);
```

#### 3.1.3 `polished_output_cache` table (new in v3)

Caches post-editing LLM results.

```sql
CREATE TABLE polished_output_cache (
    cache_key TEXT PRIMARY KEY, -- SHA-256 hash
    
    viewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    viewer_profile_version TEXT NOT NULL,
    candidate_profile_version TEXT NOT NULL,
    assessment_version TEXT NOT NULL,
    template_library_version TEXT NOT NULL,
    polish_prompt_version TEXT NOT NULL,
    
    draft_hash TEXT NOT NULL,
    
    polished_headline TEXT NOT NULL,
    polished_alignment_narrative TEXT NOT NULL,
    polished_tension_narrative TEXT NOT NULL,
    
    validation_passed BOOLEAN NOT NULL,
    validation_failure_reason TEXT, -- raw_quote_introduced, evaluative_word_introduced, etc.
    
    cached_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ -- 90 days or when polish_prompt_version changes
);

CREATE INDEX idx_polished_cache_viewer ON polished_output_cache(viewer_id);
CREATE INDEX idx_polished_cache_expires ON polished_output_cache(expires_at);
```

viewer_id is included in the cache key → A→B and B→A are cached separately.

#### 3.1.4 `operator_review_queue` table — raw quote detection cases added (v3)

```sql
ALTER TABLE operator_review_queue ADD COLUMN issue_type TEXT;
-- 'raw_quote_in_summary', 'unmapped_dealbreaker', 'tension_generation_failed',
-- 'polish_validation_failed', 'recommendation_status_needs_review'

CREATE INDEX idx_review_queue_issue ON operator_review_queue(issue_type);
```

#### 3.1.5 `interviews` table — voice input usage statistics (v3)

```sql
ALTER TABLE interviews ADD COLUMN voice_input_used BOOLEAN DEFAULT FALSE;
ALTER TABLE interviews ADD COLUMN voice_input_session_count INTEGER DEFAULT 0;
-- Operational analytics metadata. Tracks frequency of voice input usage.
```

### 3.2 RLS Policies (updated in v3)

Same as v2 §3.2, with the following additions:

```sql
-- answer_evidence is self-access only (self_review_only)
CREATE POLICY answer_evidence_self ON answer_evidence
    FOR SELECT USING (auth.uid() = user_id);

-- Other users' answer_evidence is never exposed
-- (service role can only access during operator review)

-- polished_output_cache is accessible only by service_role
-- (users access results only through the matches table)
```

### 3.3 Data Encryption (same as v3)

Same as v2 §3.3, with the following additions:
- `answer_evidence.quote` is also subject to application-level encryption review (stores raw answers).
- `polished_output_cache` is sufficiently covered by standard encryption (no raw quotes; based on public_safe summaries).

---

## 4. LLM Integration

### 4.1 Model Routing Strategy (same as v2)

| Prompt | Model | Call frequency |
|---|---|---|
| A | Gemini 3 Flash | Per answer during interview |
| B | Gemini 3 Flash | Once per domain |
| C | Gemini 3.1 Flash-Lite | 0–1 times per pair (optional) |
| D | Gemini 3 Flash | Once per user |
| E | Gemini 3.1 Flash-Lite | Once per user |
| Normalization worker | Gemini 3 Flash | Async after analysis |

### 4.2 Call Handling (updated in v3)

| Call | Sync/Async | User wait |
|---|---|---|
| A | Synchronous | ~3–5 s |
| B | Synchronous | ~5–10 s |
| D | Synchronous | ~5–8 s |
| E | Synchronous | ~3–5 s |
| C (post-editing) | Asynchronous | Pre-computed, shown immediately |
| Normalization | Asynchronous | Background |
| Matrix engine | Asynchronous | Pre-computed alongside C |
| **explanation-payload-builder** [v3] | Asynchronous | At final queue candidate selection |
| **post-polish-validation** [v3] | Synchronous (immediately after post-editing) | Validation only, ~10 ms |

### 4.3 Cost Estimates (v3 correction — key change)

**v2 §4.3 estimate of ~$4,300/month (10K users) was inaccurate.** The following assumptions were missing:
- Daily matching screen visit rate: 30%
- Exposed candidates per user: 30
- Pair narrative caching (each pair generated only once)

Revised v3 estimates:

#### 4.3.1 Cost per user

**Signup through publish (one-time)**:

| Call | Count | Input | Output | Model | Cost |
|---|---|---|---|---|---|
| Prompt A | ~40 avg | 2K | 500 | 3 Flash | $0.10 |
| Prompt B | 6 | 5K | 2K | 3 Flash | $0.051 |
| Prompt D | 1 | 10K | 1K | 3 Flash | $0.008 |
| Prompt E | 1 | 3K | 1K | 3.1 Flash-Lite | $0.002 |
| Normalization worker | 6 | 2K | 500 | 3 Flash | $0.015 |
| **Total** | | | | | **~$0.18** |

**Cost per pair**:
- Matrix engine: $0 (deterministic)
- Post-editing (50% of pairs + 15% cache hit rate): avg $0.000575 × 0.425 = **~$0.00024**

#### 4.3.2 Steady-state monthly cost at 10K users (v3 corrected)

Assumptions:
- 10,000 active users
- 50 new signups per day
- 30% visit matching screen daily = 3,000 users/day
- 30 exposed candidates per user → 90,000 pair impressions/day
- 70% pair cache hit rate (already generated) → 27,000 new pairs generated/day
- 50% post-editing × 85% cache miss = 11,475 LLM calls/day

| Item | Daily | Monthly |
|---|---|---|
| New user self-analysis | $9 | **$270** |
| Recommendation rationale LLM | $6.6 | **$200** |
| Supabase | — | **$250** |
| **Total** | — | **~$720/month** |

**~6× savings** compared to v2 estimate of ~$4,300/month. ~30× savings compared to v6 single LLM call approach.

#### 4.3.3 Monthly cost by user scale

| Active users | Daily new | Self-analysis | Rec. rationale | Supabase | **Total** | Per user |
|---|---|---|---|---|---|---|
| 100 | 5 | $27 | $5 | $25 | **$60** | $0.60 |
| 1,000 | 20 | $108 | $20 | $75 | **$200** | $0.20 |
| 5,000 | 30 | $162 | $80 | $150 | **$390** | $0.078 |
| 10,000 | 50 | $270 | $200 | $250 | **$720** | $0.072 |
| 50,000 | 100 | $540 | $1,000 | $500 | **$2,040** | $0.041 |

Economies of scale — per-user cost decreases as user base grows.

#### 4.3.4 Business model implications (v3 corrected)

At 10K users, ~$720/month:
- Operable for free. Manageable by an individual operator.
- *Just 0.5% of users subscribing at $10/month* covers costs.
- Partial monetization aligns naturally with the app's identity (serious users).

At 50K users, ~$2,040/month:
- ~$0.04 per user per month.
- Profitable with advertising or simple subscriptions.

Gyeol can run sustainably as a free service.

### 4.4 Vertex AI Integration (same as v2)

Same as v2 §4.4.

### 4.5 Call Stability (added in v3)

Same as v2 §4.5, with the following addition:

**Post-polish stability**:
- Post-editing LLM output validated against 8 checks (raw quote, evaluative language, missing tension, missing boundary language, new domain names, new principle names, JSON validity, length).
- On validation failure → fall back to draft_narrative (LLM result discarded).
- Operator alert if validation failure rate exceeds 5% threshold.

### 4.6 Voice Input Integration (new in v3)

#### 4.6.1 SDK Choice

**Apple Speech Framework (SFSpeechRecognizer)** + iOS system dictation.

Rationale:
- Standard SDK since iOS 10+, supports Korean (ko-KR), free.
- On-device mode (iOS 13+, A9 chip or later): no external server transmission.
- External STT APIs (Google Cloud, Whisper) rejected — cost + burden of sending sensitive data externally.

#### 4.6.2 Integration Pattern

**iOS App side**:
```swift
import Speech

class VoiceInputManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    
    // Force on-device mode
    private func startRecording() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        // ... 60-second silence detection, 1-minute limit bypass (auto-restart)
    }
}
```

**1-minute limit bypass**:
- Auto-restarts the session at the 50-second mark.
- Accumulated text is preserved.
- Appears as continuous recording to the user.

**60-second silence auto-stop**:
- Input level monitored via AVAudioEngine.
- Auto-stops after 60 seconds of silence.
- Toast notification shown.

#### 4.6.3 Backend Integration

Voice input itself has *no backend integration*. Only the transcribed text is sent to the backend as ordinary answer text.

Operational analytics:
- `interviews.voice_input_used`: whether the user used voice input during domain interview.
- `interviews.voice_input_session_count`: cumulative voice session count.

### 4.7 Rate Limit Management (same as v2)

Same as v2 §4.6.

---

## 5. Matching Algorithm Implementation (updated in v3)

### 5.1 Matching Pool Computation Strategy (updated in v3)

**3-stage separation**:

1. **Full pair compatibility score computation** (batch, 1-hour interval):
   - System Hard / User Hard filtering
   - Compatibility score + alignment_level
   - compatibility_assessment_basic
   - Stored in matches table (basic only; explanation_payload is NULL)

2. **Final queue candidate selection** (when user enters matching screen):
   - Per-user score ranking
   - Shortlist of 30 exposed candidates

3. **explanation_payload + Matrix Engine** (async queue):
   - explanation_payload computed only for final queue candidates
   - Matrix Engine invoked
   - Post-editing (if needed) + post-polish-validation
   - explanation_payload + recommendation_narrative written to matches table

Load comparison:
- v2: atoms computed for all 50M pairs → heavy
- v3: Stage 1 covers 50M (basic only, ~5–10 ms/pair); Stage 3 covers ~90K/day (atoms + narrative, ~25 ms/pair)

### 5.2 Edge Function Call Pseudocode (v3)

```typescript
// Stage 1: all pairs — matching-algorithm
async function computeBasicAssessment(pairs: Pair[]) {
    for (const pair of pairs) {
        const basic = await computeCompatibilityBasic(pair);
        await db.matches.upsert({
            viewer: pair.a, candidate: pair.b,
            compatibility_assessment_basic: basic
        });
    }
}

// Stage 3: final queue candidates — explanation-payload-builder + matrix engine
async function generateRecommendation(matchId: UUID) {
    const match = await db.matches.get(matchId);
    
    // Build explanation_payload
    const payload = await buildExplanationPayload(match);
    await db.matches.update(matchId, { explanation_payload: payload });
    
    // boundary_check_payload (for this pair)
    if (match.compatibility_assessment_basic.qualitative_label === 'boundary check') {
        const boundary = await buildBoundaryCheckPayload(match);
        await db.matches.update(matchId, { boundary_check_payload: boundary });
    }
    
    // Matrix engine
    const draft = await callMatrixEngine(match);
    
    // Post-editing quality evaluation
    const needsPolish = evaluateDraftQuality(draft);
    
    let finalNarrative = draft;
    let polishApplied = false;
    let validationPassed = true;
    
    if (needsPolish) {
        // Check cache
        const cacheKey = computePolishCacheKey(match, draft);
        const cached = await db.polishedOutputCache.get(cacheKey);
        
        let polished;
        if (cached) {
            polished = cached;
        } else {
            polished = await callLLMPostedit(draft);
        }
        
        // post-polish-validation
        const validation = validatePolishOutput(draft, polished, match);
        
        if (validation.valid) {
            finalNarrative = polished;
            polishApplied = true;
            
            // Save to cache
            if (!cached) {
                await db.polishedOutputCache.insert({
                    cache_key: cacheKey,
                    polished,
                    validation_passed: true
                });
            }
        } else {
            // Validation failed → fall back to draft
            finalNarrative = draft;
            polishApplied = false;
            validationPassed = false;
            
            // Do not cache (must not reuse a failed polish result)
            
            log.warn('polish_validation_failed', validation.reason);
        }
    }
    
    // Update matches table
    await db.matches.update(matchId, {
        recommendation_narrative: finalNarrative,
        polish_applied: polishApplied,
        polish_validation_passed: validationPassed,
        recommendation_status: 'ready'
    });
}
```

### 5.3 Matrix Engine Internal Implementation

See separate document (결_추천이유매트릭스엔진_v3.md).

### 5.4 Caching and Invalidation (updated in v3)

**Pair narrative caching**:
- explanation_payload + recommendation_narrative in matches table.
- Invalidation triggers: user domain restart, full reset, publish update.

**Post-editing caching** (new in v3):
- polished_output_cache table.
- Cache key: viewer_id + candidate_id + all version fields + draft_hash.
- Invalidation: 90-day expiry or when polish_prompt_version changes.

---

## 6. Authentication and Authorization (same as v2)

Same as v2 §6.

---

## 7. Security and Compliance (updated in v3)

### 7.1 PIPA Compliance (updated in v3)

v2 §7.1 + additions:

**(7) Voice data processing** (new in v3):
- Apple Speech Framework on-device mode used.
- Voice is transcribed directly to text on the user's device.
- Raw voice audio is never sent to external servers.
- Only the transcribed text is sent to the Gyeol backend (Supabase).
- Must be stated explicitly in the consent form.

**(8) Raw quote isolation** (new in v3):
- Direct quotes from user answers are isolated in the `answer_evidence` table (self_review_only).
- `summary` and `core_identity` exposed to match partners are public_safe (raw quotes prohibited).
- If the normalization layer detects raw quotes, they are blocked and added to the operator review queue.

### 7.2 External LLM Data Handling (same as v2)

Same as v2 §7.2.

### 7.3 Data Residency (same as v2 + v3 addition)

Same as v2 §7.3, with addition:
- Voice data: on-device only. No external transmission.

### 7.4–7.5 (same as v2)

---

## 8. iOS App Architecture (updated in v3)

### 8.1 Tech Stack (updated in v3)

- **Language**: Swift 5.9+
- **UI**: SwiftUI (iOS 17+)
- **Minimum iOS version**: iOS 17.0
- **Backend SDK**: Supabase Swift SDK
- **Auth**: AuthenticationServices (Apple Sign In)
- **Voice input (new in v3)**: Speech Framework + AVFoundation
- **Local storage**: SwiftData
- **Networking**: URLSession + async/await

### 8.2 App Architecture (updated in v3)

v2 §8.2 + additional ViewModel:
- `VoiceInputViewModel` (new in v3): manages voice input sessions.

### 8.3 Info.plist Permissions (new in v3)

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Please allow microphone access so you can enter answers by voice. Voice is processed entirely on-device and is not transmitted externally.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>Please allow speech recognition to convert your voice to text. Conversion happens on-device.</string>
```

### 8.4 Offline Handling (same as v2)

Same as v2 §8.3.

### 8.5 Push Notifications (same as v2)

Same as v2 §8.4.

---

## 9. Monitoring and Operations (updated in v3)

### 9.1 Metric Tracking (v3 additions)

v2 §9.1 + the following metrics:

**System metrics (added in v3)**:
- explanation-payload-builder processing time
- post-polish-validation pass rate / failure reason distribution
- polished_output_cache hit rate
- Raw quote detection rate
- needs_review occurrence rate
- Voice input usage rate (voice as a proportion of total answers)

**Operational analytics metrics (added in v3)**:
- alignment_pattern distribution (boundary_check, strong, mostly, balanced, tension, low)
- shared_rejection_targets vs shared_sacred_targets frequency comparison
- stance_distance distribution (at which distances tension is most common)

### 9.2–9.5 (same as v2)

---

## 10. Cost Estimates (consolidated into §4.3)

See §4.3. v2 §10 is retired.

---

## 11. Launch Phase Definitions (updated in v3)

v2 §11 + additions:

**MVP additions (v3)**:
- Matrix Engine v3 (with boundary_check_payload, ALIGNMENT/TENSION multiplier, etc.)
- explanation-payload-builder Edge Function
- post-polish-validation Edge Function
- raw-quote-detector
- polished_output_cache table
- answer_evidence table (separated)
- Voice input integration (Speech Framework)

MVP timeline adds approximately 2 weeks (~28 weeks → ~30 weeks, 7 months → 7.5 months).

---

## 12. Open Decision Points (added in v3)

v2 §12 + additions:

14. **Voice input on by default vs optional**: always show the voice option on all answers vs show only after a user's first use.
15. **1-minute limit approach notification**: visual signal at 50 seconds vs silent auto-restart only.
16. **post-polish-validation coverage**: start with 8 checks vs more.
17. **polished_output_cache expiry**: 90-day TTL vs invalidate on polish_prompt_version change.
18. **answer_evidence as separate table vs JSONB**: search/management convenience vs simplicity.

---

## 13. Next Steps (updated in v3)

This system design document v3, together with the updated 5 product specification documents, captures all decisions through *backend and LLM integration*.

Remaining work:
1. **Design system document v1** — detailed specification of component library and interaction patterns
2. Finalize MVP scope + set schedule
3. Legal review (terms of service and privacy policy — explicit mention of voice data processing)
4. App Store submission preparation
5. Figma mockup work

---

## 14. Alignment with Other Documents (v3)

This v3 is aligned with:

| Document | Version | Alignment area |
|---|---|---|
| Gyeol_AI_Prompt_Data_Contract | v7 | evidence_quote deprecated, public_safe summary, answer_evidence separated |
| Gyeol_Matching_Algorithm_Spec | v7 | compatibility_assessment_basic + explanation_payload separation, stance distance, shared_rejection, boundary_check_payload, post-polish-validation |
| Gyeol_Recommendation_Matrix_Engine | v3 | ALIGNMENT/TENSION multiplier, boundary_check_payload usage, candidate_brief pair relevance sort |
| Gyeol_Conflict_Matrix | v2 | No changes (System Hard / User Hard conflict rules) |
| Gyeol_Core_Question_Framework | v7 | Voice input option, avoidance options pre-disclosure, raw quote isolation |
| Gyeol_Design_Moodboard | v1 | No changes |
| Gyeol_Screen_Design | v2 | Voice input 4-stage screens, avoidance options pre-disclosure modal |
| Gyeol_Screen_Rendering | v2 | v2 HTML with 4 new voice input screens |

---

## 15. Key Changes from v2 to v3

### 15.1 Matching Algorithm v7 + Matrix Engine v3

- compatibility_assessment_basic + explanation_payload separation
- atoms computed only for final queue candidates → reduced load
- Stance distance matrix
- shared_rejection_targets
- boundary_check_payload
- ALIGNMENT/TENSION multiplier
- post-polish-validation

### 15.2 Cost Estimate Correction (§4.3)

v2: 10K users ~$4,300/month (incorrect)
v3: 10K users ~$720/month (correct)

Rationale: added assumptions for 30% daily matching screen visit rate, 30 exposed candidates per user, 70% pair cache hit rate, 15% post-editing cache hit rate.

### 15.3 PostgreSQL Schema Updates

- New `answer_evidence` table (raw quote isolation)
- `matches` table: explanation_payload, boundary_check_payload, polish-related columns added
- New `polished_output_cache` table
- `interviews` table: voice input usage statistics columns added

### 15.4 Apple Speech Framework Voice Input Integration

- SDK selection rationale (§4.6.1)
- iOS integration code pattern (§4.6.2)
- 1-minute limit bypass mechanism
- On-device mode → no external transmission

### 15.5 PIPA Consent Form — Voice Data Explicitly Stated (§7.1)

Principle 7 (new): voice on-device processing.
Principle 8 (new): raw quote isolation.

### 15.6 Unchanged Areas

- §1 key decisions (model, infrastructure unchanged)
- §6 authentication
- §8.4–8.5 iOS app general areas
- §9.2–9.5 general monitoring
- §11 launch phases (minor schedule addition)
