# 결 (Gyeol) — PRD

> 본 문서는 ordiq 파이프라인 Stage 1 산출물. 5개 한국어 스펙(시스템설계 v3, 매칭알고리즘 v7, AI프롬프트 v7, 핵심질문체계 v7, 화면설계 v2)에서 PRD에 해당하는 부분을 추출·정규화. 원문은 `결_*_v*.md`로 보존.

**Scope Dial: HOLD** — 본 앱 정체성은 *어려운 질문을 마주하지만 도망갈 곳도 두는* 매칭 앱. 가벼운 만남 영역으로 확장(EXPAND)도 단순 외모/스펙 매칭으로 축소(REDUCE)도 정체성 훼손. 따라서 HOLD.

**Anti-Mediocrity Finding**: *결혼 매칭 = 외모/스펙/소득 + 카드 스와이프* 라는 패턴은 본 앱 진입 직전까지 한국 시장 전체가 머물러 있던 mediocrity. *가치관·신념·신성·도덕적 거부감*을 매칭 신호로 끌어 올리고, *raw quote는 격리하고 paraphrase만 노출*하며, *어려운 질문 + 도망갈 곳* 두 축을 함께 두는 설계가 본 앱의 차별화 축.

**Idea Quality Score (자체 평가, handoff-ready)**:
- Specificity: 9 (6영역 핵심 질문, stance distance matrix, post-polish validation 등 결정론적 사양까지 정의)
- Differentiation: 9 (가치관 매칭 + 결정론 + LLM 분리 + on-device speech + raw quote 격리)
- Feasibility: 7 (LLM 비용 ~$720/월@10K, MVP 30주, 기술 스택 검증됨)
- User Clarity: 8 (진지한 결혼/장기 연애 후보군, 비-카주얼)

---

## 1. Vision

본 앱은 **결혼 또는 매우 진지한 장기 연애를 목표로 하는 가치관 매칭 iOS 앱**이다.

외모·스펙이 아니라 *당신이 무엇을 믿고 어디서 물러서지 않는지*를 묻는다. 질문은 가볍지 않고, 어떤 질문은 불편하다. 그 불편함 속에서 사람의 *결*이 드러난다.

가벼운 만남이나 친구를 찾는 사용자에게는 부담만 큰 앱 — 진입을 의도적으로 좁힌다.

## 2. 타깃 사용자

- **연령**: 20대 후반~40대 중반
- **결혼관**: 결혼 또는 매우 진지한 장기 연애 의향
- **가치관 자기인식**: 어느 정도 형성. 신념·도덕·가족·생명·일·관계 영역에서 *왜 그렇게 생각하는지* 30분~1시간 들여 답할 수 있는 사람
- **장치**: iPhone (iOS 17+, A9 이상 지원), 한국 거주 (한국어)
- **민감도**: 종교·정치·가족·성·낙태 등 민감 주제에 대해 본인 입장을 *명문화 가능* + *상대 입장과 충돌 가능성을 인지*하는 성숙도

## 3. 핵심 메커닉

### 3.1 6영역 가치관 인터뷰

| 영역 | 질문 예시 |
|------|-----------|
| 신념 체계 | 죽음 이후에 무언가가 있다고 생각하는가? 그 생각이 일상에 어떻게 영향을 주는가? |
| 사회와 개인 | 사회 구조 vs 개인 책임의 비중을 어떻게 보는가? |
| 생명 윤리 | 자기결정권 vs 생명의 도덕적 지위 |
| 가족과 권위 | 부모/자녀와의 관계에서 본인의 결정권을 어디까지 두는가? |
| 일과 삶 | 야망과 시간/관계의 균형 |
| 친밀함 | 신뢰·갈등·솔직함·경계의 우선순위 |

각 영역은 *오픈 질문 1개 + 후속 질문 N개*. 답변은 키보드 또는 *음성 입력*(Apple Speech Framework on-device).

### 3.2 분석 (LLM-A·B·D·E + 정규화)

- **A — 후속 질문 생성** (Gemini 3 Flash, 매 답변마다)
- **B — 영역 분석문 생성** (Gemini 3 Flash, 영역당 1회): summary(public_safe) + structured(internal_only) + answer_evidence(self_review_only)
- **D — 통합 핵심 유형** (Gemini 3 Flash, 사용자당 1회)
- **E — 명시 Dealbreaker 정규화** (Gemini 3.1 Flash-Lite, 사용자당 1회)

