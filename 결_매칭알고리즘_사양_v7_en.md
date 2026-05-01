> English translation of 결_매칭알고리즘_사양_v7.md. Korean original is the authoritative source — this version is a faithful translation for non-Korean-speaking maintainers.

# Gyeol — Matching Algorithm Specification (v7)

> This document is v7, incorporating 13 Codex review changes from v6. The most significant changes are: (1) splitting compatibility_assessment into *basic* and *explanation_payload*, (2) computing explanation_payload *only for final queue candidates, not all pairs*, (3) introducing the stance distance matrix, (4) adding shared_rejection_targets, (5) introducing boundary_check_payload, (6) adding post-polish validation, and (7) separating cache key directionality.

> §2 (normalization layer), §3 (deadline filtering), §4 (compatibility score calculation), §5 (filter pass judgment), §6 (restart), §7 (matching pool eligibility), and §10 (system behavior guarantees) — which were referenced as unchanged from v5 — continue to be referenced as *see v5* in this v7. A fully standalone v7 re-incorporation is planned for the next cycle.

> ## Document Usage Guide
>
> This v7 alone is not standalone. When starting implementation, read the following documents together:
>
> 1. **Gyeol_Matching_Algorithm_Spec_v7.md** (this document) — key changes in §1, §4, §8
> 2. **Gyeol_Matching_Algorithm_Spec_v5.md** — §2, §3, §5, §6, §7, §9, §10 (referenced in this document)
> 3. **Gyeol_Matching_Algorithm_Spec_v3.md** — §3 deadline filtering detail (v5 references v3)
> 4. **Gyeol_Matching_Algorithm_Spec_v4.md** — §4 compatibility score calculation detail (v5 references v4)
> 5. **Gyeol_Conflict_Matrix_v2.md** — System Hard / User Hard conflict rules
> 6. **Gyeol_AI_Prompt_Data_Contract_v7.md** — input data (analyses, normalized_profiles)
> 7. **Gyeol_Recommendation_Matrix_Engine_v3.md** — matrix engine specification at the §8 invocation point
>
> A fully standalone v7 reincorporation is planned for the next cycle (v5/v3/v4 reference sections noted in §13.10).

> **Key changes v6 → v7**: see §13.

---

## 1. Matching System Structure

### 1.1 App Identity (same as v6)

Gyeol is a *serious partnership matching app targeting marriage or a very committed long-term relationship*.

### 1.2 Overall Flow (key change in v7)

```
[Data for all users in matching pool]
            ↓
[Normalization layer] (offline)
            ↓
[Matching pool eligibility check]
            ↓
[Stage 1: all pairs — deterministic compatibility evaluation]
  - System Hard / User Hard filtering
  - Compatibility score calculation
  - alignment_by_domain.alignment_level computed (domain-level intensity only)
  - compatibility_assessment_basic finalized
            ↓
[Stage 2: score ranking + candidate shortlisting]
            ↓
[Stage 3: final queue candidates — only for displayed candidates]
  - explanation_payload computed (pair_reason_atoms + public sentences)
  - boundary_check_payload computed (for boundary check pairs)
            ↓
[Stage 4: Matrix Engine invoked]
  - draft_narrative assembled deterministically
  - post-editing quality evaluation function
  - Prompt C post-editing (LLM, optional)
  - post-polish validation
            ↓
[matches table stored]
            ↓
[List displayed → mutual [Interested] → instant chat room]
```

**Key change v6 → v7**: pair_reason_atoms and public sentences have been moved out of *full pair compatibility scoring* and into the *final queue candidate selection stage*. This reduces load and reinforces Gyeol's identity: *deep analysis, deterministic matching*.

### 1.3 Deterministic vs LLM Separation (same as v6, reinforced)

**Deterministic backend**:
- compatibility_assessment_basic (all pairs)
- explanation_payload (final queue candidates)
- boundary_check_payload (boundary check pairs)
- Matrix Engine first-pass assembly
- post-polish validation (new in v7)

**Offline LLM assist**:
- New natural-language label → canonical ID mapping
- Explicit dealbreaker normalization (Prompt E)

