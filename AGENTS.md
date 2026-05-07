> Translated from Korean (see .ko.md backup). Authoritative version.

# AGENTS.md

This file is referenced by Codex / Cursor / other coding agents when working in this directory. **Same single source of truth as CLAUDE.md — keep both files in sync when making changes.**

The body of this document defers to CLAUDE.md. This file is a mirror:

- Project identity + 6 core decisions: → `CLAUDE.md` "Project Identity"
- Directory guide: → `CLAUDE.md` "Directory Guide"
- Edge Functions 19: → `CLAUDE.md` "Edge Functions — 19"
- Consistency checklist when changing: → `CLAUDE.md` "Consistency Checklist When Changing"
- Deterministic core functions: → `CLAUDE.md` "Deterministic Core Functions"
- Logging policy (PII compliance): → `CLAUDE.md` "Logging Policy"
- Common tasks: → `CLAUDE.md` "Common Tasks"
- Never do: → `CLAUDE.md` "Never Do"
- Production phase TODO items: → `CLAUDE.md` "Production Phase TODO Items"
- Autonomous deployment authorization: → `CLAUDE.md` "Autonomous Deployment Authorization"

## Documentation Language Policy

> **CLAUDE.md is the authoritative source for this policy. This section mirrors it.**

**All documentation files in this repository MUST be written in English.**

- Korean source specs (`결_*_v*.md`) are preserved as immutable history. Their English translations live in `결_*_v*_en.md`.
- All other `.md` files (README, CLAUDE.md, AGENTS.md, RUNBOOK, ordiq specs, dependency map) — English only.
- Korean backup of previously-Korean docs is preserved as `*.ko.md` for reference, but `*.md` (without `.ko`) is the authoritative version.
- When you create new `.md` files, write them in English.
- When you update existing `.md` files, keep them in English. Do not introduce Korean prose.
- Inline Korean is allowed only for: (a) UI strings shown to users, (b) raw quote examples for clarity, (c) original Korean spec filenames as immutable identifiers.
- This policy applies to AI agents (Claude Code, Codex, Cursor) and human contributors equally.

## Multi-Agent Operation Rules

1. **Check dependency map before making changes** — `docs/backend-dependency-map.md` table 1.2 is the authoritative catalog of the current 19 Edge Functions.
2. **Logging policy is enforced by reviewers** — On PR creation, `grep -E "(text_plain|raw_answer|summary_where|interpretation|quote)"` added log lines = 0 automated check.
3. **Deterministic function unit tests must not break** — `deno test --allow-net=none backend/supabase/functions/_shared/test_scoring.ts` maintain 29/29 PASS.
4. **5 spec files are immutable** — `결_*_v*.md` are historical records. New decisions go into `docs/specs/` or as ADRs.
5. **Apple Sign In + iOS Speech + Apple HIG** are core to this app's identity — do not propose Android/external STT/Web additions (PRD §4.2 OUT).

## Autonomous Deployment Authorization (mirror of CLAUDE.md)

The repository owner has granted standing authorization for coding agents to deploy backend changes (Supabase Edge Functions, migrations, secrets) without per-call confirmation. See `CLAUDE.md` "Autonomous Deployment Authorization" for the full rule set, including the destructive-operation exceptions that still require explicit confirmation.

## Agent-Specific Notes

- **Claude Code**: ordiq-* skills available. Pipeline state at `.claude/ordiq/pipeline-state.md`.
- **Codex CLI**: no ordiq skills. Run `npx supabase functions deploy <name>` + `deno test ...` directly.
- **Cursor / Copilot**: code autocomplete — preserve PII policy comments when importing `_shared/types.ts`.
