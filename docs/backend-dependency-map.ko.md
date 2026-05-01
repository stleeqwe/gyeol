# 결 (Gyeol) — Backend Dependency Map

> ordiq Stage 5 산출물 (자동 갱신: 2026-05-01 — logger / crypto-scaffold / Logging.swift / 29 tests 반영).
> 권위 source: 시스템설계 v3 + 매칭알고리즘 v7 + AI프롬프트 v7 + 화면설계 v2 + Architecture §5.

---

## 1. Resources

### 1.1 PostgreSQL Tables (17개)

| 테이블 | 마이그레이션 | RLS | 비고 |
|--------|--------------|-----|------|
| users | 0001 | self read/update | apple_sub UNIQUE |
| consents | 0001 | self read/insert | PIPA 23조 별도 동의 |
| interviews | 0001 | self read/write | (user_id, domain) UNIQUE |
| interview_answers | 0001 | self only | text_ciphertext bytea |
| analyses | 0001 | self read + match_visible + chat_partner_visible | structured는 column-level |
| answer_evidence | 0001 | self read only | self_review_only |
| core_identities | 0001 | self read + match_visible + chat_partner_visible | label/interpretation public_safe |
| explicit_dealbreakers | 0001 | self only | raw_user_text_ciphertext |
| canonical_principles / targets / axes | 0002 | **public read** (0006 강화) | 운영자 사전 |
| normalized_profiles | 0002 | service_role only | RLS enabled, no policy |
| matches | 0003 | viewer-self read + candidate-after-chat | trigger sync_pair_interest |
| polished_output_cache | 0003 | service_role only | RLS enabled, no policy |
| chat_rooms | 0003 | participants only | match-id unique |
| chat_messages | 0003 | participants read + insert | sender=auth.uid() check |
| operator_review_queue | 0003 | service_role only | RLS enabled, no policy |

> 0006 보안 강화: canonical_* RLS public_read 정책 추가 + 함수 search_path 고정 + sync_pair_interest REVOKE EXECUTE + pg_trgm extensions 스키마 이동.

### 1.2 Edge Functions (19개 — 13 핵심 + 6 사용자 facade)

| 함수 | 입력 | 출력 | LLM | 호출자 | verify_jwt |
|------|------|------|-----|--------|------------|
| llm-prompt-a | interview_id, domain_id, parent_answer_id | follow_up_question | Gemini 3 Flash | iOS InterviewService.generateFollowUp | ✓ |
| llm-prompt-b | interview_id, domain_id | summary, structured, answer_evidence (insert) | Gemini 3 Flash | finalize-domain | ✓ |
| llm-prompt-c-postedit | draft, viewer_core, candidate_core | polished | Gemini 3.1 Flash-Lite | recommendation-matrix-engine (internal) | ✗ (INTERNAL_CALL_TOKEN) |
| llm-prompt-d | (없음) | core_identity (upsert) | Gemini 3 Flash | iOS InterviewService.generateCoreIdentity | ✓ |
| llm-prompt-e | (없음) | explicit_dealbreakers (update) + operator_review_queue | Gemini 3.1 Flash-Lite | iOS InterviewService.normalizeDealbreakers | ✓ |
| normalization-worker | user_id, domain_id | normalized_profiles (upsert) | (없음) | llm-prompt-b 트리거 | ✗ |
| matching-algorithm | user_id | matches (upsert × N) | (없음) | publish 트리거 | ✗ |
| explanation-payload-builder | match_id | matches.explanation_payload (update) | (없음) | (사전 계산 큐) | ✗ |
| recommendation-matrix-engine | match_id | matches.recommendation_narrative (update) | Gemini 3.1 Flash-Lite (조건부) | (사전 계산 큐) | ✗ |
| post-polish-validation | draft, polished, raw_answers, is_boundary_check | valid + reason | (없음) | matrix-engine inline + 외부 단독 | ✗ |
| raw-quote-detector | text or fields, raw_answers | detected + reason | (없음) | 외부 호출용 단독 | ✗ |
| publish | (없음) | status: publishing | (없음) | iOS InterviewService.publish | ✓ |
| finalize-domain | interview_id, domain_id | summary | (트리거: llm-prompt-b) | iOS InterviewService.finalizeDomain | ✓ |
| **bootstrap-user** | (없음) | users row upsert (Apple JWT sub → public.users) | (없음) | iOS Apple Sign In 직후 | ✓ |
| **submit-answer** | interview_id, domain, seq, text_plain, depth_level, voice_input_seconds | interview_answers row (text_ciphertext = encodeMvpCiphertext) | (없음) | iOS InterviewService.submitAnswer | ✓ |
| **set-domain-status** | interview_id, domain_id, action(skip/private), skip_reason? | interviews status 갱신 + skip/private placeholder analyses 생성 | (없음) | iOS InterviewService.skip/keepPrivate | ✓ |
| **submit-dealbreakers** | domain, raw_texts[] | explicit_dealbreakers insert (raw_user_text_ciphertext) | (없음) | iOS DealbreakerInputScreen | ✓ |
| **prepare-review** | (없음) | core_identity 미존재 시 llm-prompt-d + dealbreaker 미정규화 시 llm-prompt-e 트리거 | 간접 (Gemini 3 Flash + 3.1 Lite) | iOS SelfReviewScreen 진입 시 | ✓ |
| **request-explanation** | match_id? OR limit? | explanation-payload-builder + recommendation-matrix-engine lazy 트리거 | 간접 (Gemini 3.1 Lite) | iOS MatchListScreen 진입 / 카드 펼침 | ✓ |