**Online LLM (optional)**:
- Recommendation rationale post-editing (Prompt C, Flash-Lite, 0–1 times per pair)

### 1.4 Data Privacy Principles (same as v6)

Same as v6 §1.4, with the following additions:
- `compatibility_assessment_basic`: internal_only
- `explanation_payload`: internal_only
- `boundary_check_payload`: internal_only

---

## 2. Normalization Layer

**v5 §2 + raw quote blocking reinforcement** (added in v7).

### 2.1 Areas Unchanged from v5

canonical_principles, axis_positions, sacred_targets, disgust_targets, dealbreaker_targets, domain_salience schema, per-domain canonical dictionary, normalization procedures, and offline LLM call specifications — all unchanged from v5 §2.

### 2.2 Raw Quote Blocking (new in v7)

When the normalization layer converts analysis results into normalized profiles, the following checks are performed:

```python
def detect_raw_quote_in_summary(summary):
    """
    Detects direct user answer quotes in
    summary.where, summary.why, summary.how, summary.tension.text.
    """
    
    # Check 1: quotation mark patterns
    quote_patterns = [
        r"['\"]",
        r"['\"][^'\"]{5,}['\"]",
        r"<<.*?>>",
    ]
    
    # Check 2: n-gram overlap with raw answer
    # Continuous substring match of 8+ characters
    overlap = check_ngram_overlap(summary, raw_answer, min_length=8)
    
    if any(re.search(p, summary) for p in quote_patterns):
        return True
    if overlap:
        return True
    return False
```

When a raw quote is detected:
- normalized_profile generation is blocked
- Added to operator_review_queue
- Operator reviews and either regenerates the summary or manually corrects it

This blocking ensures that by the time data reaches the matrix engine input, it is *raw-quote-safe*. The matrix engine itself also has raw quote detection heuristics (multiple defense layers).

---

## 3. Deadline Filtering

**Same as v5 §3.** System Hard / User Hard separation mechanism unchanged.

---

## 4. Compatibility Score Calculation + Data Separation (key change in v7)

### 4.1 v6 → v7 Data Separation

v6: compatibility score calculation produced alignment_summary + pair_reason_atoms + public sentences all at once  
v7: *2-stage separation*

**Stage 1 — full pair compatibility score** (compatibility_assessment_basic):
- final_score
- qualitative_label
- comparable_domain_count
- comparable_domain_weight_sum
- alignment_by_domain (alignment_level + alignment_summary only)
- shared_sacred_targets
- queue_reason

**Stage 2 — final queue candidate explanation expansion** (explanation_payload):
- per-domain pair_reason_atoms
- per-domain public_alignment_sentence
- per-domain public_tension_sentence
- boundary_check_payload (if applicable)

Load reduction:
- v6: atoms computed for all 50M pairs → heavy
- v7: atoms computed only for ~90K daily display candidates → 90%+ reduction

### 4.2 Compatibility Score Calculation (same as v5)

The compatibility score calculation itself is unchanged from v5.

### 4.3 compatibility_assessment_basic Output (defined in v7)

Computed for all pairs:

```json
{
  "compatibility_assessment_basic": {
    "assessment_version": "string",
    "final_score": 0.0,
    "qualitative_label": "alignment" | "compromise" | "boundary check",
    "comparable_domain_count": 0,
    "comparable_domain_weight_sum": 0.0,
    "alignment_by_domain": [
      {
        "domain_id": "string",
        "alignment_level": "strong" | "moderate" | "tension" | "soft_conflict",
        "alignment_score": 0.0,
        "tension_score": 0.0,
        "alignment_summary": "string"
      }
    ],
    "shared_sacred_targets": ["string"],
    "queue_reason": "top_match" | "boundary_check"
  }
}
```

**Differences from v6**:
- pair_reason_atoms removed (moved to explanation_payload)
- public_alignment_sentence, public_tension_sentence removed (moved to explanation_payload)
- alignment_score and tension_score retained as *operational analytics metadata* (the matching algorithm and matrix engine use alignment_level only)

