# CLAUDE.md

본 파일은 Claude Code (또는 다른 코딩 에이전트)가 이 디렉토리에서 일할 때 참조한다. 동일 내용이 `AGENTS.md`에도 있음 — 다른 에이전트(Codex/Cursor 등)는 그쪽을 본다. 변경 시 두 파일 동기화.

## 프로젝트 정체성

**결 (Gyeol)** — 결혼/장기 연애를 고민하는 사용자를 위한 *가치관 매칭* iOS 앱.

핵심 결정 (Architecture ADR-001 ~ ADR-015 참조):

1. **iOS 전용** Apple Sign In만, 한 명당 하나의 계정
2. **결정론 + LLM 분리** — 매칭 자체는 결정론, narrative 후편집만 LLM
3. **on-device 음성** — Apple Speech Framework, 외부 전송 0
4. **raw quote 격리 3중 방어선** — LLM 자가 검증 + 정규화 n-gram + 매트릭스 엔진 detect
5. **PIPA 23조** — 별도 동의, 한국 데이터 거주 (현재 Google AI Studio, hard requirement 시 Vertex AI Seoul로 교체)
6. **사용자 facade Edge Functions** (ADR-015) — iOS는 plaintext만 전송, ciphertext 변환·service_role 트리거는 Edge에서

## 디렉토리 가이드

| 위치 | 책임 |
|------|------|
| `결_*_v*.md` | 원본 한국어 사양. 변경 금지 (히스토리 보존) |
| `docs/specs/01-prd.md` | PRD — Vision / 타깃 / 6영역 / 매칭 메커닉 / Scope IN/OUT |
| `docs/specs/02-architecture.md` | C4 + ADR 15개 + Fitness Function |
| `docs/specs/03-design-system.md` | Color/Type/Space/Motion + 13화면 매핑 |
| `docs/backend-dependency-map.md` | 6 Data Flow Contracts + Cross-Domain Chains + RLS 트러스트 경계 + Observability |
| `docs/RUNBOOK.md` | 운영 절차 — secrets, 배포, 매칭 트리거, 장애 대응 |
| `backend/supabase/config.toml` | supabase CLI 배포 + verify_jwt 매핑 |
| `backend/supabase/migrations/0001..0006.sql` | DDL+RLS+seed+보안 강화 |
| `backend/supabase/functions/_shared/` | 결정론 라이브러리 + logger + crypto-scaffold |
| `backend/supabase/functions/<name>/` | Edge Function 1개당 1 디렉토리 (19개) |
| `ios/Gyeol/Models/` | Codable structs — Edge `_shared/types.ts`와 정합 |
| `ios/Gyeol/Services/` | Supabase / Auth / Speech / InterviewService / MatchService / ChatService / DraftStore + **Logging.swift** (OSLog 7 카테고리) |
| `ios/Gyeol/ViewModels/` | InterviewViewModel 외 |
| `ios/Gyeol/Views/` | 13개 화면 (+ 흐름 필수 4개) |
| `ios/Gyeol/Components/` | Tokens + Primary/Secondary Button + Mic + Recording + Waveform + ProgressBar + Modal + ChoiceChip + MatchCard + ChatBubble |
| `.claude/ordiq/` | 파이프라인 상태 + 품질 reports (gitignore) |

## Edge Functions 19개 (= 13 핵심 + 6 facade)

| 핵심 (시스템설계 v3 명시) | 사용자 facade (ADR-015) |
|---------------------------|--------------------------|
| llm-prompt-a/b/c-postedit/d/e | bootstrap-user — Apple JWT → public.users |
| matching-algorithm | submit-answer — text_plain → encodeMvpCiphertext → bytea |
| explanation-payload-builder | set-domain-status — skip/private 통합 |
| recommendation-matrix-engine | submit-dealbreakers — raw_texts → bytea |
| post-polish-validation | prepare-review — core_identity + dealbreaker 정규화 보장 |
| raw-quote-detector | request-explanation — lazy 큐 트리거 |
| normalization-worker | (위 6개 모두 verify_jwt=true, 사용자 호출 입구) |
| publish, finalize-domain | |

## 변경 시 정합성 체크리스트

| 변경 | 같이 손봐야 할 곳 |
|------|-------------------|
| 새 영역 추가 | DomainID enum (iOS) + DOMAIN_IDS (Edge `_shared/types.ts`) + canonical seed (0005) + OpenQuestion.all (iOS Models) + RLS 검토 |
| 새 LLM 프롬프트 추가 | `_shared/prompts.ts` PROMPT_VERSION + Edge Function 디렉토리 신규 + `config.toml` verify_jwt + 이 표 갱신 |
| matches 컬럼 추가 | migrations 신규 + matches RLS 검토 + iOS Match struct + ExplanationPayload/RecommendationNarrative 갱신 |
| polish 검증 항목 추가 | `_shared/post-polish-validation.ts` 8가지 → 9가지 + `test_scoring.ts` 단위 테스트 추가 |
| 새 Reactive Sync flow | `docs/backend-dependency-map.md` Contract 추가 (sync_status: COMPLETE 보장) |
| 새 boundary log | logger 정책 PII 점검 (raw text 절대 미노출, ID/enum/version/카운트만) |
| Edge Function 신규 | `supabase/config.toml`에 verify_jwt 명시 + dependency map 표 갱신 + RUNBOOK 운영 절차 |