**중요한 데이터 비공개 원칙**:
- summary.* / core_identity.* — match_visible, **public_safe** (raw quote 금지)
- structured.* — internal_only (운영자만 service_role)
- answer_evidence — self_review_only (본인만)

### 3.3 매칭 (3단계 결정론)

1. **전체 페어 호환 점수 계산** (배치, 5-10ms/페어): System Hard / User Hard 필터링 + final_score + alignment_level + compatibility_assessment_basic
2. **점수 정렬 + 필터 통과 후보 산출** (사용자 매칭 화면 진입 시)
3. **최종 큐 후보 30명** → explanation_payload + boundary_check_payload + 매트릭스 엔진 + 후편집 (LLM-C 선택적, Gemini 3.1 Flash-Lite) + post-polish-validation 8가지

### 3.4 회피 옵션

본 앱은 *어려운 질문을 마주하지만 도망갈 곳도 두는* 앱이다.

- **더 쉽게 설명해주세요** (depth 단계 낮춤, 최대 3회)
- **이 영역은 건너뛸게요** (사유 4가지 enum, 매칭 상대에게 *사유 노출* 사전 고지)
- **답변은 하되 비공개로 보관** (자기 분석은 진행, 매칭 풀에는 미노출, 노출 사실 사전 고지)

### 3.5 양방향 [관심 있음] → 즉시 대화방

매칭 카드에 *결이 잘 맞음 / 타협 가능 / 경계 확인* 라벨. 양쪽 모두 [관심 있음] 클릭 시 즉시 대화방 개설.

## 4. Scope

### 4.1 IN — MVP

#### 핵심 기능
- Apple Sign In만 지원 (한 명당 하나의 계정)
- 6영역 가치관 인터뷰 (오픈 질문 + 후속 질문)
- 키보드 입력 + **음성 입력 (on-device Speech Framework, ko-KR)**
- 회피 3옵션 + 사전 고지 모달 (PIPA 23조 정합)
- 영역별 분석문 + 통합 핵심 유형 자동 생성
- 본인 검토 화면 (발행 직전, 매칭 상대에게 보일 모습 미리보기)
- 명시 Dealbreaker 입력 + 정규화
- 결정론적 매칭 알고리즘 (basic + explanation_payload 분리)
- stance distance matrix
- shared_rejection_targets
- boundary_check_payload
- 매트릭스 엔진 v3 (ALIGNMENT/TENSION multiplier 등)
- LLM 후편집 + post-polish-validation 8가지
- 매칭 후보 카드 목록 + 카드 펼침
- 양방향 [관심 있음] → 대화방
- 1:1 텍스트 대화 (이미지/파일 없음, 첫 화면)

#### 인프라
- Supabase Seoul (PostgreSQL + Auth + Realtime + Edge Functions Deno)
- Vertex AI Seoul (asia-northeast3) — Gemini 3 Flash + 3.1 Flash-Lite
- iOS 17+, Swift 5.9+, SwiftUI

#### 컴플라이언스
- PIPA 23조 민감정보 처리 동의 (별도 동의)
- 음성 on-device 처리 명시
- raw quote 격리 (answer_evidence 분리, summary는 public_safe)
- 데이터 거주 (한국)
- AI 학습 데이터 사용 금지

#### 운영
- 정규화 레이어 raw quote 감지 + 운영자 검토 큐
- 영역 재시작 (해당 사용자의 explanation_payload 재계산)
- needs_review 처리 분기 (매칭 풀 충분 여부)
- 운영 메트릭: alignment_pattern 분포, 음성 입력 사용률, polish 검증 실패율, raw quote 감지율

### 4.2 OUT — 명시적 제외

- **Android** — 1차 iOS 전용
- **Apple 외 인증** — 진지한 사용자 필터링 목적
- **이미지/사진 업로드** — 본 앱 정체성과 충돌
- **외부 STT API** (Google Cloud, Whisper) — 비용 + 외부 전송 부담
- **광고 / 인앱결제** (1차 무료, 향후 0.5% 사용자 구독으로 흑자 가능)
- **그룹 매칭, 친구 추천** — 본 앱 정체성 외
- **위치 기반 매칭 / 거리 표시** — 1차 제외 (가치관 우선)
- **detailed answer_evidence를 매칭 상대에게 노출하는 옵션** — 항상 self_review_only
- **사용자 임의의 자유 양식 dealbreaker** — enum + paraphrase로 정규화