### 4.4 explanation_payload Output (new in v7, final queue candidates only)

Computed only for pairs selected as final queue candidates:

```json
{
  "explanation_payload": {
    "viewer_id": "string",
    "candidate_id": "string",
    "alignment_by_domain": [
      {
        "domain_id": "string",
        "public_alignment_sentence": "string",
        "public_tension_sentence": "string",
        "pair_reason_atoms": {
          "shared_principles": [
            { "principle_id": "string", "label": "string" }
          ],
          "different_principles": [
            { "viewer_position": "string", "candidate_position": "string" }
          ],
          "shared_sacred_targets": ["string"],
          "shared_rejection_targets": ["string"],
          "tension_targets": ["string"]
        }
      }
    ],
    "boundary_check_payload": null
  }
}
```

#### 4.4.1 shared_principles Extraction (same as v6)

Both users hold the same principle with weight high/medium.

#### 4.4.2 different_principles Extraction (same as v6)

Opposite leans on the same axis.

#### 4.4.3 shared_sacred_targets Extraction (same as v6)

Both users have stance require/support + intensity strong/moderate for the same target.

#### 4.4.4 shared_rejection_targets Extraction (new in v7)

Both users have stance reject/avoid + intensity strong/moderate for the same target.

```python
def extract_shared_rejection_targets(viewer_targets, candidate_targets):
    """
    Extracts shared rejection targets. v4 conflict matrix §0 'Sanctity' principle —
    the insight that what binds people together is not only shared values
    but also shared sacred things and shared disgust.
    """
    viewer_rejected = set(
        t.target_id for t in viewer_targets
        if t.stance in ["reject", "avoid"]
        and t.intensity in ["strong", "moderate"]
    )
    candidate_rejected = set(
        t.target_id for t in candidate_targets
        if t.stance in ["reject", "avoid"]
        and t.intensity in ["strong", "moderate"]
    )
    return list(viewer_rejected & candidate_rejected)
```

#### 4.4.5 tension_targets Extraction — stance distance matrix applied (new in v7)

v6's *stance ≠* approach was imprecise. *require vs support* is a small difference; *require vs reject* is a strong conflict. v7 applies the stance distance matrix.

**Stance distance matrix**:

```python
STANCE_DISTANCE = {
    "require":  {"require": 0, "support": 1, "allow": 2, "neutral": 3, "avoid": 4, "reject": 5},
    "support":  {"require": 1, "support": 0, "allow": 1, "neutral": 2, "avoid": 3, "reject": 4},
    "allow":    {"require": 2, "support": 1, "allow": 0, "neutral": 1, "avoid": 2, "reject": 3},
    "neutral":  {"require": 3, "support": 2, "allow": 1, "neutral": 0, "avoid": 1, "reject": 2},
    "avoid":    {"require": 4, "support": 3, "allow": 2, "neutral": 1, "avoid": 0, "reject": 1},
    "reject":   {"require": 5, "support": 4, "allow": 3, "neutral": 2, "avoid": 1, "reject": 0},
}
```

**Tension determination condition (v7)**:

```python
def is_tension_target(viewer_stance, candidate_stance, viewer_intensity, candidate_intensity):
    distance = STANCE_DISTANCE[viewer_stance][candidate_stance]
    max_intensity = max_intensity_level(viewer_intensity, candidate_intensity)
    
    return distance >= 3 and max_intensity in ["moderate", "strong"]
```

Stance combinations with distance >= 3:
- require ↔ neutral, avoid, reject
- support ↔ avoid, reject
- allow ↔ reject
- neutral ↔ require, reject
- avoid ↔ require, support
- reject ↔ require, support, allow, neutral

Only these combinations produce tension. Small differences do not constitute tension.

#### 4.4.6 public_alignment_sentence / public_tension_sentence Generation (same as v6)

Generation rules are unchanged from v6 §4.3.4–§4.3.5.

### 4.5 boundary_check_payload Output (new in v7)

Computed additionally for pairs where qualitative_label is *boundary check*:

