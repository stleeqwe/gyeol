# 결 (Gyeol) — Design System

> ordiq Stage 3 산출물. 17개 스크린샷에서 토큰 추출 + 화면설계 v2 §15 시각 토큰 정합.

**Domain Design Profile: Consumer (intimate / serious)**

본 앱은 SaaS도 아니고 portfolio도 아니다. 한국 시장의 *진지한 결혼/장기 연애* 사용자가 30분~1시간 들여 어려운 답을 적는 동안 *침착하고 묵직한 동반자* 같이 보여야 한다. 카주얼 데이팅 앱 톤(밝은 그라디언트, 칩, 풍부한 일러스트)은 본 앱 정체성과 충돌.

## 1. First Impression (Phase 1 anchor)

스크린샷 17장의 첫 인상:
- **묵직함**. 베이지 배경 + 검정 primary + serif 한글 = "오래된 신뢰감".
- **여백**. 화면당 정보가 적음. 한 가지 질문만 보여줌.
- **명조계열 헤드라인 + 산세리프 본문**. "결" 1자 = 인장 같음.
- **경어체 + 짧은 문장**. *"답변이 끝났습니다", "결을 통해 연결되었습니다"*.

본 인상이 Critic 비교 anchor — 시안에서 *생기 / 활기 / 다채로움*으로 끌려가지 않게.

## 2. 3-Layer Synthesis

| 레이어 | 결정 |
|--------|------|
| Table Stakes | iOS HIG 준수 (safe area, dynamic type, dark mode), Apple Sign In 검정 버튼 권장 형태, FaceID 옵션, VoiceOver |
| Trending | 미니멀 한국 IT 앱(Toss·Karrot 일부) 영향. 단 *밝은 색 카드 그라디언트*는 거부 — 본 앱 톤과 충돌 |
| First Principles | "어려운 질문 + 도망갈 곳" 정체성. 침착한 톤. 사용자 답변 = 주인공. UI는 배경 |

## 3. Color Palette

### 3.1 Light

| 토큰 | Hex | 역할 |
|------|-----|------|
| `bg.primary` | `#F0EAE0` | 앱 배경 (베이지) |
| `bg.elevated` | `#FFFFFF` | 카드 / 모달 |
| `bg.subtle` | `#E8E2D7` | 입력 영역 disabled / 마이크 비활성 |
| `text.primary` | `#1A1A1A` | 본문, 헤드라인 |
| `text.secondary` | `#6B6760` | 부가 설명, placeholder |
| `text.tertiary` | `#9C9890` | 메타 (1/6 카운터) |
| `text.disabled` | `#C5C0B5` | 비활성 텍스트 |
| `accent.primary` | `#1A1A1A` | CTA 검정 |
| `accent.contrast` | `#FFFFFF` | CTA 위 글자 |
| `divider` | `#D8D2C5` | 구분선 |
| `border.subtle` | `#D8D2C5` | 카드 border |
| `feedback.recording` | `#C44545` | 빨간 점 (녹음 중) |
| `state.alignment` | `#1A1A1A` | "결이 잘 맞음" 도트 |
| `state.compromise` | `#6B6760` | "타협 가능" 도트 |
| `state.boundary` | `#A05A2C` | "경계 확인" 도트 |

### 3.2 Dark

| 토큰 | Hex | 역할 |
|------|-----|------|
| `bg.primary` | `#1A1A1A` | 앱 배경 |
| `bg.elevated` | `#262626` | 카드 / 모달 |
| `bg.subtle` | `#2F2F2F` | 입력 비활성 |
| `text.primary` | `#F0EAE0` | 본문 |
| `text.secondary` | `#A8A39A` | 부가 |
| `text.tertiary` | `#7A766F` | 메타 |
| `text.disabled` | `#5A5650` | 비활성 |
| `accent.primary` | `#F0EAE0` | CTA 베이지 (역전) |
| `accent.contrast` | `#1A1A1A` | CTA 위 글자 |
| `divider` | `#3A3A3A` | 구분선 |
| `border.subtle` | `#3A3A3A` | 카드 border |
| `feedback.recording` | `#E06060` | 빨간 점 |

## 4. Typography

### 4.1 Font Families

- **헤드라인 / 인장**: Apple SD Gothic Neo Heavy (한글) — 시스템 한글 명조 톤. *Serif* 인상이 본 앱과 정합.
- **본문 / UI**: SF Pro Text (Latin) + Apple SD Gothic Neo Regular/Medium/SemiBold (한글)
- **숫자 / 시간**: SF Mono — 녹음 시간 표시 등

### 4.2 Type Scale