### 1.3 _shared 라이브러리 (12개 + 2 신설)

| 모듈 | 책임 | LLM 의존 |
|------|------|----------|
| types.ts | DomainId/Stance/Intensity/AlignmentLevel + 분석 schema | X |
| stance-distance.ts | STANCE_DISTANCE 6×6 + isTension/isSharedSacred/isSharedRejection | X |
| raw-quote.ts | detectRawQuoteInSummary (따옴표 + n-gram 8자) | X |
| scoring.ts | computeCompatibilityBasic (1단계, 5-10ms/페어) | X |
| explanation.ts | buildExplanationPayload + buildBoundaryCheckPayload (3단계) | X |
| matrix-engine.ts | assembleDraftNarrative + evaluateDraftQuality (4단계 결정론) | X |
| post-polish-validation.ts | validatePolishOutput 8가지 + buildValidationContext | X |
| cache-key.ts | computePolishCacheKey (viewer-isolated) | X |
| prompts.ts | SYSTEM_PROMPT_A·B·C·D·E + PROMPT_VERSION | X (프롬프트 정의만) |
| supabase.ts | getServiceRoleClient / getUserClient / HttpError / readJson / handleError | X |
| vertex.ts | callGemini / callGeminiJson (Google AI Studio 직접 호출) | ✓ |
| **logger.ts** [신설] | Logger 클래스 + JSON 구조 console 출력 + correlation id | X |
| **crypto-scaffold.ts** [신설] | encodeMvpCiphertext / decodeMvpCiphertext (bytea round trip 평문 fallback) | X |

### 1.4 iOS 모듈 (Services + ViewModels)

| 모듈 | 책임 |
|------|------|
| GyeolClient | Supabase SDK wrapper (Auth/Realtime/Functions) |
| AuthService | Apple Sign In + nonce/SHA256 + consent 기록 |
| SpeechService | SFSpeechRecognizer on-device + 1분 우회 + 60초 무음 종료 |
| InterviewService | submitAnswer/finalizeDomain/skip/keepPrivate/publish/loadOwnAnalyses/loadOwnCoreIdentity |
| MatchService | loadInitial + Realtime channel `matches:{userId}` filter `viewer_id=eq` + setInterest |
| ChatService | loadRooms + Realtime + send (200자 cap) |
| DraftStore | SwiftData AnswerDraft (offline-first) |
| **Logging.swift** [신설] | OSLog Logger 카테고리 7종 (auth/interview/speech/match/chat/realtime/api) + GyLogger.trace stopwatch + UUID.short |

---

## 2. Data Flow Contracts (mutation → DB → push → client → UI)

각 contract: COMPLETE 또는 GAP. Stage 5 게이트 GAP=0 보장 (MVP 범위).