```json
{
  "boundary_check_payload": {
    "domain_id": "string",
    "source": "inferred_dealbreaker" | "explicit_dealbreaker",
    "viewer_boundary": "string",
    "candidate_position": "string",
    "confidence": "high" | "medium" | "low"
  }
}
```

**Computation procedure**:

```python
def build_boundary_check_payload(viewer, candidate, assessment):
    """
    Produces specific information about why a boundary check pair
    is a boundary check.
    """
    
    # 1. Identify which domain's dealbreaker is a conflict candidate
    for domain in viewer.normalized_profile:
        # Explicit dealbreakers take priority
        for db in domain.explicit_dealbreakers:
            candidate_target = find_target(candidate, db.target_id, domain.domain_id)
            if candidate_target and candidate_target.stance in db.unacceptable_stances:
                return {
                    "domain_id": domain.domain_id,
                    "source": "explicit_dealbreaker",
                    "viewer_boundary": db.user_text or canonical_label(db.target_id, db.unacceptable_stances),
                    "candidate_position": candidate_target.label_korean,
                    "confidence": "high"
                }
        
        # Check inferred dealbreakers
        for db in domain.inferred_dealbreakers:
            candidate_target = find_target(candidate, db.target_id, domain.domain_id)
            if candidate_target and candidate_target.stance in db.unacceptable_stances:
                return {
                    "domain_id": domain.domain_id,
                    "source": "inferred_dealbreaker",
                    "viewer_boundary": canonical_label(db.target_id, db.unacceptable_stances),
                    "candidate_position": candidate_target.label_korean,
                    "confidence": db.confidence
                }
    
    return None  # Could not find the boundary check reason — very rare
```

### 4.6 alignment_score / tension_score (clarified in v7)

A point that was ambiguous in v6 is now explicit: alignment_score and tension_score are *operational analytics metadata*. The matching algorithm and matrix engine use alignment_level only.

Use cases:
- Track per-domain alignment_score distribution
- Correlate with user feedback (which alignment_score ranges yield higher [Interested] rates)
- Reference when operators adjust alignment_level thresholds

These values have no effect on matching results or recommendation rationale. They are retained — not removed — but explicitly marked as *operational analytics only*.

---

## 5. Filter Pass Judgment

**Same as v5 §5.** No changes.

---

## 6. Post-Publish Restart Handling

**v5 §6 + v7 addition:** when a domain is restarted, this triggers *recomputation of all related pair explanation_payloads* for that user (not full pair recomputation — only for final queue candidate pairs).

---

## 7. Matching Pool Eligibility

**Same as v5 §7.** No changes.

---

## 8. Recommendation Rationale Generation (updated in v7)

### 8.1 Recommendation Rationale Generation Flow (v7)

```
[Filter-passed candidate list]
  ↓
[Final queue candidate selection]
  - Candidates for display on user's matching screen
  - Ranked by score + boundary_check slots
  ↓
[explanation_payload computed]
  - pair_reason_atoms
  - public_alignment_sentence / public_tension_sentence
  - boundary_check_payload (if applicable)
  ↓
[Recommendation Matrix Engine]
  - draft_narrative assembled deterministically
  ↓
[Post-editing quality evaluation function]
  ↓
[Post-editing cache check]
  - hash including viewer_id
  - hit → cached result + post-polish validation
  - miss → invoke Prompt C → post-polish validation → save to cache
  ↓
[post-polish validation]
  - pass → store in matches table
  - fail → fall back to draft_narrative (LLM result discarded)
  ↓
[matches table stored]
```

### 8.2 Matrix Engine I/O (updated in v7)

#### 8.2.1 Matrix Engine Input (v7)

```json
{
  "viewer_user": {
    "user_id": "string",
    "profile_version": "string",
    "core_identity": { ... },
    "summary_by_domain": { ... },
    "domain_published_status": { ... },
    "domain_skip_reasons": { ... }
  },
  "candidate_user": { ... same structure ... },
  "compatibility_assessment_basic": { ... §4.3 ... },
  "explanation_payload": { ... §4.4 ... }
}
```

