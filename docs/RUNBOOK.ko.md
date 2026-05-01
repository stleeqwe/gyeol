# 결 (Gyeol) — 운영 RUNBOOK

> 운영 절차 매뉴얼. 신규 인입자 / 장애 대응 / 일상 작업 모두 본 문서 한 권.
> 권위 source: `02-architecture.md` + `backend-dependency-map.md` + 코드.

---

## 1. 환경 정보

| 항목 | 값 |
|------|----|
| Supabase 프로젝트 ref | `xkgffegenrvitalgncnt` |
| URL | `https://xkgffegenrvitalgncnt.supabase.co` |
| 리전 | `ap-northeast-2` (Seoul) |
| PostgreSQL | 17.6 |
| 마이그레이션 | 로컬 재현 0001..0006 |
| Edge Functions | 19개 ACTIVE (13 핵심 + 6 facade) |
| LLM provider | Google AI Studio (key 설정) — gemini-3-flash-preview / gemini-3.1-flash-lite-preview |

---

## 2. Secrets 관리

### 2.1 필수 secrets

```bash
cd backend
supabase secrets list
```

| 키 | 상태 | 출처 |
|----|------|------|
| `INTERNAL_CALL_TOKEN` | ✅ 설정됨 | `openssl rand -hex 32` |
| `GEMINI_API_KEY` | ✅ 설정됨 | https://aistudio.google.com/apikey |
| `GEMINI_FLASH_MODEL` | ✅ `gemini-3-flash-preview` | (옵션 override) |
| `GEMINI_LITE_MODEL` | ✅ `gemini-3.1-flash-lite-preview` | (옵션 override) |
| `SUPABASE_URL` | ✅ Edge runtime 자동 주입 | (자동) |
| `SUPABASE_SERVICE_ROLE_KEY` | ✅ Edge runtime 자동 주입 | (자동) |
| `SUPABASE_ANON_KEY` | ✅ Edge runtime 자동 주입 | (자동) |
| `LOG_LEVEL` | (옵션, 기본 `info`) | `debug` 시 boundary 외 상세 추적 |

### 2.2 키 로테이션 (PIPA 정합)

```bash
# INTERNAL_CALL_TOKEN 로테이션 (모든 internal-only Edge Function 호출 영향)
NEW=$(openssl rand -hex 32)
cd backend && supabase secrets set INTERNAL_CALL_TOKEN="$NEW"
# → Edge Function 재시작은 자동 (다음 콜드 스타트부터 적용, ~1-2분)
# → 모든 facade Edge Function (publish/finalize-domain/...) 자동 적용
```

> Gemini API key는 Google AI Studio 콘솔에서 별도 로테이션 → secrets set으로 갱신.

---

## 3. 배포 절차

### 3.1 Edge Function 배포

```bash
cd backend
# 단일 함수
supabase functions deploy llm-prompt-b
# 전체 (config.toml verify_jwt 매핑 자동 적용)
supabase functions deploy
```

배포 후 검증:
```bash
# 함수 목록 + 상태
supabase functions list
# 또는 Supabase Studio Dashboard → Edge Functions
```

### 3.2 마이그레이션 적용

```bash
cd backend
supabase db push        # 로컬 → 원격 적용 (dry-run 후)
supabase db diff        # 로컬 vs 원격 차이 확인
```

### 3.3 iOS 앱

1. `cd ios && xcodegen generate`
2. Xcode에서 `ios/Gyeol.xcodeproj` 열기
3. `GyeolApp` scheme + iPhone Simulator 선택 → Run
4. 실기기 배포 시 Apple Developer Team 설정 및 Sign in with Apple capability 확인

---

## 4. 사용자 흐름 트레이스 (정상 경로)