### Contract C1: 답변 저장 → drafts + 서버 동기화

| 단계 | 위치 |
|------|------|
| 1. iOS InterviewViewModel.submitOpenAnswer / submitFollowUpAnswer | ios/Gyeol/ViewModels/InterviewViewModel.swift |
| 2. SwiftData AnswerDraft.upsert (offline-first) | ios/Gyeol/Services/DraftStore.swift |
| 3. InterviewService.submitAnswer → POST interview_answers | ios/Gyeol/Services/InterviewService.swift (GyLog.interview.trace) |
| 4. RLS check (auth.uid() = user_id) | migrations/0004_rls_policies.sql:answers_self_all |
| 5. iOS @Published answers 갱신 → SwiftUI redraw | InterviewViewModel.answers |

**Sync Status: COMPLETE**

### Contract C2: 영역 종료 → 분석 결과 노출

| 단계 | 위치 |
|------|------|
| 1. iOS finalize-domain 호출 | InterviewViewModel.finalizeDomain (GyLog.interview.trace) |
| 2. Edge finalize-domain → llm-prompt-b → analyses + answer_evidence + raw_quote 차단 | functions/finalize-domain + llm-prompt-b (logger: analysis.start/llm.ok/raw_quote_detected/analysis.ok) |
| 3. analyses 업데이트 (Realtime 옵션) | DB |
| 4. 본인 검토 화면 진입 시 InterviewService.loadOwnAnalyses → analyses SELECT (RLS self) | SelfReviewScreen.task |

**Sync Status: COMPLETE**

### Contract C3: 발행 → 매칭 풀 진입 → 후보 노출

| 단계 | 위치 |
|------|------|
| 1. iOS InterviewService.publish | ios/Gyeol/Services/InterviewService.swift |
| 2. Edge publish → 6영역 + core_identity 검증 → matching-algorithm 비동기 트리거 | functions/publish (logger: publish.start/matching_algorithm.trigger/publish.ok) |
| 3. matching-algorithm: 전체 페어 basic 산출 → matches.upsert × N 양방향 | functions/matching-algorithm (logger: batch.start/candidates.loaded/batch.ok with avg_per_pair_ms) |
| 4. 사용자 매칭 화면 진입 시 explanation-payload-builder + recommendation-matrix-engine 호출 (큐) | (큐, MVP에서는 lazy) |
| 5. matches.recommendation_status='ready' update | functions/recommendation-matrix-engine (logger: matrix.ok/polish.cache_hit·miss/polish.validation) |
| 6. **Realtime broadcast**: postgres_changes on matches WHERE viewer_id=auth.uid() | Supabase Realtime publication |
| 7. iOS MatchService.subscribeRealtime → channel "matches:{userId}" | ios/Gyeol/Services/MatchService.swift (GyLog.realtime.matches.subscribe.start/ok/change_received) |
| 8. handleChange → loadInitial() refetch → @Published matches 갱신 → MatchListScreen redraw | MatchService |

**Sync Status: COMPLETE**

### Contract C4: [관심 있음] → 양방향 → 대화방 자동 개설

| 단계 | 위치 |
|------|------|
| 1. iOS MatchService.setInterest(matchId, true) | MatchService (GyLog.match.set_interest) |
| 2. matches.viewer_interest='interested' UPDATE (RLS viewer-self) | matches RLS matches_viewer_interest_update |
| 3. **Trigger sync_pair_interest** (BEFORE UPDATE OF viewer_interest) — search_path = public, pg_temp (0006 보안) + REVOKE EXECUTE | migrations/0004 + 0006 |
|   - 짝 row(reverse direction)의 candidate_interest 동기화 |
|   - 양방향 모두 'interested'면 chat_rooms INSERT + 시스템 메시지 INSERT |
| 4. **Realtime broadcast**: postgres_changes on chat_rooms WHERE user_a_id OR user_b_id = auth.uid() | Realtime |
| 5. iOS ChatService.subscribeRooms → channel "chat_rooms:{userId}" → handleChange → loadRooms refetch | ChatService |
| 6. ChatRoomsScreen 자동 갱신 | ChatRoomsScreen |