**Difference from v6**: single compatibility_assessment object → split into compatibility_assessment_basic + explanation_payload.

#### 8.2.2 Matrix Engine Output

Same as v6 §8.2.2.

#### 8.2.3 candidate_brief Handling (same as v6)

Same as v6 §8.2.3.

#### 8.2.4 Matrix Engine Responsibilities (updated in v7)

v6 responsibilities + additions:
- boundary_check_payload usage (for boundary check pairs)
- candidate_brief sorted by *pair relevance priority*

See Matrix Engine v3 document for details.

### 8.3 Post-Editing Quality Evaluation Function

Same as v6 §8.3.

### 8.4 Prompt C Post-Editing + Cache Key Directionality Separation (changed in v7)

**v6**: cache key was the same for both directions (`min(viewer, candidate)` sort)  
**v7**: *viewer_id explicitly included*. A→B and B→A cached separately.

Rationale: if the viewer differs, the narrative differs:
- candidate_brief is candidate-based, so it varies per viewer
- In a boundary check pair, *"your boundary"* refers to a different person depending on the viewer
- The viewer's core_identity feeds into the post-editing context, affecting LLM output

**Cache key (v7)**:

```python
def compute_polish_cache_key(viewer_id, candidate_id, viewer_profile_version, 
                             candidate_profile_version, assessment_version,
                             template_library_version, polish_prompt_version,
                             draft_narrative):
    """
    A→B and B→A are cached separately.
    """
    draft_hash = stable_hash(
        draft_narrative.headline,
        draft_narrative.alignment_narrative,
        draft_narrative.tension_narrative
    )
    return stable_hash(
        viewer_id,  # separate by direction
        candidate_id,
        viewer_profile_version,
        candidate_profile_version,
        assessment_version,
        template_library_version,
        polish_prompt_version,
        draft_hash
    )
```

Cache hit assumption revised in v7: 30% → **15%** (conservative). To be refined with operational data.

### 8.5 Post-Polish Validation (new in v7)

Validates post-editing LLM output. The LLM may distort meaning, add evaluative language, obscure tensions, or re-introduce raw quotes.

**Validation checks**:

```python
def validate_polish_output(draft, polished, context):
    """
    Validates post-editing output. Falls back to draft on failure.
    """
    
    # Check 1: no raw quotes
    if has_raw_quote(polished):
        return ValidationResult(valid=False, reason="raw_quote_introduced")
    
    # Check 2: no evaluative language
    if has_evaluative_word(polished):
        return ValidationResult(valid=False, reason="evaluative_word_introduced")
    
    # Check 3: tension not dropped
    if context.tension_count > 0 and not polished.tension_narrative.strip():
        return ValidationResult(valid=False, reason="tension_dropped")
    
    # Check 4: boundary language retained (for boundary check pairs)
    if context.queue_reason == "boundary_check":
        if not has_boundary_language(polished):
            return ValidationResult(valid=False, reason="boundary_language_dropped")
    
    # Check 5: no new domain names introduced
    draft_domains = extract_domain_names(draft)
    polished_domains = extract_domain_names(polished)
    if polished_domains - draft_domains:
        return ValidationResult(valid=False, reason="new_domain_introduced")
    
    # Check 6: no new principle names introduced
    draft_principles = extract_principle_phrases(draft)
    polished_principles = extract_principle_phrases(polished)
    if polished_principles - draft_principles:
        return ValidationResult(valid=False, reason="new_principle_introduced")
    
    # Check 7: JSON schema valid (already enforced at LLM output stage)
    
    # Check 8: length within ±20% (constraint from AI Prompts v6 §1.5.3)
    if not check_length_constraint(draft, polished, tolerance=0.2):
        return ValidationResult(valid=False, reason="length_out_of_range")
    
    return ValidationResult(valid=True)
```

**On validation failure**:

```python
def handle_polish_failure(draft, polished, validation_result):
    """
    Falls back to draft when post-editing fails.
    """
    log_polish_failure(
        viewer_id, candidate_id, validation_result.reason
    )
    
    # Do not cache (must not reuse a failed polish result)
    
    # Use draft_narrative as the final result
    return draft
```

