> English translation of 결_AI프롬프트_데이터계약_v7.md. Korean original is the authoritative source — this version is a faithful translation for non-Korean-speaking maintainers.

# Gyeol — AI System Prompts and Data Contract (v7)

> This document is v7, incorporating Codex P0–5 review changes from v6. Key changes: (1) removal of direct raw quotes from summary, (2) deprecation of structured.principle_mix.evidence_quote (only evidence_ids retained), (3) explicit public_safe_summary labeling, (4) raw quote blocking enforced *upstream* at the normalization layer.

> **Key changes v6 → v7**: see §9.

---

## 1. Data Contract (Schema)

### 1.1 System Structure Overview (same as v6)

Same as v6 §1.1.

### 1.2 Prompt Lineup (same as v6)

Same as v6 §1.2.

### 1.3 Data Visibility Scope (reinforced in v7)

Visibility scope for each output field:

| Field | Visibility | v7 change |
|---|---|---|
| `summary.where` | match_visible | **public_safe**: raw quotes prohibited (enforced in v7) |
| `summary.why` | match_visible | **public_safe**: raw quotes prohibited (enforced in v7) |
| `summary.how` | match_visible | **public_safe**: raw quotes prohibited (enforced in v7) |
| `summary.tension` | match_visible | **public_safe**: raw quotes prohibited (enforced in v7) |
| `core_identity.label` | match_visible | public_safe |
| `core_identity.interpretation` | match_visible | public_safe |
| `structured.*` | internal_only | service_role access only |
| `answer_evidence` | self_review_only | user only; raw quotes isolated |
| `explicit_dealbreaker.raw_user_text` | self_only | user only |
| `recommendation_narrative` | viewer_only | visible to match viewer only |

**Core v7 change**: `summary` fields are in the *match_visible* scope, which means *any raw quote included would be exposed to the match partner*. To prevent this, v7 explicitly enforces a *public_safe* constraint.

### 1.4 Schemas 1–4 (Prompts A, B, D, E)

#### 1.4.1 Prompt A Output Schema (same as v6)

Same as v6.

#### 1.4.2 Prompt B Output Schema (changed in v7)

**Changes**:
1. *public_safe* constraint explicitly stated on `summary.*` fields
2. `structured.principle_mix[].evidence_quote` deprecated; only `evidence_ids` retained
3. `answer_evidence` stored separately (self_review_only)

**v7 Schema**:

```json
{
  "domain_id": "string",
  
  "summary": {
    "where": "string [public_safe — raw quotes prohibited]",
    "why": "string [public_safe — raw quotes prohibited]",
    "how": "string [public_safe — raw quotes prohibited]",
    "tension": {
      "type": "string",
      "text": "string [public_safe — raw quotes prohibited]"
    }
  },
  
  "structured": {
    "surface_position": "string",
    "core_principle": "string",
    "principle_mix": [
      {
        "principle": "string",
        "weight": "high" | "medium" | "low",
        "evidence_ids": ["string"]
      }
    ],
    "sacred_values": [
      {
        "target": "string",
        "stance": "require" | "support" | "allow" | "neutral" | "avoid" | "reject",
        "intensity": "strong" | "moderate" | "mild",
        "scope": "self" | "partner" | "children" | "household" | "public_policy",
        "evidence_ids": ["string"]
      }
    ],
    "moral_disgust_points": [
      {
        "target": "string",
        "intensity": "strong" | "moderate" | "mild",
        "evidence_ids": ["string"]
      }
    ],
    "edge_conditions": [
      {
        "condition": "string",
        "expected_behavior": "string"
      }
    ],
    "self_interest_stability": "stable" | "uncertain" | "shifting",
    "loved_one_stability": "stable" | "uncertain" | "shifting",
    "opposing_view_tolerance": "high" | "medium" | "low",
    "non_negotiables": [
      {
        "boundary": "string",
        "intensity": "strong" | "moderate"
      }
    ],
    "inferred_dealbreaker": [
      {
        "target": "string",
        "unacceptable_stances": ["string"],
        "intensity_min_for_conflict": "strong" | "moderate" | "mild",
        "scope": "string",
        "confidence": "high" | "medium" | "low"
      }
    ],
    "confidence_level": "high" | "medium" | "low",
    "depth_level": "shallow" | "moderate" | "deep"
  },
  
  "answer_evidence": [
    {
      "evidence_id": "ev_001",
      "quote": "string [self_review_only — direct quote from user's raw answer]",
      "context": "string"
    }
  ]
}
```

**Core v6 → v7 changes**:
- `principle_mix[].evidence_quote` field *removed*. In v6, raw quotes could leak through structured fields.
- Only `evidence_ids` retained. Actual quotes stored separately in the `answer_evidence` array (self_review_only).
- `sacred_values[].evidence_ids` and `moral_disgust_points[].evidence_ids` treated the same way.
- *public_safe* constraint explicitly stated on `summary.*` fields. Direct quotation prohibited.

#### 1.4.3 Prompt D Output Schema (changed in v7)

`core_identity.label` and `core_identity.interpretation` also explicitly marked *public_safe*.

```json
{
  "core_identity": {
    "label": "string [public_safe — one sentence]",
    "interpretation": "string [public_safe — 3–5 sentences]"
  }
}
```

#### 1.4.4 Prompt E Output Schema (same as v6)

Same as v6. `raw_user_text` is self_only, so raw quote isolation is not a concern.

### 1.5 Schema 5 — Recommendation Rationale Post-Editing (same as v6)

Same as v6 §1.5.

---

## 2. System Prompts A, B, D, E (changed in v7)

### 2.1 Prompt B (domain analysis) — updated in v7

#### 2.1.1 Section Added to Prompt Body