**Sync Status: COMPLETE**

### Contract C5: 메시지 송수신

| 단계 | 위치 |
|------|------|
| 1. ChatService.send(roomId, body) → chat_messages INSERT (RLS sender=auth.uid()) | ChatService (GyLog.chat.send_message) |
| 2. **Trigger bump_room_last_message** → chat_rooms.last_message_at UPDATE — search_path 고정 (0006) | migrations/0003 + 0006 |
| 3. **Realtime postgres_changes INSERT** on chat_messages WHERE room_id=eq.{roomId} | Realtime |
| 4. ChatService.openRoom → channel "chat:{roomId}" subscribe → 발신자/수신자 모두 INSERT 수신 | ChatService.openRoom (GyLog.realtime.chat.subscribe.ok / chat.message_received) |
| 5. messages append → ScrollViewReader scrollTo(last.id) | ChatRoomScreen |

**Sync Status: COMPLETE**

### Contract C6: 영역 재시작 → explanation_payload 재계산

| 단계 | 위치 |
|------|------|
| 1. iOS Me 화면 → 영역 재시작 (TODO: MVP 후) | (미구현) |
| 2. interviews.restarted_count++ + status reset | (미구현) |
| 3. matches WHERE viewer_id=user OR candidate_id=user → explanation_payload=NULL | (운영자 트리거) |
| 4. 매칭 화면 재진입 시 explanation-payload-builder 재호출 | (큐) |

**Sync Status: GAP** — MVP-out-of-scope, Phase 2 이연.

---

## 3. Cross-Domain Chains

| Chain | 설명 |
|-------|------|
| 답변 텍스트 변경 | interview_answers → analyses → answer_evidence → normalized_profiles → matches.compatibility_assessment_basic → matches.explanation_payload → matches.recommendation_narrative |
| Apple Sign In 가입 | auth.users → users (Edge Function trigger) → consents (사용자 명시 동의) → interviews 생성 가능 |
| 명시 dealbreaker 추가 | explicit_dealbreakers (raw_user_text_ciphertext) → llm-prompt-e → canonical_target_id mapping → matching-algorithm User Hard 필터 |
| raw quote 감지 | llm-prompt-b (1차 자가 검증) → normalization-worker (2차 n-gram detect) → operator_review_queue (insert) → analyses 차단 / 재호출 |
| 양방향 [관심 있음] | matches.viewer_interest UPDATE → trigger sync_pair_interest → 짝 row UPDATE → chat_rooms INSERT → chat_messages INSERT (시스템) |
| polish 캐시 hit | matches.polish_cache_key (computed via cache-key.ts) → polished_output_cache (viewer-isolated) → recommendation_narrative 직접 사용 |
| ciphertext bytea round trip [신설] | iOS plaintext → Edge POST → encodeMvpCiphertext (\\x...) → bytea column → decodeMvpCiphertext → LLM 입력 |

---

## 4. RLS / Trust Boundary

### 4.1 column-level 접근 차단

| 테이블 | 일반 user 차단 column |
|--------|------------------------|
| analyses | structured_ciphertext (앱 코드는 structured 직접 접근하지 않음, summary만 사용) |
| explicit_dealbreakers | raw_user_text_ciphertext (대신 canonical_target_id, unacceptable_stances만 매칭에 사용) |
| answer_evidence | quote_ciphertext (self만, 다른 사용자에게는 RLS로 차단) |

### 4.2 service_role only

- normalized_profiles (정규화 결과는 매칭 알고리즘 내부에서만 사용)
- polished_output_cache (캐시는 결과만 matches에 복사)
- operator_review_queue (운영자 어드민 도구만)

### 4.3 trust boundary

- iOS app는 Supabase Auth JWT만 보유. 사용자 자기 row 외 절대 접근 불가.
- Edge Function 내부 호출은 INTERNAL_CALL_TOKEN header로 1차 검증.
- service_role key는 Supabase secrets에만, 절대 클라이언트 노출 X.
- sync_pair_interest 함수 REVOKE EXECUTE FROM anon, authenticated, public (0006).

---

## 5. Reactive Sync GAPS