## 결정론 핵심 함수 (LLM 의존 없음)

- `_shared/stance-distance.ts` — STANCE_DISTANCE 6×6 + isTensionTarget / isSharedSacred / isSharedRejection
- `_shared/raw-quote.ts` — detectRawQuoteInSummary (n-gram 8자 + 따옴표 패턴)
- `_shared/scoring.ts` — computeCompatibilityBasic (1단계, 5-10ms/페어)
- `_shared/explanation.ts` — buildExplanationPayload + buildBoundaryCheckPayload (3단계)
- `_shared/matrix-engine.ts` — assembleDraftNarrative + evaluateDraftQuality (4단계)
- `_shared/post-polish-validation.ts` — validatePolishOutput (8 검사, draft 폴백)
- `_shared/cache-key.ts` — computePolishCacheKey (viewer-isolated)
- `_shared/crypto-scaffold.ts` — encodeMvpCiphertext / decodeMvpCiphertext (bytea round trip)

이 함수들은 변경 시 반드시 `_shared/test_scoring.ts` 단위 테스트를 갱신. **현재 29 tests / 100% PASS.**

## 로깅 정책 (PII 정합)

| 절대 금지 | 허용 |
|----------|------|
| raw 답변 / summary_* / raw_user_text / polished narrative / evidence quote / LLM input/output text | user_id/match_id (8자 short), enum (stance/qualitative/alignment_level), version, latency_ms, duration_ms, *_chars, *_count |

- Edge: `_shared/logger.ts` `loggerFor(fn).info/warn/error/trace`. JSON 한 줄 console → Supabase Logs.
- iOS: `GyLog.{auth,interview,speech,match,chat,realtime,api}.info/warn/error`. OSLog → Console.app.
- 정책 검증: `grep -E "(text_plain|raw_answer|summary_where|interpretation|quote)" 추가된 로그라인 = 0` 자동 점검.

## 자주 하는 작업

```bash
# 결정론 테스트 (Vertex AI 키 없이)
deno test --allow-net=none backend/supabase/functions/_shared/test_scoring.ts
# Edge Function 타입 체크
deno check backend/supabase/functions/**/*.ts
# 단일 / 전체 배포
cd backend && supabase functions deploy <name>
cd backend && supabase functions deploy
# secrets 관리
cd backend && supabase secrets list
cd backend && supabase secrets set GEMINI_API_KEY="..." INTERNAL_CALL_TOKEN="$(openssl rand -hex 32)"
# 마이그레이션 적용 (MCP 또는)
cd backend && supabase db push
# iOS 빌드 (Xcode 필요)
xcodebuild -scheme Gyeol -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 절대 하지 말 것

- `summary` 필드에 raw quote 직접 인용 ✗ (paraphrase only — public_safe 제약)
- `structured` 데이터를 `match_visible` 노출 ✗ (internal_only)
- `answer_evidence`를 매칭 상대에게 노출 ✗ (self_review_only)
- 외부 STT API 호출 ✗ (Apple Speech on-device만)
- `polished_output_cache` 양방향 동일 hash 저장 ✗ (viewer 분리)
- `polish_validation` 실패 시 결과 캐시 저장 ✗ (실패는 재사용 금지)
- LLM 호출 결과를 단위 테스트에 포함 ✗ (결정론만 단위 테스트)
- skip 사유 enum 외 자유 텍스트 추가 ✗
- **로그에 raw text 한 줄도 노출 ✗** (PII 정합. ID/enum/카운트/duration만)
- iOS에서 `interview_answers`/`explicit_dealbreakers`/`analyses` 등을 직접 INSERT ✗ (facade Edge Function 사용 — `submit-answer` / `submit-dealbreakers` 등)

## 운영 단계 보강 항목

코드에 `[1차 스캐폴드]`, `[운영 단계 보강 필요]`로 마킹된 곳:

- `_shared/crypto-scaffold.ts` — KMS envelope encryption 교체 (현재 \\x hex plaintext)
- `_shared/vertex.ts` — PIPA hard requirement 시 Vertex AI Seoul (현재 Google AI Studio)
- `normalization-worker` mapToNormalizedDomain.axis_positions — principle ↔ axis 명시 매핑 사전
- `post-polish-validation` 새 원칙명 검사 — 너무 보수적, 운영 데이터 보강
- `matching-algorithm` failsUserHard — payload 구조 일치 가정, 정합성 강화
- `request-explanation` — 현재 lazy 큐, 운영 단계 pg_cron 배치
