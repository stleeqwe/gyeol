# 결 (Gyeol)

> 결혼 또는 매우 진지한 장기 연애를 고민하는 사용자를 위한 *가치관 매칭* iOS 앱.
> Live: Supabase Seoul + Google AI Studio (Gemini 3 Flash + 3.1 Flash-Lite)
> Decisional core: 결정론 매칭 + raw quote 3중 방어선 + post-polish-validation 8가지

## 구조

```
.
├── 결_*_v*.md                    # 원본 한국어 사양 (immutable history) — v3 / v7 시리즈
├── 화면디자인/                   # 17 시안 PNG (라이트/다크)
├── docs/
│   ├── specs/01-prd.md           # ordiq Stage 1
│   ├── specs/02-architecture.md  # ordiq Stage 2 (ADR 15개)
│   ├── specs/03-design-system.md # ordiq Stage 3
│   ├── backend-dependency-map.md # ordiq Stage 5 (19 functions + 6 contracts)
│   └── RUNBOOK.md                # 운영 절차
├── CLAUDE.md / AGENTS.md         # 다중 에이전트 가이드 (단일 source of truth)
├── backend/
│   └── supabase/
│       ├── config.toml           # CLI 배포 + verify_jwt 매핑
│       ├── migrations/           # PostgreSQL DDL + RLS + seed (0001..0006)
│       └── functions/            # Edge Functions Deno (19개) + _shared 라이브러리 (12+2)
└── ios/
    ├── Gyeol.xcodeproj           # 실행 가능한 iOS 앱 타겟 (XcodeGen 산출물)
    ├── project.yml               # XcodeGen source of truth
    ├── Package.swift             # GyeolDomain / GyeolCore / GyeolUI SPM 모듈
    ├── Gyeol/                    # iOS 앱 소스 (App / Models / Services + Logging.swift / ViewModels / Views / Components / Resources)
    └── GyeolTests/
```

## Live 배포 상태

| 항목 | 값 |
|------|----|
| 프로젝트 ref | `xkgffegenrvitalgncnt` |
| URL | `https://xkgffegenrvitalgncnt.supabase.co` |
| 리전 | `ap-northeast-2` (Seoul) |
| PostgreSQL | 17.6 |
| 마이그레이션 | 로컬 재현 0001..0006 (init / normalization / matching / RLS / canonical seed / 보안 강화) |
| 테이블 | 17개 모두 RLS enabled, canonical 사전 3개는 public read 정책 |
| Edge Functions | **19개 ACTIVE** (13 핵심 + 6 사용자 facade — bootstrap-user/submit-answer/set-domain-status/submit-dealbreakers/prepare-review/request-explanation) |
| Secrets | `INTERNAL_CALL_TOKEN` ✓ / `GEMINI_API_KEY` ✓ / `GEMINI_FLASH_MODEL=gemini-3-flash-preview` ✓ / `GEMINI_LITE_MODEL=gemini-3.1-flash-lite-preview` ✓ |
| 결정론 단위 테스트 | **29 / 29 PASS** (`deno test --allow-net=none backend/supabase/functions/_shared/test_scoring.ts`) |
| 보안 advisor | ERROR 0 / WARN 0 |
| Reactive Sync | 5 contracts COMPLETE / 1 GAP (영역 재시작 — Phase 2) |

## 빌드

### 백엔드 — 이미 배포됨

**재배포 (코드 수정 시)**:
```bash
cd backend
supabase functions deploy <function-name>      # 단일
supabase functions deploy                       # 전체 (config.toml 자동 적용)
```

**secrets 갱신**:
```bash
cd backend
supabase secrets list
supabase secrets set GEMINI_API_KEY="..." \
                     INTERNAL_CALL_TOKEN="$(openssl rand -hex 32)"
```

### iOS

1. `cd ios && xcodegen generate`로 `Gyeol.xcodeproj` 재생성
2. Xcode에서 `ios/Gyeol.xcodeproj` 열기
3. `GyeolApp` scheme + iPhone Simulator (iOS 17+) 선택 → Run
4. `Gyeol/Resources/Gyeol.xcconfig`가 Debug/Release에 연결되어 `SUPABASE_URL` / `SUPABASE_ANON_KEY`를 주입
5. 실기기 배포 시 Apple Developer Team을 설정하고 Sign in with Apple capability 확인

