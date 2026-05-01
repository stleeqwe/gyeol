# 결 (Gyeol) — AI 시스템 프롬프트 및 데이터 계약 (v7)

> 본 문서는 v6에 코덱스 P0-5 검토를 반영한 v7이다. 핵심 변경: (1) summary에서 raw quote 직접 인용 제거, (2) structured.principle_mix.evidence_quote 폐기 (evidence_ids만 유지), (3) public_safe_summary 명시, (4) 정규화 레이어 raw quote 차단을 *upstream 차원*에서 강제.

> **v6 → v7 주요 변경**: §9 참조.

---

## 1. 데이터 계약 (스키마)

### 1.1 시스템 구조 개요 (v6 그대로)

v6 §1.1 그대로.

### 1.2 프롬프트 라인업 (v6 그대로)

v6 §1.2 그대로.

### 1.3 데이터 비공개 범위 (v7 강화)

각 출력 필드의 노출 범위:

| 필드 | 노출 범위 | v7 변경 |
|---|---|---|
| `summary.where` | match_visible | **public_safe**: raw quote 포함 금지 (v7 강제) |
| `summary.why` | match_visible | **public_safe**: raw quote 포함 금지 (v7 강제) |
| `summary.how` | match_visible | **public_safe**: raw quote 포함 금지 (v7 강제) |
| `summary.tension` | match_visible | **public_safe**: raw quote 포함 금지 (v7 강제) |
| `core_identity.label` | match_visible | public_safe |
| `core_identity.interpretation` | match_visible | public_safe |
| `structured.*` | internal_only | service_role만 접근 |
| `answer_evidence` | self_review_only | 본인만, raw quote 격리 |
| `explicit_dealbreaker.raw_user_text` | self_only | 본인만 |
| `recommendation_narrative` | viewer_only | 매칭 viewer에게만 |

**핵심 v7 변경**: `summary` 필드들이 *match_visible* 노출 범위에 있으므로 *raw quote가 포함되면 매칭 상대에게 노출됨*. 이를 차단하기 위해 v7부터 *public_safe* 제약을 명시.

### 1.4 스키마 1·2·3·4 (프롬프트 A·B·D·E)

#### 1.4.1 프롬프트 A 출력 스키마 (v6 그대로)

v6 그대로.

#### 1.4.2 프롬프트 B 출력 스키마 (v7 변경)

**변경 사항**:
1. `summary.*` 필드에 *public_safe* 제약 명시
2. `structured.principle_mix[].evidence_quote` 폐기, `evidence_ids`만 유지
3. `answer_evidence` 별도 보관 (self_review_only)

**v7 스키마**:

```json
{
  "domain_id": "string",
  
  "summary": {
    "where": "string [public_safe — raw quote 포함 금지]",
    "why": "string [public_safe — raw quote 포함 금지]",
    "how": "string [public_safe — raw quote 포함 금지]",
    "tension": {
      "type": "string",
      "text": "string [public_safe — raw quote 포함 금지]"
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
      "quote": "string [self_review_only — 사용자 raw 답변 직접 인용]",
      "context": "string"
    }
  ]
}
```

**v6 → v7 변경 핵심**:
- `principle_mix[].evidence_quote` 필드 *제거*. v6에서 raw quote가 structured에 포함되어 새어나갈 위험.
- `evidence_ids`만 유지. 실제 quote는 `answer_evidence` 배열에 별도 보관 (self_review_only).
- `sacred_values[].evidence_ids`, `moral_disgust_points[].evidence_ids`도 동일 처리.
- `summary.*` 필드에 *public_safe* 제약 명시. 직접 인용 금지.

#### 1.4.3 프롬프트 D 출력 스키마 (v7 변경)

`core_identity.label`, `core_identity.interpretation`도 *public_safe* 명시.

```json
{
  "core_identity": {
    "label": "string [public_safe — 한 문장]",
    "interpretation": "string [public_safe — 3-5문장]"
  }
}
```

#### 1.4.4 프롬프트 E 출력 스키마 (v6 그대로)

v6 그대로. `raw_user_text`는 self_only이므로 raw quote 격리 무관.

### 1.5 스키마 5 — 추천 이유 후편집 (v6 그대로)

v6 §1.5 그대로.

---

## 2. 시스템 프롬프트 A·B·D·E (v7 변경)

### 2.1 프롬프트 B (영역 분석문) — v7 갱신

#### 2.1.1 프롬프트 본문에 추가되는 절

```
# 출력 안전성 제약 (v7)

당신의 출력 중 다음 필드는 매칭 상대에게 노출됩니다 (match_visible):
- summary.where
- summary.why
- summary.how
- summary.tension.text

이 필드들에는 사용자의 raw 답변에서 직접 인용한 표현을 포함하지 않습니다. 직접 인용 대신 사용자 답변의 *작동 원리*를 본인의 언어로 paraphrase합니다.

다음과 같은 직접 인용은 금지됩니다:
- 작은따옴표·큰따옴표로 감싼 사용자 표현
- 따옴표 없이도 사용자 답변에서 그대로 가져온 5단어 이상의 연속 표현
- 사용자 특유의 어조나 구어체 표현

다음과 같은 paraphrase는 허용됩니다:
- 사용자가 "본인의 몸이고 본인의 인생"이라고 말했다면 → "신체적 자기결정권을 우선하는 결"로 paraphrase
- 사용자가 "거의 사람이고 받아들이기 어렵다"고 말했다면 → "태아의 도덕적 지위가 일정 시점부터 강화된다고 보는 입장"으로 paraphrase

structured 필드는 internal_only이므로 raw quote가 들어가도 외부 노출 안 됩니다. 다만 v7부터 structured.principle_mix[].evidence_quote 필드는 폐기되었으므로, raw quote는 answer_evidence 배열에만 저장합니다.

answer_evidence는 self_review_only — 본인이 발행 전 검토할 때만 보입니다. 매칭 상대에게는 노출되지 않습니다.
```

