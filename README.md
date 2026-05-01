> Translated from Korean (see .ko.md backup). Authoritative version.

# Gyeol

> A *value-alignment matching* iOS app for users seriously considering marriage or a long-term committed relationship.
> Live: Supabase Seoul + Google AI Studio (Gemini 3 Flash + 3.1 Flash-Lite)
> Decisional core: deterministic matching + raw quote triple-defense + 8 post-polish-validation checks

## Structure

```
.
├── 결_*_v*.md                    # Original Korean spec (immutable history) — v3 / v7 series
├── 화면디자인/                   # 17 mockup PNGs (light/dark)
├── docs/
│   ├── specs/01-prd.md           # ordiq Stage 1
│   ├── specs/02-architecture.md  # ordiq Stage 2 (15 ADRs)
│   ├── specs/03-design-system.md # ordiq Stage 3
│   ├── backend-dependency-map.md # ordiq Stage 5 (19 functions + 6 contracts)
│   └── RUNBOOK.md                # Operations runbook
├── CLAUDE.md / AGENTS.md         # Multi-agent operation rules (single source of truth)
├── backend/
│   └── supabase/
│       ├── config.toml           # CLI deploy + verify_jwt mapping
│       ├── migrations/           # PostgreSQL DDL + RLS + seed (0001..0006)
│       └── functions/            # Edge Functions Deno (19) + _shared library (12+2)
└── ios/
    ├── Gyeol.xcodeproj           # Runnable iOS app target (XcodeGen output)
    ├── project.yml               # XcodeGen source of truth
    ├── Package.swift             # GyeolDomain / GyeolCore / GyeolUI SPM modules
    ├── Gyeol/                    # iOS app source (App / Models / Services + Logging.swift / ViewModels / Views / Components / Resources)
    └── GyeolTests/
```

## Live Deployment Status

| Item | Value |
|------|-------|
| Project ref | `xkgffegenrvitalgncnt` |
| URL | `https://xkgffegenrvitalgncnt.supabase.co` |
| Region | `ap-northeast-2` (Seoul) |
| PostgreSQL | 17.6 |
| Migrations | Local reproducible 0001..0006 (init / normalization / matching / RLS / canonical seed / security hardening) |
| Tables | All 17 tables RLS enabled; 3 canonical dictionary tables have public read policies |
| Edge Functions | **19 ACTIVE** (13 core + 6 user-facing facade — bootstrap-user/submit-answer/set-domain-status/submit-dealbreakers/prepare-review/request-explanation) |
| Secrets | `INTERNAL_CALL_TOKEN` ✓ / `GEMINI_API_KEY` ✓ / `GEMINI_FLASH_MODEL=gemini-3-flash-preview` ✓ / `GEMINI_LITE_MODEL=gemini-3.1-flash-lite-preview` ✓ |
| Deterministic unit tests | **29 / 29 PASS** (`deno test --allow-net=none backend/supabase/functions/_shared/test_scoring.ts`) |
| Security advisor | ERROR 0 / WARN 0 |
| Reactive Sync | 5 contracts COMPLETE / 1 GAP (domain restart — Phase 2) |

## Build

### Backend — Already Deployed

**Redeploy (after code changes)**:
```bash
cd backend
supabase functions deploy <function-name>      # single function
supabase functions deploy                       # all functions (config.toml applied automatically)
```

**Update secrets**:
```bash
cd backend
supabase secrets list
supabase secrets set GEMINI_API_KEY="..." \
                     INTERNAL_CALL_TOKEN="$(openssl rand -hex 32)"
```

### iOS

1. Run `cd ios && xcodegen generate` to regenerate `Gyeol.xcodeproj`
2. Open `ios/Gyeol.xcodeproj` in Xcode
3. Select the `GyeolApp` scheme + an iPhone Simulator (iOS 17+) → Run
4. `Gyeol/Resources/Gyeol.xcconfig` is attached to Debug/Release and injects `SUPABASE_URL` / `SUPABASE_ANON_KEY`
5. For device distribution, set an Apple Developer Team and verify the Sign in with Apple capability

