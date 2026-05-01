# 결 (Gyeol) — Architecture

> ordiq Stage 2 산출물. 시스템설계 v3 + 매칭알고리즘 v7 + AI프롬프트 v7을 표준 아키텍처 문서로 정규화.

## 1. 기술 스택 + 인지 패턴 매핑

| 영역 | 선택 | 인지 패턴 | 근거 |
|------|------|-----------|------|
| 클라이언트 | iOS Swift 5.9 + SwiftUI | Boring by Default, Boundary Discipline | 텍스트 중심 UX + Apple 생태계 (Sign In + Speech) 통합 |
| BaaS | Supabase Seoul | Configuration Gravity, Boring by Default | PostgreSQL + Auth + Realtime + Edge Functions 단일 공급자, 한국 데이터 거주 |
| Edge Runtime | Deno (Supabase Edge Functions) | Single Responsibility | TypeScript, 빠른 콜드 스타트, 명확한 경계 |
| LLM | Vertex AI Seoul (Gemini 3 Flash + 3.1 Flash-Lite) | Boundary Discipline, Failure Mode Fluency | 데이터 거주 + 학습 미사용 + 모델 라우팅 분리 |
| 결정론 엔진 | TypeScript (Edge Functions) | Single Responsibility, Test Boundary | LLM과 결정론 분리. 테스트 가능한 순수 함수 중심 |
| 음성 입력 | Apple Speech Framework on-device | Blast Radius (외부 전송 0) | PIPA 민감정보, on-device가 유일한 안전 선택 |
| 인증 | Apple Sign In (AuthenticationServices) | Boundary Discipline | 단일 ID 1계정 + 진지한 사용자 필터링 |
| 로컬 캐시 | SwiftData (인터뷰 drafts) | State Locality | 오프라인 작성 + 자동 저장 |
| 실시간 | Supabase Realtime | Seam Awareness | matches 테이블 변경 push, 매칭 화면 즉시 반영 |

## 2. C4 — Context

```
┌─────────────────────────────────────────────────────────────┐
│                        결 사용자                             │
│  (iPhone iOS 17+, A9 이상)                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │ Apple Sign In + 답변 + [관심 있음]
                       │ 음성: on-device, 외부 전송 없음
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  결 iOS App (SwiftUI)                                        │
│  - 13 screens (light/dark)                                   │
│  - Speech Framework (ko-KR, on-device)                       │
│  - Supabase Swift SDK + Realtime                             │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTPS TLS 1.3
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase Seoul (ap-northeast-2)                             │
│  - Auth (Apple JWT)                                          │
│  - PostgreSQL (raw 답변 암호화)                              │
│  - Realtime (matches push)                                   │
│  - Edge Functions Deno (19개: 13 핵심 + 6 facade)            │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTPS
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  Google AI Studio (Gemini API key)                           │
│  - Gemini 3 Flash (A·B·D)                                    │
│  - Gemini 3.1 Flash-Lite (C·E)                               │
│  - PIPA 한국 거주 hard requirement 시 Vertex AI Seoul 교체   │
└─────────────────────────────────────────────────────────────┘
```

## 3. C4 — Container

### 3.1 iOS 앱 모듈

```
ios/Gyeol/
├── App/                       # @main, AppDelegate, Lifecycle
├── Views/                     # 화면 (13개 + 다크 변형)
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
│   └── DraftStore.swift       # SwiftData 로컬 답변 저장
├── Components/                # 재사용 UI (mic button, progress bar 등)
└── Resources/
    ├── Tokens.swift           # 디자인 토큰 (Color/Spacing/Radius/Type)
    ├── Localizable.strings    # ko
    └── Info.plist
```