#### 2.1.2 자가 검증 추가

프롬프트 B 자가 검증에 추가:

```
- summary.where, summary.why, summary.how, summary.tension.text에 raw quote(따옴표 또는 5단어 이상 연속 표현)가 있는가? → 제거하고 paraphrase로 대체
- structured.principle_mix에 evidence_quote 필드가 있는가? → 제거 (v7에서 폐기됨)
- raw quote는 answer_evidence에만 있는가? → 확인
```

### 2.2 프롬프트 D (핵심 유형) — v7 갱신

#### 2.2.1 프롬프트 본문 추가

```
# 출력 안전성 제약 (v7)

core_identity.label, core_identity.interpretation은 매칭 상대에게 노출됩니다 (match_visible).

이 필드들에는 사용자의 raw 답변 직접 인용을 포함하지 않습니다. 사용자 답변의 *작동 원리*를 본인의 언어로 통합 표현합니다.
```

### 2.3 프롬프트 A·E

A·E는 raw quote 노출 위험 적음. 변경 없음.

---

## 3. 시스템 프롬프트 C — 추천 이유 후편집 (v6 그대로)

v6 §3 그대로.

---

## 4. 추천 이유 매트릭스 엔진 (별도 문서 참조)

매트릭스 엔진 v3 참조. v7 변경 없음.

---

## 5. 5개 프롬프트의 관계 (v6 그대로)

v6 §5 그대로.

---

## 6. 호출 비용 추정 (v6 그대로)

v6 §6 그대로 + raw quote 차단으로 인한 *재생성 비용* 추가:

- 정규화 레이어가 raw quote 감지 시 → operator_review_queue → 운영자가 검토
- 운영자가 *운영 단계 보강*이 필요하다고 판단하면 → 프롬프트 B 재호출 (전체 영역 재분석)
- 1차 운영 단계에서 raw quote 감지율 가정: ~5% (LLM이 v7 제약을 따라도 일부 누락)
- 재호출 비용 추가: 사용자 1명당 평균 0.3회 × $0.0085 = ~$0.003 (무시 가능 수준)

운영 데이터로 raw quote 감지율 측정 후 v7 제약 강화·완화 결정.

---

## 7. 검토 요청 사항 (v7)

본 v7 결과물 검토 시 다음 지점에 주목.

**(1) summary 필드의 public_safe 제약 (§1.3, §2.1)**: LLM이 *paraphrase* 원칙을 충분히 따를 수 있는지. 예시 2개로 충분한 가이드인지.

**(2) structured.evidence_quote 폐기 영향 (§1.4.2)**: 폐기 후 정규화 레이어와 매칭 알고리즘이 *evidence 기반 신뢰도 검증*에 충분한지. evidence_ids만으로 fallback 가능한지.

**(3) raw quote 차단의 다중 방어선**:
- 1차: 프롬프트 B 자체에서 paraphrase 강제 (LLM 책임)
- 2차: 정규화 레이어의 raw quote 감지 (시스템 책임, 매칭 알고리즘 v7 §2.2)
- 3차: 매트릭스 엔진의 raw quote 감지 (시스템 책임, 매트릭스 엔진 v3 §5.3)

3중 방어선이 충분한지.

**(4) answer_evidence 별도 보관**: self_review_only 노출 범위가 *본인 검토 화면*에서 자기 raw 답변 인용을 다시 볼 수 있는 형태로 작동하는지.

**(5) 누락된 핵심 요소.**

---

## 8. 영향받는 다른 문서

본 v7 변경에 따른 다른 문서 갱신:

- **매칭 알고리즘 v7**: §2.2 raw quote 차단이 v7 데이터 계약과 정합 — 변경 없음
- **매트릭스 엔진 v3**: 입력으로 받는 summary가 public_safe 보장됨 — 변경 없음
- **시스템 설계서**: structured 스키마 갱신 (evidence_quote 폐기) — 갱신 필요
- **충돌매트릭스 v2**: principle_mix 활용 부분 — 변경 없음 (evidence_ids로 충분)

---

## 9. v6에서 v7로의 주요 변경 사항

### 9.1 summary 필드 public_safe 제약

v6: 모호한 노출 범위 (실제로는 match_visible이지만 raw quote 포함 가능)
v7: 명시적 *public_safe* 제약 + 프롬프트 B 본문 갱신

### 9.2 structured.principle_mix.evidence_quote 폐기

v6: principle_mix 항목에 evidence_quote (raw 인용) 필드 포함
v7: evidence_quote 폐기, evidence_ids만 유지. raw quote는 answer_evidence에만 저장

근거: structured는 internal_only지만 *외부 LLM 호출이나 디버깅 시 누출 위험*. v7부터는 structured 자체에 raw quote가 없으므로 안전.

### 9.3 sacred_values / moral_disgust_points evidence 처리

v6: 일부 LLM 출력에서 evidence quote가 직접 들어감
v7: evidence_ids만 명시. raw 인용은 answer_evidence 배열로 격리

### 9.4 프롬프트 B·D 본문 갱신

v6: 안전성 제약 명시 약함
v7: paraphrase 원칙 + raw quote 금지 명시 + 자가 검증 추가

### 9.5 변경 없는 영역

- 프롬프트 A·C·E (raw quote 위험 적음)
- 데이터 비공개 범위 일반 (v7 강화만)
- 입력 신뢰 경계 원칙 (모든 프롬프트 그대로)