### 4.3 [auto-enriched] — Production 표준 누락 채움

기존 스펙에 명시되어 있지만 향후 누락 가능성 높은 항목 — auto-enrich 태그.

- 회원 탈퇴 + 데이터 완전 삭제 (PIPA)
- 영역별 데이터 삭제 (회피 3옵션 외)
- 세션 만료 + 재로그인 흐름
- 푸시 알림 권한 + on/off (대화방 신규 메시지, 매칭 신규)
- 차단 + 신고 (대화방 / 후보 카드)
- 약관 / 개인정보 처리방침 동의 (음성 데이터 처리 명시)
- 앱 잠금 (FaceID/passcode) — 민감 데이터 보호 옵션
- 백그라운드/포그라운드 전환 시 인터뷰 답변 자동 저장 (drafts)
- 네트워크 오프라인 시 답변 작성 가능 + 복구
- 비공개 영역 미리보기 + 변경

### 4.4 [user-enriched] — 본 사이클 처리 보류

다음 단계에서 사용자와 별도 협의 후 추가:

- 매칭 화면 새로고침 빈도 / 디바운스 정책
- 1주일 / 1개월 비활성 시 매칭 풀 휴면 처리 정책
- 운영자 어드민 화면 (operator_review_queue 처리)
- 아이콘/스플래시 / 앱 스토어 메타데이터

## 5. 비기능 요구사항

| 영역 | 요구 |
|------|------|
| 성능 | 자기 분석 1회 합계 ≤ 30초 LLM 대기. 매칭 화면 진입 → 후보 노출 ≤ 2초. 대화방 메시지 송수신 ≤ 500ms. |
| 비용 | 10K 사용자 안정기 ≤ $720/월 |
| 가용성 | 99.5% (Supabase Seoul + Vertex AI Seoul SLA 합산) |
| 보안 | PIPA 정합. 모든 raw 답변 저장·전송 시 암호화. RLS로 사용자 격리. service_role만 structured 접근. |
| 데이터 거주 | 한국 (Supabase ap-northeast-2 + Vertex AI asia-northeast3) |
| 접근성 | 한국어, VoiceOver 지원, Dynamic Type 지원, 다크 모드 지원 |

## 6. 출시 단계

- **MVP** (~30주): 위 IN 전체 + 핵심 운영 메트릭
- **Phase 2** (~6주): operator 어드민, 비활성 휴면 처리, 푸시 분기
- **Phase 3** (~12주): Android, 부분 유료화 검토, 다국어 (영어)

## 7. 리스크

| 리스크 | 완화 |
|--------|------|
| LLM 출력의 raw quote 누출 | 3중 방어선: 프롬프트 B 자가 검증 + 정규화 레이어 n-gram detect + 매트릭스 엔진 detect |
| 후편집 LLM이 본 앱 톤 훼손 | post-polish-validation 8가지 검사. 실패 시 draft 폴백 + 캐시 미저장 |
| 6영역 = 답변 부담 → 이탈 | 회피 3옵션 + 분할 저장 + 음성 입력 |
| 매칭 풀 적은 시점 needs_review 부적절 노출 | §8.6 매칭 풀 충분 여부 분기 (≥10명 시 hidden, 미만 시 fallback_shown) |
| Apple Speech 1분 제한 | 50초 시점 자동 세션 재시작, 사용자에겐 연속 녹음으로 보임 |
| 가치관 영역 = 정치적 양극화 → 운영자에 부담 | 결정론적 매칭 + 운영자는 needs_review·raw quote 케이스만 처리 |

## 8. 출처 매핑

| 본 PRD 절 | 원본 스펙 |
|-----------|-----------|
| §1 Vision | 핵심질문체계 v7 §1, 화면설계 v2 화면 1 |
| §2 타깃 | 시스템설계 v3 §1, 핵심질문체계 v7 §1 |
| §3.1 6영역 | 핵심질문체계 v7 §2-§9 |
| §3.2 LLM | AI프롬프트 v7 §1.2, §2 |
| §3.3 매칭 | 매칭알고리즘 v7 §1.2, §4 |
| §3.4 회피 | 핵심질문체계 v7 §11 |
| §3.5 [관심 있음] | 시스템설계 v3 §2.2 |
| §4 Scope | 시스템설계 v3 §11 + 본 정규화 |
| §5 비기능 | 시스템설계 v3 §4.3, §7, §9 |
| §6 단계 | 시스템설계 v3 §11 |