```
1. Apple Sign In
   iOS AuthService.startAppleSignIn
   → ASAuthorizationController
   → GyeolClient.signInWithApple(idToken, nonce)
   → bootstrap-user Edge Function (auth.users → public.users)
   → AuthService.recordConsent (consents row, PIPA 5항목)
   ✓ logger: GyLog.auth.apple_sign_in.start/ok

2. 6영역 인터뷰
   InterviewViewModel.bootstrap → InterviewService.getOrCreateInterview
   → InterviewIntroScreen (오픈 질문)
   → AnswerInputScreen (키보드 또는 음성)
     - 음성: SpeechService.start (on-device, 1분 우회)
   → submit-answer Edge Function (text_plain → encodeMvpCiphertext)
   → llm-prompt-a 동기 호출 (다음 후속 질문)
   ✓ logger: GyLog.interview.submit_answer.start/ok + Edge follow_up.start/ok

3. 영역 종료
   DomainEndScreen → InterviewService.finalizeDomain
   → finalize-domain Edge Function
   → llm-prompt-b 동기 호출 (분석 + raw_quote 1차 검증)
   → analyses + answer_evidence INSERT (encodeMvpCiphertext)
   → normalization-worker 동기 트리거 (raw_quote 2차 + canonical 매핑)
   ✓ logger: analysis.start/llm.ok/raw_quote_detected/analysis.ok

4. 발행 직전 본인 검토
   SelfReviewScreen → prepare-review Edge Function
   → core_identity 미존재 시 llm-prompt-d 트리거
   → dealbreaker 미정규화 시 llm-prompt-e 트리거
   → InterviewService.loadOwnAnalyses (RLS self)

5. 발행
   InterviewService.publish → publish Edge Function
   → 6영역 finalized + core_identity 검증
   → matching-algorithm 비동기 트리거 (양방향 matches.upsert × N)
   ✓ logger: publish.start/matching_algorithm.trigger/publish.ok + batch.ok (avg_per_pair_ms)

6. 매칭 후보 노출
   MatchListScreen → MatchService.loadInitial + subscribeRealtime
   → request-explanation Edge Function (lazy 큐)
     - explanation-payload-builder (atoms + boundary_check_payload)
     - recommendation-matrix-engine (draft + needs_polish 평가 + 캐시 또는 LLM-C + post-polish-validation)
   → matches.recommendation_status='ready' UPDATE
   → Realtime postgres_changes broadcast → MatchListScreen 갱신
   ✓ logger: matrix.ok / polish.cache_hit·miss / polish.validation

7. [관심 있음] → 대화방
   MatchService.setInterest(matchId, true)
   → matches.viewer_interest='interested' UPDATE
   → trigger sync_pair_interest (search_path 고정, REVOKE EXECUTE)
   → 양방향 시 chat_rooms INSERT + 시스템 메시지
   → ChatService Realtime 자동 갱신
```

---

## 5. 모니터링

### 5.1 라이브 로그 조회

```bash
# Supabase Studio Dashboard → Logs Explorer
# 또는 MCP: get_logs(service: "edge-function" | "postgres" | "auth" | "realtime")
```

JSON 로그 line 검색 query 예시 (Supabase Logs UI):
```
metadata->>level = "error"
metadata->>fn = "recommendation-matrix-engine"
metadata->>match_id = "273658b7"
```

### 5.2 핵심 메트릭 (운영 단계 fitness)

| Fitness | 측정 source | 임계값 |
|---------|-------------|--------|
| `polish.validation valid=false` 비율 | recommendation-matrix-engine logs | < 5% (보강 시 프롬프트 C 또는 evaluator) |
| `raw_quote_detected` 비율 | llm-prompt-b + normalization-worker logs | < 5% (보강 시 프롬프트 B) |
| `batch.ok avg_per_pair_ms` | matching-algorithm logs | p95 < 15ms |
| LLM `llm.ok llm_latency_ms` | llm-prompt-* logs | p95 < 5000ms |
| Realtime `matches.change_received` 빈도 | iOS device logs | 폭주 시 filter 재검토 |

### 5.3 operator_review_queue 처리

운영자 어드민 화면 (Phase 2):
```sql
SELECT issue_type, count(*), max(created_at)
FROM operator_review_queue
WHERE status = 'pending'
GROUP BY issue_type
ORDER BY count(*) DESC;
```

| issue_type | 처리 |
|-----------|------|
| `raw_quote_in_summary` | LLM-B 프롬프트 보강 후 재호출 또는 운영자 수동 paraphrase |
| `unmapped_dealbreaker` | canonical_targets 사전 보강 + 재호출 |
| `polish_validation_failed` | 통계 누적, 5% 초과 시 프롬프트 C 보강 |
| `normalization_failed` | normalization-worker 코드 점검 (axis_positions 매핑 사전) |

---

## 6. 장애 시나리오

### 6.1 Gemini API 장애 / 키 만료

**증상**: `llm.ok` 로그 끊김, `polish.llm_call_failed http_status=401/429/500`

**대응**:
1. Google AI Studio 콘솔 — 키 활성화/quota 확인
2. `GEMINI_API_KEY` rotate: `supabase secrets set GEMINI_API_KEY="..."`
3. 진행 중 사용자: `recommendation-matrix-engine`은 자동 draft 폴백 → 매칭 흐름 부분 회복
4. `llm-prompt-b` 실패 시: `finalize-domain`이 `interviews.status` 자동 롤백 (`in_progress`) → 사용자 재시도 가능

