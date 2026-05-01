# AGENTS.md

본 파일은 Codex / Cursor / 기타 코딩 에이전트가 이 디렉토리에서 일할 때 참조한다. **CLAUDE.md와 동일 source of truth — 변경 시 두 파일 동기화.**

내용 본체는 CLAUDE.md 참조. 본 파일은 미러:

- 프로젝트 정체성 + 핵심 결정 6가지: → `CLAUDE.md` "프로젝트 정체성"
- 디렉토리 가이드: → `CLAUDE.md` "디렉토리 가이드"
- Edge Functions 19개: → `CLAUDE.md` "Edge Functions 19개"
- 변경 시 정합성 체크리스트: → `CLAUDE.md` "변경 시 정합성 체크리스트"
- 결정론 핵심 함수: → `CLAUDE.md` "결정론 핵심 함수"
- 로깅 정책 (PII 정합): → `CLAUDE.md` "로깅 정책"
- 자주 하는 작업: → `CLAUDE.md` "자주 하는 작업"
- 절대 하지 말 것: → `CLAUDE.md` "절대 하지 말 것"
- 운영 단계 보강 항목: → `CLAUDE.md` "운영 단계 보강 항목"

## 다중 에이전트 운영 규칙

1. **변경 전 의존성 맵 확인** — `docs/backend-dependency-map.md` 1.2 표가 현재 19개 Edge Functions의 권위 카탈로그.
2. **로깅 정책은 검토자가 강제** — PR 생성 시 `grep -E "(text_plain|raw_answer|summary_where|interpretation|quote)" 추가된 로그라인 = 0` 자동 점검.
3. **결정론 함수 단위 테스트는 깨면 안 됨** — `deno test --allow-net=none backend/supabase/functions/_shared/test_scoring.ts` 29/29 PASS 유지.
4. **사양 5종은 immutable** — `결_*_v*.md`는 historical record. 새 결정은 `docs/specs/` 또는 ADR로.
5. **Apple Sign In + iOS Speech + Apple HIG**는 본 앱 정체성 — Android/외부 STT/Web 추가 제안 금지 (PRD §4.2 OUT).

## 에이전트별 특수 사항

- **Claude Code**: ordiq-* 스킬 사용 가능. 파이프라인 상태는 `.claude/ordiq/pipeline-state.md`.
- **Codex CLI**: ordiq 스킬 없음. `npx supabase functions deploy <name>` + `deno test ...` 직접 실행.
- **Cursor / Copilot**: 코드 자동완성 — `_shared/types.ts` import 시 PII 정책 주석 보존.