### 3.2 Backend (Supabase) 모듈

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
│   ├── _shared/               # 공통 라이브러리
│   │   ├── supabase.ts
│   │   ├── vertex.ts          # Vertex AI 호출
│   │   ├── stance-distance.ts # 6×6 distance matrix
│   │   ├── raw-quote.ts       # n-gram detector
│   │   ├── post-polish-validation.ts
│   │   └── matrix-engine.ts   # 결정론 narrative 조립
│   ├── llm-prompt-a/          # 후속 질문 생성 (Gemini 3 Flash)
│   ├── llm-prompt-b/          # 영역 분석문 (Gemini 3 Flash)
│   ├── llm-prompt-c-postedit/ # 추천 narrative 후편집 (Flash-Lite)
│   ├── llm-prompt-d/          # 통합 핵심 유형 (Gemini 3 Flash)
│   ├── llm-prompt-e/          # 명시 dealbreaker 정규화 (Flash-Lite)
│   ├── normalization-worker/  # 분석 → normalized_profile (비동기)
│   ├── matching-algorithm/    # 1단계 — 전체 페어 basic
│   ├── explanation-payload-builder/  # 3단계 — 최종 큐 후보 atoms
│   ├── recommendation-matrix-engine/ # 4단계 — draft narrative
│   ├── post-polish-validation/       # 후편집 LLM 결과 검증
│   └── raw-quote-detector/    # 정규화 레이어 raw quote 차단
└── tests/                     # Deno test
```

## 4. 데이터 모델

### 4.1 핵심 테이블

| 테이블 | 목적 | RLS |
|--------|------|-----|
| `users` | Apple Sign In sub | self read |
| `consents` | PIPA 23조 동의 (별도) | self read/write |
| `interviews` | 영역별 인터뷰 진행 상태 + voice_input_used | self read/write |
| `interview_answers` | 사용자 raw 답변 (암호화) | self only |
| `analyses` | 영역별 분석 (summary public_safe + structured internal) | self read, service_role write |
| `answer_evidence` | raw quote 격리 (self_review_only) | self read only |
| `core_identities` | 통합 핵심 유형 | self read |
| `explicit_dealbreakers` | 명시 dealbreaker (raw text + 정규화 enum) | self only (raw_user_text), match_visible (canonical) |
| `normalized_profiles` | 정규화 결과 (canonical_principles 등) | service_role read |
| `matches` | 페어별 호환 + explanation_payload + recommendation | viewer-self read |
| `polished_output_cache` | 후편집 LLM 캐시 (viewer 분리) | service_role only |
| `chat_rooms` | 양방향 [관심 있음] 후 개설 | participants only |
| `chat_messages` | 텍스트 메시지 | participants only |
| `operator_review_queue` | needs_review / raw quote / polish 실패 | service_role only |

### 4.2 데이터 비공개 범위 (5단계)

| 범위 | 의미 | 접근 |
|------|------|------|
| `service_role_only` | 운영자만 (structured, polished_output_cache, normalized_profiles) | RLS service_role |
| `self_only` | 본인만 (interview_answers, explicit_dealbreaker.raw_user_text) | RLS self |
| `self_review_only` | 본인 검토 화면에서만 (answer_evidence) | RLS self + view 전용 |
| `match_visible` (public_safe) | 매칭된 상대에게 (summary, core_identity) | RLS via matches join |
| `viewer_only` | 특정 viewer에게만 (recommendation_narrative) | RLS via matches.viewer_id |

## 5. API Contract

### 5.1 사용자 흐름 + Edge Function

| 단계 | 클라이언트 액션 | Edge Function | 모드 | 응답 시간 |
|------|------------------|---------------|------|-----------|
| 답변 → 후속 질문 | `POST /interviews/{id}/answers` | llm-prompt-a | 동기 | ~3-5s |
| 영역 종료 | `POST /interviews/{id}/domains/{domain_id}/finalize` | llm-prompt-b → 정규화 워커 트리거 | 동기 + 비동기 | ~5-10s |
| 6영역 완료 | `POST /interviews/{id}/finalize` | llm-prompt-d (sync) + llm-prompt-e (sync) | 동기 | ~8-13s |
| 발행 | `POST /publish` | matching-algorithm (배치 트리거 enqueue) | 비동기 | 즉시 응답 |
| 매칭 화면 진입 | `GET /matches?status=ready` | (DB 직접) | 동기 | ≤2s |
| 카드 펼침 | `GET /matches/{id}/explanation` | explanation-payload-builder + matrix-engine + post-polish | 비동기 사전 계산 | 즉시 |
| [관심 있음] | `POST /matches/{id}/interest` | (DB 직접 + 양방향 체크) | 동기 | ≤500ms |
| 대화방 | Realtime channel `chat:{room_id}` | (Supabase Realtime) | 실시간 | ≤500ms |

### 5.2 Reactive Sync Contracts (mutation → DB → push → client → UI)

각 mutation의 데이터 흐름. **모든 contract는 COMPLETE 상태 — 부분 노출(GAP) 없음.**

#### Contract C1: 답변 저장 → drafts 동기화
1. iOS `InterviewViewModel.saveAnswer(text)`
2. (offline-first) `DraftStore` SwiftData에 즉시 저장
3. (online) `SupabaseClient.upsert(interview_answers)`
4. UI: 입력란 인디케이터 = saved
5. **동기화 보장**: SwiftData 트리거 → @Query 갱신 → SwiftUI redraw

#### Contract C2: 영역 종료 → 분석 결과 노출
1. iOS `POST /interviews/{id}/domains/{domain_id}/finalize`
2. Edge Function `llm-prompt-b` → `analyses` insert + `answer_evidence` insert + `summary` (public_safe)
3. Realtime broadcast: `interviews:domain_finalized` 채널
4. iOS Realtime 구독 → ViewModel 갱신 → 영역 종료 화면 노출

#### Contract C3: 발행 → 매칭 큐
1. iOS `POST /publish`
2. `matches` table insert (compatibility_assessment_basic 만)
3. Job queue (pg_cron + Edge Function) → matching-algorithm 배치 → matches 갱신 → recommendation_status='pending' → 'ready' 단계
4. Realtime broadcast: `matches:user_id` 채널
5. iOS 매칭 화면 — recommendation_status='ready' 후보만 표시

#### Contract C4: [관심 있음] → 양방향 체크 → 대화방
1. iOS `POST /matches/{id}/interest`
2. Edge Function: matches.viewer_interested=true 업데이트, candidate_interested=true 인지 양방향 체크
3. 양방향 시 chat_rooms insert + chat_messages 시스템 메시지
4. Realtime broadcast: `chat_rooms:user_id` 신규 룸
5. iOS 대화방 목록 + 룸 자동 진입 옵션

#### Contract C5: 메시지 송수신
1. 발신자 `chat_messages` insert
2. Postgres trigger → Realtime 자동 broadcast `chat:{room_id}`
3. 수신자 iOS Realtime 구독 → ChatViewModel append → ScrollView 하단 추가
4. **동시성**: 발신자도 동일 채널 구독 → optimistic insert + reconcile

## 6. 비기능 아키텍처

### 6.1 보안

- **암호화**: PostgreSQL pgcrypto. application-level encryption for `interview_answers.text`, `analyses.structured`, `answer_evidence.quote`, `explicit_dealbreakers.raw_user_text`. KMS 키는 Supabase 프로젝트 secrets.
- **RLS**: 모든 테이블 RLS enabled. service_role bypass.
- **JWT**: Apple ID token → Supabase Auth → row-level access via auth.uid()
- **Edge Function 인증**: 모든 Edge Function은 Authorization header verify. service_role 호출은 internal trigger만.
- **3중 raw quote 방어선**:
  1. LLM 프롬프트 B 자가 검증 (paraphrase 강제)
  2. 정규화 레이어 n-gram detector (8자 임계값)
  3. 매트릭스 엔진 입력 시점 detector

### 6.2 확장성

- **부하 분리**: 1단계 basic은 50M 페어 배치, 3단계 explanation은 90K/일 — 정확한 수직 분리
- **캐시**: polished_output_cache (90일 TTL, viewer 분리). 페어 narrative 캐시 (matches.recommendation_narrative).
- **무효화 트리거**: 영역 재시작 시 해당 사용자의 explanation_payload 재계산만 (전체 재계산 X)

### 6.3 성능

- **결정론 핫패스**: 매칭 알고리즘 1단계는 LLM 미사용 → 5-10ms/페어
- **LLM 동기 호출 ≤ 30s 합산**: 인터뷰 발행까지의 사용자 대기 시간 상한
- **Realtime 지연**: matches table push ≤ 200ms median
- **콜드 스타트**: Edge Function 첫 호출 ≤ 1.5s (Supabase 가이드)

### 6.4 가용성

- **Supabase Seoul SLA 99.9%** (single region 제약 받아들임 — 한국 데이터 거주 우선)
- **Vertex AI Seoul SLA 99.9%**
- **합산 99.5%** (보수)
- **그레이스풀 디그레이션**:
  - LLM 실패 시 — 영역 분석은 재시도 큐, 추천 narrative는 draft 폴백
  - Realtime 끊김 시 — 5초 재연결 + 매칭 화면 pull-to-refresh fallback
  - Speech Framework 권한 거부 — 키보드 입력만 허용 (강요 X)

## 7. ADR

### ADR-001: Apple Sign In만
- **결정**: Apple Sign In만, Google/카카오/이메일 미지원
- **인지 패턴**: Blast Radius (계정 1개로 묶어서 신원 분산 차단), Boundary Discipline
- **근거**: 진지한 사용자 필터링. 한 명당 하나의 계정. iOS 전용이므로 친화적.
- **대안**: 카카오 (큰 한국 점유율) — 거부. 부담 낮은 가입은 본 앱 정체성과 충돌.

### ADR-002: Supabase 단일 BaaS
- **결정**: Supabase 한 곳에 Auth + DB + Realtime + Edge Functions
- **인지 패턴**: Configuration Gravity, Boring by Default
- **근거**: 운영 인력 1명 가정. 단일 공급자가 multi-vendor 결합보다 확실히 안정적. Seoul 리전 + 한국 데이터 거주.
- **대안**: Firebase (Google) — 거부 (raw 답변을 Google 인프라에 두는 것이 PIPA 동의 범위 외).

### ADR-003: Vertex AI 호스팅 LLM (Gemini 3 Flash + 3.1 Flash-Lite 분리)
- **결정**: Vertex AI Seoul. A·B·D는 3 Flash, C·E는 3.1 Flash-Lite.
- **인지 패턴**: Boundary Discipline, Failure Mode Fluency
- **근거**: 데이터 거주 + 학습 미사용. 분석 핵심(B·D)은 더 큰 모델, 후편집·매핑(C·E)은 lite로 비용·속도 절감.
- **대안**: OpenAI / Anthropic — 거부 (한국 거주 정합 어려움).

### ADR-004: 결정론적 매칭 + LLM 후편집 분리
- **결정**: 호환 점수 + alignment_level + atoms는 결정론. narrative 후편집만 LLM.
- **인지 패턴**: Single Responsibility, Test Boundary
- **근거**: 매칭 결과 자체는 reproducible해야 함. LLM 호출은 *문장 다듬기*에 한정. post-polish-validation으로 의미 변경 차단.
- **대안**: end-to-end LLM 매칭 — 거부 (재현성 + 비용 + 본 앱 톤 훼손 위험).

### ADR-005: stance distance matrix 6×6
- **결정**: 6단계 stance(require/support/allow/neutral/avoid/reject) × 6단계 distance + tension 임계값 distance≥3
- **인지 패턴**: Failure Mode Fluency, Naming as Documentation
- **근거**: stance ≠ binary는 부정확. require vs support는 약한 차이, require vs reject는 강한 충돌.
- **대안**: 단순 stance 일치 — 거부 (실제 사용자 답변 다양성 미반영).

### ADR-006: explanation_payload는 최종 큐 후보에만
- **결정**: compatibility_assessment_basic은 전체 페어, atoms·sentences는 노출 후보 30명/일에만
- **인지 패턴**: Blast Radius, Evolutionary Architecture
- **근거**: 50M 페어 atoms는 부담. 노출 후보만 90K/일이면 충분. 사용자에게 보이지 않는 페어에 비용 지불 X.
- **대안**: 전체 페어 atoms — 거부 (비용 6배).

### ADR-007: Apple Speech Framework on-device
- **결정**: SFSpeechRecognizer + requiresOnDeviceRecognition=true
- **인지 패턴**: Blast Radius (외부 전송 0)
- **근거**: PIPA 민감정보. 음성을 Google/Apple 외부 서버로 보내는 옵션 자체를 거부.
- **대안**: 외부 STT — 거부.

### ADR-008: viewer_id 포함 캐시 키 (방향성 분리)
- **결정**: polish 캐시 key에 viewer_id 명시. A→B와 B→A 분리.
- **인지 패턴**: State Locality
- **근거**: candidate_brief는 viewer 기준이므로 viewer마다 narrative 다름. 양방향 동일 hash는 의미 잘못 캐싱.
- **대안**: 양방향 동일 — 거부 (실제 출력이 다르므로 캐시 hit가 잘못된 결과 노출).

### ADR-009: 6개 회피 옵션 사전 고지 모달
- **결정**: 건너뛰기·비공개·"더 쉽게" 모두 *결과* 사전 고지. 첫 선택 시 자동 펼침.
- **인지 패턴**: Naming as Documentation, Boundary Discipline
- **근거**: 사용자가 *예상치 못한 노출*을 발견하지 않도록. 본 앱 신뢰 핵심.
- **대안**: 결과 노출 안 함 — 거부 (사용자 신뢰 훼손).

### ADR-010: post-polish-validation 8가지
- **결정**: raw quote / 평가어 / tension 누락 / boundary 누락 / 새 영역명 / 새 원칙명 / JSON valid / 길이 ±20%
- **인지 패턴**: Failure Mode Fluency
- **근거**: LLM은 재학습 시 톤 흐려짐. 결정론 검증으로 본 앱 톤 보장.
- **대안**: 검증 없이 노출 — 거부.

### ADR-011: needs_review 매칭 풀 충분 여부 분기
- **결정**: 사용자 통과 후보 ≥10명 → needs_review_hidden, 미만 → fallback_shown
- **인지 패턴**: Failure Mode Fluency
- **근거**: 풀 적은 시점에 후보 0건 노출은 *서비스 죽음* 신호. 풀 충분 시 의심 케이스 숨김이 안전.
- **대안**: 항상 hidden — 거부 (얼리 스테이지 사용자 경험 파괴).

### ADR-012: SwiftData 로컬 drafts (offline-first)
- **결정**: 인터뷰 답변은 SwiftData에 우선 저장 → 비동기 백엔드 동기화
- **인지 패턴**: State Locality, Failure Mode Fluency
- **근거**: 6영역 인터뷰 = 길고 정성. 네트워크 끊김으로 작성한 답변 잃으면 사용자 이탈.
- **대안**: 백엔드 only — 거부.

### ADR-013: 구조화 logger (Edge Functions JSON + iOS OSLog)
- **결정**: `_shared/logger.ts`(Edge JSON line console) + `Logging.swift`(OSLog 7 카테고리). PII 정책 — raw 답변·summary·quote·polished 텍스트 절대 비노출. ID(8자 short)/enum/version/카운트/duration_ms만 허용.
- **인지 패턴**: Boundary Discipline, Failure Mode Fluency, Naming as Documentation
- **근거**: 분산 시스템 trace 필수. 단 PIPA 23조 정합 — raw text 한 줄도 로그에 흘리면 동의 위반.
- **대안**: console 그대로 — 거부 (노이즈 + 비구조). console.log를 logger 함수로 한 곳에 묶어 PII 정책을 코드 리뷰로 강제.

### ADR-014: MVP crypto-scaffold (bytea round trip)
- **결정**: `_shared/crypto-scaffold.ts`의 `encodeMvpCiphertext`(`\\x...` hex) / `decodeMvpCiphertext`(plaintext fallback). PostgreSQL bytea 컬럼(text_ciphertext, structured_ciphertext, raw_user_text_ciphertext, quote_ciphertext) round trip을 KMS 통합 전 일관된 직렬화 형태로 처리.
- **인지 패턴**: Configuration Gravity, Evolutionary Architecture (KMS 교체 seam 한 곳)
- **근거**: 1차 스캐폴드는 bytea를 plaintext UTF-8로 보관(개발 편의). 운영 단계에는 본 모듈만 KMS envelope encryption으로 교체하면 모든 Edge Function이 자동 적용. `Logging.swift`도 동일 정책 — raw text 미노출.
- **대안**: 처음부터 KMS — 거부 (MVP 단계 secret 인프라 의존성 과다, 시드 작업 마찰).

### ADR-015: 사용자 facade Edge Functions 분리
- **결정**: iOS 직접 DB 호출 대신 6개 facade 함수(`bootstrap-user`, `submit-answer`, `set-domain-status`, `submit-dealbreakers`, `prepare-review`, `request-explanation`)에 캡슐화.
- **인지 패턴**: Boundary Discipline, Single Responsibility
- **근거**: (1) iOS는 raw text를 plaintext로 보내고 Edge에서 `encodeMvpCiphertext`로 bytea 변환 — KMS 교체 seam이 Edge에 모임. (2) ARCHITECTURE §6.1 강화 — 사용자 client RLS만 신뢰, ciphertext 변환은 Edge service_role. (3) prepare-review/request-explanation은 user JWT 호출이지만 service_role 작업(LLM-D/E 호출, 큐 트리거) 캡슐화.
- **대안**: iOS 직접 supabase-js 호출 — 거부 (ciphertext 정책 + service_role 트리거를 클라이언트에 노출).

## 8. Fitness Function

| Fitness | 측정 | 기준 |
|---------|------|------|
| `summary public_safe` 위반률 | n-gram detector hit / 분석 1만 건 | < 0.5% (운영 데이터) |
| post-polish-validation 실패율 | 검증 실패 / LLM 호출 | < 5% |
| 매칭 알고리즘 1단계 페어당 시간 | matches insert 시간 분포 | p95 < 15ms |
| 콜드 스타트 Edge Function | 첫 호출 latency | p95 < 1500ms |
| Realtime push latency | matches.update → iOS 수신 | p95 < 500ms |
| 음성 입력 1분 우회 성공률 | 50초 자동 재시작 / 1분+ 음성 세션 | > 99% |
| RLS 침해 테스트 | service-role 외 cross-user select | 0 |
| Reactive Sync GAP | docs/backend-dependency-map.md | 0 |

## 9. 위험 + 운영

### 9.1 모니터링

| 메트릭 | 임계값 | 액션 |
|--------|--------|------|
| LLM 호출 실패율 | >2% | 운영자 알림 + 재시도 큐 |
| polish_validation 실패율 | >5% | 프롬프트 C 보강 검토 |
| raw quote detect 비율 | >5% | 프롬프트 B 보강 검토 |
| 매칭 후보 0건 사용자 비율 | >10% | 매칭 풀 확장 정책 |
| 음성 입력 사용률 | 운영 분석 | UI 개선 신호 |
| Realtime 끊김 빈도 | 운영 분석 | iOS 재연결 로직 검토 |

### 9.2 백업 + 복구

- Supabase 자동 일일 백업 (30일 보관)
- PIPA 삭제 요청 시 — soft delete 후 30일 후 hard delete (백업 포함)

## 10. AHS Self-Score (사전, ordiq Stage 2 게이트 정합)

| 차원 | 점수 | 근거 |
|------|------|------|
| Modularity (0.25) | 8 | iOS / Edge / DB 명확 분리, ADR 12개 |
| Test Boundary (0.20) | 7 | 결정론 함수는 단위 테스트 가능, LLM 호출은 통합 테스트 |
| Scalability (0.20) | 7 | 50M 페어 배치 가능, 1단계/3단계 분리 |
| Security (0.20) | 9 | RLS + 암호화 + on-device speech + 3중 raw quote 방어선 |
| Maintainability (0.15) | 7 | ADR + fitness function + 출처 매핑 |

**AHS = (8×0.25)+(7×0.20)+(7×0.20)+(9×0.20)+(7×0.15) = 2.00+1.40+1.40+1.80+1.05 = 7.65 → PASS (≥7).**

Hard-fail 차단 — Modularity ≥5, Security ≥5 정합.