If the validation failure rate exceeds a threshold (e.g., 5%), an operator alert is triggered. The post-editing prompt or evaluation function needs reinforcement.

### 8.6 needs_review Handling (changed in v7)

**v6**: all needs_review pairs shown to users with a temporary fallback narrative  
**v7**: branched by whether the matching pool is sufficient

```python
def handle_needs_review(match, user_pool_size):
    """
    Handles needs_review pairs.
    """
    
    if user_pool_size >= 10:
        # Sufficient matching pool → hide needs_review candidates from user display
        match.recommendation_status = "needs_review_hidden"
        # Added to operator review queue; not visible to user
    else:
        # Insufficient matching pool → allow temporary fallback display
        match.recommendation_status = "fallback_shown"
        # Temporary narrative based on alignment_summary
        # No "under review" label shown (avoids user anxiety)
        # Operator review prioritized
    
    operator_review_queue.add(match.id, priority="high")
```

Sufficiency threshold (initial assumption): ≥10 filter-passed candidates per user. To be adjusted with operational data.

### 8.7 Final Recommendation Rationale Data Contract (same as v6)

Same as v6 §8.7.

---

## 9. Matching Results Data Contract

**v5 §9 + changes from §8.7.**

---

## 10. System Behavior Guarantees

**v5 §10 + v6 additions + v7 additions.**

Additional guarantees (v7):
- Load separation: full pair load and explanation load are decoupled. As the matching pool grows, only compatibility score load scales proportionally; explanation load scales with *display candidate count* only.
- post-polish validation: deterministic validation ensures the LLM cannot undermine Gyeol's tone and honesty.
- Cache key directionality separation: A→B and B→A narratives are cached with proper separation.
- Stance distance matrix: improved precision for tension determination.

---

## 11. Cost Estimates (v7)

### 11.1 Matching Overhead (corrected in v7)

**v6**: compatibility score + atoms computed together → ~10–20 ms/pair  
**v7**: separated

- **Stage 1 (all pairs)** — compatibility score + alignment_level only: ~5–10 ms/pair
- **Stage 3 (final queue candidates only)** — atoms + public sentences: ~5–10 ms additional

At 10K users (steady state):
- All pairs (batch): 50M × 7 ms = 350K seconds — heavy but handled via batch processing and Edge Function concurrency
- Final queue pairs: 90K/day × 8 ms = 12 minutes of processing

### 11.2 Recommendation Rationale Generation Cost (same as v6 + cache correction)

**Cache hit assumption corrected in v7**: 30% → 15%

Recommendation rationale LLM cost at 10K users (steady state):
- v6: 30% cache hit assumption → ~$600–800/month
- v7: 15% cache hit assumption → ~$700–900/month

Cache hit rate to be refined with operational data. The key factor is how often the same viewer views the same pair multiple times.

### 11.3 Monthly Cost by User Scale (corrected in v7)

| Active users | Daily new | Self-analysis LLM | Rec. rationale LLM | Supabase | **Total** |
|---|---|---|---|---|---|
| 100 | 5 | $30 | $5 | $25 | **~$60/month** |
| 1,000 | 20 | $120 | $55 | $75 | **~$250/month** |
| 5,000 | 30 | $180 | $330 | $150 | **~$660/month** |
| 10,000 | 50 | $300 | $800 | $250 | **~$1,350/month** |
| 50,000 | 100 | $600 | $4,000 | $500 | **~$5,100/month** |

~5–10% increase versus v6 (more conservative cache assumption). Still $0.135 per active user per month at 10K.

---

## 12. Review Requests (v7)

Please pay attention to the following points when reviewing this v7.

**(1) compatibility_assessment_basic / explanation_payload separation.** Whether the separation in §4.1 is appropriate in terms of load and implementation. Whether the trigger mechanisms for Stage 1 and Stage 3 are clear.

**(2) Stance distance matrix application.** Whether the distance >= 3 threshold in §4.4.5 is appropriate. Areas that need reinforcement at the operational stage.