### 6.2 Realtime 끊김 (iOS)

**증상**: 매칭 후보 신규/대화방 자동 갱신 안 됨

**대응**:
1. iOS app 자동 재연결 — Supabase SDK 5초 backoff
2. fallback: 매칭 화면 pull-to-refresh / 대화방 진입 시 manual loadRooms
3. Supabase Studio → Realtime → channel `matches:{userId}` 활성 확인

### 6.3 캐시 무효화 필요

```sql
-- 특정 viewer의 polish 캐시 만료
UPDATE polished_output_cache SET expires_at = now() WHERE viewer_id = '...';

-- 전체 폐기 (프롬프트 C 버전 변경 시)
DELETE FROM polished_output_cache WHERE polish_prompt_version != 'C.v7.1';
```

> 캐시 키에 `polish_prompt_version` 포함이라 `GEMINI_API_KEY`/모델 변경 시는 자동 무효화 안 됨. 모델 ID 변경 → 캐시 수동 폐기 권장.

### 6.4 raw quote 감지율 폭증

**증상**: `operator_review_queue WHERE issue_type='raw_quote_in_summary'` 빈도 폭증

**대응**:
1. 패턴 분석 — 어느 영역(`payload->>'domain_id'`)에서 빈도 높은가?
2. LLM-B 프롬프트 §"자가 검증" 강화 — 해당 영역 예시 추가
3. n-gram 임계값 조정 (`raw-quote.ts` `ngramMinLength` 8 → 10) — 단 보수적으로 (false negative 위험)

### 6.5 매칭 풀 비활성 (사용자 0명)

`needs_review_hidden` 처리는 매칭 풀 충분 (≥10명) 가정. 초기 사용자 < 10명 시 모든 needs_review를 `fallback_shown`으로 표시 (매칭알고리즘 v7 §8.6).

---

## 7. 일상 작업

### 7.1 새 LLM 프롬프트 추가

1. `_shared/prompts.ts` — `SYSTEM_PROMPT_X` + `PROMPT_VERSION.X` 추가
2. `backend/supabase/functions/llm-prompt-x/index.ts` — entry 작성
3. `backend/supabase/config.toml` — `[functions.llm-prompt-x] verify_jwt = true|false`
4. `supabase functions deploy llm-prompt-x`
5. `dependency-map.md` 표 갱신
6. iOS Service에 호출 추가 + `GyLog.interview.trace` 감싸기

### 7.2 새 영역 추가 (예: 7번째 영역)

1. `migrations/0007_new_domain.sql` — `ALTER TYPE domain_id ADD VALUE 'new_domain'`
2. `_shared/types.ts` — DOMAIN_IDS 배열 + DOMAIN_LABELS_KO
3. `migrations/0005_seed_canonical.sql` — 새 영역 principles/targets/axes 시드 추가 마이그레이션
4. iOS `DomainID` enum + `OpenQuestion.all` + `Domain.swift indexNumber`
5. RLS 점검 (analyses/normalized_profiles 영역별 처리 없음 — pass)
6. `prompts.ts` SYSTEM_PROMPT_B에 영역명 추가 (LLM이 인지하도록)
7. 화면 — `DomainID.allCases.count == 7`로 ProgressBar 자동 갱신

### 7.3 사용자 데이터 삭제 (PIPA 21조 삭제권)

```sql
-- soft delete
UPDATE users
SET deleted_at = now(), deletion_purges_at = now() + interval '30 days'
WHERE id = '<user_id>';

-- 30일 후 hard delete (cron job 권장)
DELETE FROM users WHERE deletion_purges_at < now();
-- → cascade: consents, interviews, answers, analyses, evidence, core_identities,
--   explicit_dealbreakers, normalized_profiles, matches, chat_rooms, messages
```

> PIPA 22조 — 동의 철회 시 `consents.revoked_at` 갱신 (감사 로그 보존), service_role 처리만.

---

## 8. 참고 자료

- 시스템설계: `결_시스템설계서_v3.md`
- 매칭 알고리즘: `결_매칭알고리즘_사양_v7.md`
- AI 프롬프트: `결_AI프롬프트_데이터계약_v7.md`
- 핵심 질문체계: `결_핵심질문체계_설계문서_v7.md`
- 화면설계: `결_화면설계서_v2.md`
- 정규화 PRD: `docs/specs/01-prd.md`
- 아키텍처: `docs/specs/02-architecture.md` (ADR 15개)
- 디자인: `docs/specs/03-design-system.md`
- 의존성맵: `docs/backend-dependency-map.md`