| 토큰 | Size / LineHeight / Weight | 용도 |
|------|---------------------------|------|
| `display.brand` | 80 / 96 / Heavy | "결" 인장 |
| `display.subBrand` | 11 / 14 / Medium / 0.3em letter-spacing | "GYEOL" 부 라벨 |
| `headline.lg` | 22 / 32 / SemiBold | 영역 질문 헤드 ("당신은 죽음 이후에…") |
| `headline.md` | 18 / 26 / SemiBold | 카드 메인 |
| `headline.sm` | 16 / 24 / SemiBold | 모달 타이틀 |
| `body.lg` | 15 / 24 / Regular | 본문 (여러 줄) |
| `body.md` | 14 / 22 / Regular | 카드 본문 |
| `body.sm` | 13.5 / 21 / Regular | 부가 설명 |
| `label.md` | 13 / 18 / Medium | 영역 라벨, 상태 |
| `caption` | 11 / 14 / Medium | 1/6 카운터, 메타 |
| `cta` | 16 / 22 / SemiBold | CTA 버튼 |

### 4.3 한국어 줄바꿈 원칙

- 줄바꿈은 *의미 단위*에서. e.g. *"당신은 죽음 이후에 무언가가 있다 / 고 생각하시나요?"*
- 어색한 토큰 분리 금지: *"하시나 / 요?"* X
- iOS UILabel `lineBreakStrategy = .hangulWordPriority` 활성

## 5. Spacing Scale (8pt 기반)

| 토큰 | 값 | 사용 |
|------|----|------|
| `space.xxs` | 4 | 인접 텍스트 |
| `space.xs` | 8 | 라벨 ↔ 본문 |
| `space.sm` | 12 | 헤드 ↔ 본문 |
| `space.md` | 16 | 본문 단락 / 카드 패딩 |
| `space.lg` | 24 | 모달 패딩 / 화면 좌우 마진 |
| `space.xl` | 32 | 섹션 간 |
| `space.xxl` | 48 | 화면 상단 여백 |
| `space.section` | 64 | 큰 섹션 분리 (인장 위) |

## 6. Radius / Shadow / Border

| 토큰 | 값 | 사용 |
|------|----|------|
| `radius.sm` | 8 | 마이크 버튼 / 입력칩 |
| `radius.md` | 12 | 녹음 배너 / 입력 영역 |
| `radius.lg` | 18 | 모달 |
| `radius.xl` | 24 | 카드 |
| `radius.cta` | 12 | 주 CTA 버튼 |
| `border.width.thin` | 1 | divider, card border |
| `shadow.subtle` | `0 1 4 rgba(0,0,0,0.04)` | 카드 |
| `shadow.elevated` | `0 4 16 rgba(0,0,0,0.08)` | 모달 (light) |

다크 모드: `shadow.subtle/elevated`은 사용 안 함. 대신 `border.subtle` 명시.

## 7. Motion

| 토큰 | 곡선 / 시간 |
|------|-------------|
| `motion.swift` | easeInOut / 200ms — 버튼 상태 |
| `motion.standard` | easeInOut / 300ms — 모달 등장 |
| `motion.calm` | easeInOut / 450ms — 카드 펼침 |
| `motion.pulse` | easeInOut / 1600ms infinite — 마이크 활성 |
| `motion.recording-dot` | easeInOut / 1200ms infinite — 녹음 빨간 점 |
| `motion.waveform` | easeInOut / 1200ms infinite, stagger 0–300ms — 음성 진폭 |

원칙: *부드럽되 길지 않게*. 본 앱은 *빠른 reaction*보다 *침착한 dwell*. 그러나 길이 자체가 길면 무겁게 느껴짐.

## 8. Components

### 8.1 PrimaryButton (CTA)

- 배경: `accent.primary`
- 글자: `accent.contrast`, `cta` 토큰
- height: 56pt
- radius: `radius.cta`
- 좌우 padding: `space.lg`
- pressed: opacity 0.85
- disabled: bg `text.disabled`, glyph 동일

### 8.2 SecondaryButton (텍스트 링크)

- 배경: 투명
- 글자: `text.secondary`, `body.md / Medium`
- pressed: opacity 0.6
- 사용: "더 쉽게 설명해주세요", "건너뛸게요", "잠시 쉬었다 할게요"

### 8.3 MicButton

| 상태 | 배경 | 아이콘 | 애니메이션 |
|------|------|--------|------------|
| 비활성 | `bg.subtle` | `text.secondary` mic | — |
| 활성 (녹음 중) | `accent.primary` | `accent.contrast` mic | pulse 1.6s |
| 권한 거부 | `bg.subtle` | `text.disabled` mic-slash | — (탭 시 설정 안내) |

크기 40×40, radius 50% (원).

### 8.4 RecordingBanner

- 좌측 빨간 점 8×8 + pulse 1.2s
- 라벨 "듣고 있습니다" `body.sm`
- 우측 시간 `SF Mono 13`
- 배경 `bg.subtle`, radius 12, padding (10, 16)

### 8.5 Waveform

- 막대 25개, 너비 2.5, gap 3
- 색 `accent.primary` opacity 0.7
- 애니메이션 `motion.waveform`, stagger
- 무음 시 정지 + 막대 1.5px 균일 (idle baseline)