**(3) shared_rejection_targets effectiveness.** Whether the shared rejection extraction in §4.4.4 contributes to expressing *tonal alignment* in the recommendation rationale.

**(4) boundary_check_payload usage.** Whether the payload in §4.5 provides sufficient information for the matrix engine's boundary headline/narrative.

**(5) Raw quote blocking (normalization layer).** Whether the checks in §2.2 cover all raw quote leakage paths. Whether the 8-character n-gram overlap threshold is appropriate.

**(6) Post-polish validation.** Whether the 8 checks in §8.5 sufficiently prevent LLM output from undermining Gyeol's tone.

**(7) needs_review handling.** Whether the pool sufficiency branch in §8.6 is appropriate. Whether the threshold of 10 candidates is reasonable.

**(8) Cache key directionality separation.** Whether including viewer_id in §8.4 is appropriate. Whether the 15% cache hit assumption is conservatively appropriate.

**(9) alignment_score / tension_score as operational analytics.** Whether the handling in §4.6 will cause confusion during code implementation.

**(10) v5 reference sections — standalone reincorporation.** The v5-referenced sections in §13 will be reincorporated as standalone v7 in the next cycle. Left as references in this cycle.

**(11) Missing critical elements.**

---

## 13. Key Changes from v6 to v7

### 13.1 Data Separation — compatibility_assessment_basic + explanation_payload

v6: all data in a single compatibility_assessment  
v7: 2-stage separation; explanation_payload computed only for final queue candidates

**Related changes**:
- §1.2 — Stages 1, 2, 3, 4 made explicit in overall flow
- §4.3 — compatibility_assessment_basic defined
- §4.4 — explanation_payload defined (final queue candidates only)
- §11 — cost estimates corrected (load separation effect)

### 13.2 Stance Distance Matrix Introduced

v6: stance ≠ + intensity difference only  
v7: 6×6 stance distance matrix + distance >= 3 threshold

**Related changes**:
- §4.4.5 — tension_targets extraction refined

### 13.3 shared_rejection_targets Added

Reinforces app identity (Sanctity principle). Shared rejection is also an alignment signal.

**Related changes**:
- §4.4.4 — new section

### 13.4 boundary_check_payload Introduced

v6: only queue_reason "boundary_check" indicated  
v7: payload provides *specific information about which domain's dealbreaker is in conflict*

**Related changes**:
- §4.5 — new section

### 13.5 alignment_score / tension_score Explicitly Marked as Operational Analytics

v6: ambiguous role  
v7: matching algorithm and matrix engine use alignment_level only. scores are operational analytics metadata

**Related changes**:
- §4.6 — clarified

### 13.6 Raw Quote Blocking Reinforced

v6: normalization layer check + matrix engine check  
v7: + n-gram overlap check + operator review queue blocking

**Related changes**:
- §2.2 — new section

### 13.7 Cache Key Directionality Separation

v6: same hash for both directions (sorted by `min(viewer, candidate)`)  
v7: viewer_id explicitly included; A→B and B→A separated

**Related changes**:
- §8.4 — changed
- §11.2 — cache hit assumption corrected (30% → 15%)

### 13.8 Post-Polish Validation Introduced

v7: post-editing LLM output validated against 8 checks

**Related changes**:
- §8.5 — new section

### 13.9 needs_review Handling Changed

v6: all needs_review pairs shown with temporary fallback  
v7: branched by matching pool sufficiency (hidden when pool is sufficient)

**Related changes**:
- §8.6 — changed

### 13.10 Unchanged Areas

- §2 normalization layer (v5 reference + raw quote blocking added)
- §3 deadline filtering (v5 reference)
- §5 filter pass judgment (v5 reference)
- §6 post-publish restart (v5 reference + explanation recomputation added)
- §7 matching pool eligibility (v5 reference)
- §9 matching results data contract (v5 reference)
- §10 system behavior guarantees (v5 reference + v6·v7 additions)

Next cycle: reincorporate v5-referenced sections as standalone v7. Left as references in this cycle to save time.