CLI verification:
```bash
cd ios
swift test
xcodebuild -scheme GyeolApp -project Gyeol.xcodeproj -destination 'generic/platform=iOS Simulator' build
```

**Current keys** (publishable, anon level):
- URL: `https://xkgffegenrvitalgncnt.supabase.co`
- ANON KEY: `sb_publishable__8MViMngmZS76hXOrI76Qw_cRHAoYNc`

## Deterministic vs LLM Separation (ADR-004)

- **Deterministic** (0 LLM calls): compatibility score / alignment_level / atoms / boundary_check_payload / draft narrative assembly / 8 post-polish-validation checks / raw quote n-gram detect / cache key
- **LLM (Gemini 3 Flash)**: follow-up questions (A) / domain analysis text (B) / integrated core type (D)
- **LLM (Gemini 3.1 Flash-Lite)**: narrative post-edit (C, conditional) / dealbreaker normalization (E)
- **On-device**: Apple Speech Framework (0 external transmission)

## User-Facing Facade Edge Functions (ADR-015)

iOS sends plaintext only. Ciphertext conversion and service_role triggers are encapsulated in the Edge:

| Facade function | iOS caller | Responsibility |
|-----------------|------------|----------------|
| `bootstrap-user` | AuthService.refresh (immediately after Apple Sign In) | auth.users → public.users + consent state response |
| `submit-answer` | InterviewService.submitAnswer | text_plain → encodeMvpCiphertext → bytea |
| `set-domain-status` | InterviewService.skipDomain / keepPrivate | skip reason enum + private storage unified |
| `submit-dealbreakers` | InterviewService.submitDealbreakers | raw_texts → bytea |
| `prepare-review` | SelfReviewScreen.task | core_identity + dealbreaker normalization guaranteed |
| `request-explanation` | MatchListScreen / MatchDetailScreen | lazy queue: explanation + matrix-engine trigger |

## Data Privacy 5 Levels

| Scope | Exposure |
|-------|----------|
| `service_role_only` | Operator — structured, normalized_profiles, polished_output_cache, operator_review_queue |
| `self_only` | Self — interview_answers, explicit_dealbreakers.raw_user_text |
| `self_review_only` | Self review screen — answer_evidence (raw quote isolated) |
| `match_visible` (public_safe) | Match partner — analyses.summary_*, core_identities.label/interpretation |
| `viewer_only` | Specific viewer only — matches.recommendation_narrative |

## Observability

- **Edge Functions**: `_shared/logger.ts` single-line JSON console → Supabase Logs (`LOG_LEVEL` env, default `info`)
- **iOS**: `Services/Logging.swift` OSLog 7 categories (auth/interview/speech/match/chat/realtime/api) → Console.app
- **PII policy**: raw answers / summary text / quotes / polished narrative are never exposed. Only ID (8-char short) / enum / version / latency_ms / *_chars.

## ordiq Pipeline Results (2026-05-01)

- Stage 1: IQS handoff-ready, Scope Dial: HOLD
- Stage 2: AHS 7.65/10 (Grade B) — 15 ADRs
- Stage 3: DAI 8.05/10 (Grade B+) — 17 mockups consistent
- Stage 4: BAS 7.6/10 (implementation complete, live)
- Stage 5: Map Health 8.75/10
- Stage 6: qa B / front B / perf B all PASS
- Stage 7: Doc Health A (88) — README + CLAUDE + AGENTS + RUNBOOK + dependency map + ADR + 5 spec files
- Stage 8: Review Health 84.6/10 (Grade B)

## User Action Items

1. **Apple Developer**: Sign In Service ID + Key (Supabase Studio → Auth → Providers → Apple enable)
2. **Xcode project setup**: link xcconfig + Sign in with Apple capability + validate 13 screens on iOS Simulator

## License

Private. PIPA Article 23 compliant.