### 8.6 ProgressBar (인터뷰 1/6)

- height 2pt
- bg `divider`, fill `text.primary`
- 좌→우 채워짐. duration `motion.standard`

### 8.7 ChoiceChip (skip reason)

- radio 형태. 배경 투명, border 1pt `divider`
- 선택 시 border `text.primary`, 좌측 `●`

### 8.8 MatchCard

- 배경 `bg.elevated`
- radius `radius.xl`
- padding `space.lg`
- 좌측 상단 작은 도트 + 라벨 (state.alignment / compromise / boundary 색)
- 헤드 `headline.md`
- 본문 `body.md`
- divider 후 *통합 핵심 유형*

### 8.9 ChatBubble

- 자기 메시지: 배경 `accent.primary`, 글자 `accent.contrast`, 우측 정렬
- 상대 메시지: 배경 `bg.subtle`, 글자 `text.primary`, 좌측 정렬
- radius 18 (양쪽 위, 같은 사용자 측은 4)
- 시스템 메시지 ("결을 통해 연결되었습니다"): 가운데, `text.secondary`, `body.sm`

### 8.10 Modal

- 너비 320 (좌우 24 마진)
- bg `bg.elevated`
- radius `radius.lg`
- padding 24
- 타이틀 `headline.sm`
- 본문 `body.sm`, line-height 1.55, `text.secondary`
- 액션 행 — 좌(취소 `text.secondary`), 우(주 액션 `accent.primary`)
- 두 액션 사이 1pt divider

## 9. 13개 화면 매핑

| # | 라벨 | 화면설계 v2 §  | 핵심 컴포넌트 |
|---|------|---------------|---------------|
| 1 | 온보딩 게이트 | §2 | display.brand "결", body.lg, PrimaryButton |
| 2 | Apple Sign In | §3 | Apple Sign In 표준 버튼, body.sm |
| 3 | 영역 인터뷰 (오픈 질문) | §4 | ProgressBar, label, headline.lg, SecondaryButton (회피) |
| 4 | 답변 입력 — 키보드 | §5 | 헤더 질문 paraphrase, MicButton, multi-line text, helper, PrimaryButton |
| 4·A | 음성 입력 권한 | §5 | iOS 시스템 모달 |
| 4·B | 음성 입력 녹음 중 | §5 | MicButton 활성, RecordingBanner, Waveform, "녹음 종료" |
| 4·C | 음성 입력 종료, 편집 | §5 | MicButton 비활성, helper "음성으로 받은 텍스트입니다…", PrimaryButton |
| 5 | 후속 질문 생성 중 | §6 | "당신의 답을 읽고 있습니다", dot loader |
| 6 | 후속 질문 (대화형) | §7 | 이전 답변 prefix, 결의 후속 질문, 답변 입력 + MicButton |
| 7 | 영역 종료 | §8 | "답변이 끝났습니다", 다음 영역 hint, PrimaryButton + 보조 |
| 9 | 명시 Dealbreaker 입력 | §10 | 영역별. 자유 텍스트 + 예시 보기 펼침. 선택 비워두기 가능 |
| 10 | 본인 검토 (발행 직전) | §11 | 6영역 결 카드 6개 + 통합 결 + dealbreaker 표시. PrimaryButton "발행하기" |
| 11 | 매칭 후보 목록 | §12 | MatchCard 스크롤 |
| 12 | 후보 카드 펼침 | §13 | 카드 헤드라인, 결이 닿는 부분, 결의 차이, 영역별 라벨, [관심 있음] |
| 13 | 대화방 | §14 | ChatBubble, 입력바 |

## 10. Active Verification (Phase 3 plan)

iOS Simulator (iPhone 15) 라이트/다크 모드 13화면 전부:
- VoiceOver 한국어 발화 검증
- Dynamic Type Large 지원 (텍스트 잘림 없음)
- iPhone SE (3rd) 좁은 화면 적합성

## 11. DAI Self-Score

| 차원 | 점수 | 근거 |
|------|------|------|
| Cohesion (0.30) | 9 | 17 스크린샷 전반 일관. 베이지+검정+serif 한글 모두 정합 |
| Originality (0.25) | 8 | 한국 IT 앱 대비 묵직 / 매칭 앱 대비 명조 헤드 / "결" 인장 1자 = 차별 |
| Craft (0.25) | 7 | 줄바꿈 한글 우선 + 음성 4단계 디테일 + Dark/Light 양 토큰 |
| Intuitiveness (0.20) | 8 | 한 화면 한 질문 / CTA 1차 명확 / 회피 2차 명확 |

**DAI = (9×0.30)+(8×0.25)+(7×0.25)+(8×0.20) = 2.70+2.00+1.75+1.60 = 8.05 → PASS (≥7).**

Hard-fail 차단 — Cohesion ≥5, Craft ≥5 정합.