| # | Contract | 상태 | 결정 |
|---|----------|------|------|
| 1 | C6 영역 재시작 → explanation_payload 재계산 | GAP | MVP-out-of-scope, Phase 2로 이연 |

**MVP 범위 GAP 0건.** Phase 2 항목 1건 별도 추적.

---

## 6. Observability (Logging)

### 6.1 Edge Functions structured logger

`_shared/logger.ts`의 `loggerFor(fn, ctx?)` → `Logger` 인스턴스. JSON 한 줄 console 출력 → Supabase Edge Logs 자동 수집.

**환경변수**: `LOG_LEVEL=debug|info|warn|error` (기본 info).

**boundary 패턴**:
- `{action}.start` / `{action}.ok` / `{action}.fail` (or trace stopwatch)
- request_id (12자 짧은 UUID), user_id (필요 시), match_id, domain_id

**로그 라인 예시 (recommendation-matrix-engine)**:
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

`GyLog.{category}` → `GyLogger` (OSLog 기반). 7개 카테고리.

| 카테고리 | subsystem | 호출자 |
|----------|-----------|--------|
| auth | com.gyeol.app | AuthService |
| interview | com.gyeol.app | InterviewService + InterviewViewModel |
| speech | com.gyeol.app | SpeechService (session lifecycle, 1분 우회, silence stop) |
| match | com.gyeol.app | MatchService (load, set_interest) |
| chat | com.gyeol.app | ChatService |
| realtime | com.gyeol.app | MatchService/ChatService Realtime 채널 |
| api | com.gyeol.app | (예약) |

### 6.3 PII 정책 (regulated profile 정합)

| 절대 금지 | 허용 |
|----------|------|
| raw 답변, summary 텍스트, raw_user_text, polished narrative, evidence quote, LLM input/output text | user_id/match_id (8자 short), enum, version, latency_ms, duration_ms, *_chars, *_count |

> 검증: `grep -E "(text_plain\|raw_answer\|summary_where\|interpretation\|quote)" 추가된 로그라인 = 0건` (`.claude/ordiq/reports/ordiq-log-health.json` 참조)

---

## 7. 결정론 단위 테스트 (29 tests, 100% PASS)

`backend/supabase/functions/_shared/test_scoring.ts` — `deno test --allow-net=none`

| 카테고리 | 함수 | 테스트 수 |
|----------|------|-----------|
| crypto-scaffold | encode/decode round trip + plaintext fallback | 2 |
| stance-distance | STANCE_DISTANCE 6×6, isTensionTarget, isSharedSacred, isSharedRejection | 7 |
| raw-quote | 따옴표 패턴, n-gram 8자, paraphrase 통과 | 3 |
| scoring | computeCompatibilityBasic 일치/dealbreaker 충돌 | 2 |
| matrix-engine | evaluateDraftQuality short/long, assembleDraftNarrative alignment/boundary | 4 |
| post-polish-validation | raw quote/평가어/길이/적합 polish | 4 |
| explanation | buildExplanationPayload shared principles/rejection, buildBoundaryCheckPayload explicit/null | 4 |
| cache-key | computeDraftHash 일관성, computePolishCacheKey 방향성 분리, 버전 변경 무효화 | 3 |

---

## 8. Map Health Self-Score

| 차원 | 점수 | 근거 |
|------|------|------|
| Completeness (0.30) | 9 | 17 테이블 + 19 Edge Functions(13 핵심 + 6 facade) + 12+2 lib + 6 contracts 모두 트레이스됨 |
| Accuracy (0.25) | 9 | 코드와 정합. RLS, trigger, channel filter, logger 호출 모두 명시. logger.ts/crypto-scaffold.ts 추가 반영 |
| Reactive Sync (0.25) | 8 | 5 contracts COMPLETE, 1 contract MVP-out-of-scope, 0 unresolved GAP |
| Cross-Domain (0.20) | 9 | 7 chains 명시 (ciphertext bytea round trip 추가) |

**Map Health Score = (9×0.30)+(9×0.25)+(8×0.25)+(9×0.20) = 2.70+2.25+2.00+1.80 = 8.75 → PASS (≥7).**

Hard-fail 차단 — Completeness ≥5, Accuracy ≥4 정합.