CLI 검증:
```bash
cd ios
swift test
xcodebuild -scheme GyeolApp -project Gyeol.xcodeproj -destination 'generic/platform=iOS Simulator' build
```

**현재 키** (publishable, anon level):
- URL: `https://xkgffegenrvitalgncnt.supabase.co`
- ANON KEY: `sb_publishable__8MViMngmZS76hXOrI76Qw_cRHAoYNc`

## 결정론 vs LLM 분리 (ADR-004)

- **결정론** (LLM 호출 0): 호환 점수 / alignment_level / atoms / boundary_check_payload / draft narrative 조립 / post-polish-validation 8가지 / raw quote n-gram detect / cache key
- **LLM (Gemini 3 Flash)**: 후속 질문(A) / 영역 분석문(B) / 통합 핵심 유형(D)
- **LLM (Gemini 3.1 Flash-Lite)**: narrative 후편집(C, 조건부) / dealbreaker 정규화(E)
- **on-device**: Apple Speech Framework (외부 전송 0)

## 사용자 facade Edge Functions (ADR-015)

iOS는 plaintext만 전송. ciphertext 변환과 service_role 트리거는 Edge에 캡슐화:

| facade 함수 | iOS 호출자 | 책임 |
|-------------|------------|------|
| `bootstrap-user` | AuthService.refresh (Apple Sign In 직후) | auth.users → public.users + consent 상태 회신 |
| `submit-answer` | InterviewService.submitAnswer | text_plain → encodeMvpCiphertext → bytea |
| `set-domain-status` | InterviewService.skipDomain / keepPrivate | skip 사유 enum + private 보관 통합 |
| `submit-dealbreakers` | InterviewService.submitDealbreakers | raw_texts → bytea |
| `prepare-review` | SelfReviewScreen.task | core_identity + dealbreaker 정규화 보장 |
| `request-explanation` | MatchListScreen / MatchDetailScreen | lazy 큐: explanation + matrix-engine 트리거 |

## 데이터 비공개 5단계

| 범위 | 노출 |
|------|------|
| `service_role_only` | 운영자 — structured, normalized_profiles, polished_output_cache, operator_review_queue |
| `self_only` | 본인 — interview_answers, explicit_dealbreakers.raw_user_text |
| `self_review_only` | 본인 검토 화면 — answer_evidence (raw quote 격리) |
| `match_visible` (public_safe) | 매칭 상대 — analyses.summary_*, core_identities.label/interpretation |
| `viewer_only` | 특정 viewer만 — matches.recommendation_narrative |

## Observability

- **Edge Functions**: `_shared/logger.ts` JSON 한 줄 console → Supabase Logs (`LOG_LEVEL` env, default `info`)
- **iOS**: `Services/Logging.swift` OSLog 7 카테고리 (auth/interview/speech/match/chat/realtime/api) → Console.app
- **PII 정책**: raw 답변 / summary 텍스트 / quote / polished narrative 절대 비노출. ID(8자 short) / enum / version / latency_ms / *_chars만.

## ordiq 파이프라인 결과 (2026-05-01)

- Stage 1: IQS handoff-ready, Scope Dial: HOLD
- Stage 2: AHS 7.65/10 (Grade B) — ADR 15개
- Stage 3: DAI 8.05/10 (Grade B+) — 17 시안 정합
- Stage 4: BAS 7.6/10 (구현 완료, 라이브)
- Stage 5: Map Health 8.75/10
- Stage 6: qa B / front B / perf B 모두 PASS
- Stage 7: Doc Health A (88) — README + CLAUDE + AGENTS + RUNBOOK + dependency map + ADR + 사양 5종
- Stage 8: Review Health 84.6/10 (Grade B)

## 사용자 별도 작업

1. **Apple Developer**: Sign In Service ID + Key (Supabase Studio → Auth → Providers → Apple 활성화)
2. **Xcode 프로젝트 셋업**: xcconfig 연결 + Sign in with Apple capability + iOS 시뮬레이터 13화면 검증

## 라이선스

Private. PIPA 23조 정합.