```
# Output Safety Constraints (v7)

The following fields in your output are visible to match partners (match_visible):
- summary.where
- summary.why
- summary.how
- summary.tension.text

These fields must not contain expressions directly quoted from the user's raw answers. Instead of direct quotation, paraphrase the *underlying principles* of the user's answers in your own language.

The following are prohibited:
- User expressions enclosed in single or double quotation marks
- Sequences of 5 or more consecutive words taken verbatim from a user answer, even without quotation marks
- The user's distinctive conversational tone or colloquial expressions

The following paraphrases are permitted:
- If the user said "it's my body and my life" ("본인의 몸이고 본인의 인생") → paraphrase as "a disposition that prioritizes bodily self-determination"
- If the user said "it's almost a person and I find it hard to accept" ("거의 사람이고 받아들이기 어렵다") → paraphrase as "a position that holds the moral status of the fetus intensifies from a certain point"

structured fields are internal_only, so raw quotes within them will not be exposed externally. However, from v7 onward, the structured.principle_mix[].evidence_quote field is deprecated; raw quotes are stored exclusively in the answer_evidence array.

answer_evidence is self_review_only — it is visible only when the user reviews their own data before publishing. It is not exposed to match partners.
```

#### 2.1.2 Self-Verification Added

The following is added to Prompt B self-verification:

```
- Does summary.where, summary.why, summary.how, or summary.tension.text contain a raw quote (quotation marks or 5+ consecutive words)? → Remove and replace with a paraphrase.
- Does structured.principle_mix contain an evidence_quote field? → Remove (deprecated in v7).
- Are all raw quotes present only in answer_evidence? → Confirm.
```

### 2.2 Prompt D (core identity type) — updated in v7

#### 2.2.1 Section Added to Prompt Body

```
# Output Safety Constraints (v7)

core_identity.label and core_identity.interpretation are visible to match partners (match_visible).

These fields must not contain direct quotations from the user's raw answers. Express the *underlying principles* of the user's answers as an integrated statement in your own language.
```

### 2.3 Prompts A and E

A and E carry low risk of raw quote exposure. No changes.

---

## 3. System Prompt C — Recommendation Rationale Post-Editing (same as v6)

Same as v6 §3.

---

## 4. Recommendation Matrix Engine (see separate document)

See Matrix Engine v3. No changes in v7.

---

## 5. Relationship Among the 5 Prompts (same as v6)

Same as v6 §5.

---

## 6. Call Cost Estimates (same as v6 + v7 addition)

Same as v6 §6, with the addition of *regeneration cost* due to raw quote blocking:

- If the normalization layer detects a raw quote → added to operator_review_queue → operator reviews
- If the operator determines *operational reinforcement* is needed → Prompt B re-invoked (full domain re-analysis)
- Assumed raw quote detection rate in initial operations: ~5% (some may slip through even when the LLM follows v7 constraints)
- Additional re-invocation cost: avg 0.3 calls × $0.0085 per user = ~$0.003 (negligible)

Measure raw quote detection rate with operational data, then decide whether to tighten or relax v7 constraints.

---

## 7. Review Requests (v7)

Please pay attention to the following points when reviewing this v7.

**(1) public_safe constraint on summary fields (§1.3, §2.1)**: Can the LLM sufficiently adhere to the *paraphrase* principle? Are 2 examples enough guidance?

**(2) Impact of structured.evidence_quote deprecation (§1.4.2)**: After deprecation, does the normalization layer and matching algorithm have sufficient *evidence-based reliability validation*? Is fallback possible with evidence_ids alone?

**(3) Multi-layered raw quote blocking defense**:
- Layer 1: Prompt B itself enforces paraphrase (LLM responsibility)
- Layer 2: normalization layer raw quote detection (system responsibility, matching algorithm v7 §2.2)
- Layer 3: matrix engine raw quote detection (system responsibility, matrix engine v3 §5.3)

Is this triple defense sufficient?

**(4) answer_evidence stored separately**: Does the self_review_only visibility scope work as a mechanism allowing users to see their own raw answer quotes during self review before publishing?

**(5) Missing critical elements.**

---

## 8. Impact on Other Documents

Documents requiring updates following this v7 change:

- **Matching Algorithm v7**: §2.2 raw quote blocking is consistent with v7 data contract — no changes needed
- **Matrix Engine v3**: input summary is guaranteed public_safe — no changes needed
- **System Design Document**: structured schema updated (evidence_quote deprecated) — update needed
- **Conflict Matrix v2**: principle_mix usage portions — no changes (evidence_ids sufficient)

---

## 9. Key Changes from v6 to v7

### 9.1 public_safe Constraint on summary Fields

v6: ambiguous visibility scope (effectively match_visible but raw quotes could be included)  
v7: explicit *public_safe* constraint + Prompt B body updated

### 9.2 structured.principle_mix.evidence_quote Deprecated

v6: evidence_quote (raw quotation) field included in principle_mix items  
v7: evidence_quote deprecated; only evidence_ids retained. Raw quotes stored in answer_evidence only

Rationale: although structured is internal_only, there is *risk of leakage via external LLM calls or debugging*. From v7 onward, structured itself contains no raw quotes, making it safe.

### 9.3 sacred_values / moral_disgust_points evidence Handling

v6: some LLM outputs included evidence quotes directly  
v7: only evidence_ids specified. Raw quotations isolated to the answer_evidence array

### 9.4 Prompt B and D Body Updated

v6: safety constraints weakly stated  
v7: paraphrase principle + explicit raw quote prohibition + self-verification added

### 9.5 Unchanged Areas

- Prompts A, C, E (low raw quote risk)
- General data visibility scope (v7 reinforcement only)
- Input trust boundary principles (all prompts unchanged)
