-- 결 (Gyeol) — 0001 init schema
-- 시스템설계 v3 §3.1 + 매칭알고리즘 v7 §4.3
-- PIPA 23조 정합. 모든 raw 답변·structured는 application-level 암호화 전제(envelope keys는 Supabase secrets).

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- ─────────────────────────────────────────────────────────────
-- enum types
-- ─────────────────────────────────────────────────────────────

create type domain_id as enum (
    'belief',          -- 신념 체계
    'society',         -- 사회와 개인
    'bioethics',       -- 생명 윤리
    'family',          -- 가족과 권위
    'work_life',       -- 일과 삶
    'intimacy'         -- 친밀함
);

create type interview_status as enum (
    'in_progress',     -- 답변 중
    'analyzing',       -- LLM-B 호출 중
    'finalized',       -- 영역 분석 완료
    'skipped',         -- 건너뜀
    'private_kept'     -- 비공개 보관
);

create type skip_reason as enum (
    'do_not_want_public',     -- 공개하고 싶지 않음
    'not_settled',            -- 아직 정리되지 않음
    'not_important',          -- 중요하지 않다고 판단
    'other'                   -- 기타
);

create type recommendation_status as enum (
    'pending',
    'ready',
    'needs_review_hidden',
    'fallback_shown'
);

create type qualitative_label as enum (
    'alignment',       -- 결이 잘 맞음
    'compromise',      -- 타협 가능
    'boundary'         -- 경계 확인
);

create type alignment_level as enum (
    'strong',
    'moderate',
    'tension',
    'soft_conflict'
);

create type stance as enum (
    'require',
    'support',
    'allow',
    'neutral',
    'avoid',
    'reject'
);

create type intensity as enum (
    'strong',
    'moderate',
    'mild'
);

create type stance_scope as enum (
    'self',
    'partner',
    'children',
    'household',
    'public_policy'
);

create type queue_reason as enum (
    'top_match',
    'boundary_check'
);

create type match_interest as enum (
    'pending',
    'interested',
    'declined'
);

-- ─────────────────────────────────────────────────────────────
-- users
-- ─────────────────────────────────────────────────────────────

create table users (
    id uuid primary key default gen_random_uuid(),
    apple_sub text not null unique,            -- Apple Sign In stable id
    email_hash text,                            -- 옵션, hashed only
    display_name text,                          -- 사용자 본인이 자기 검토에서만 봄
    created_at timestamptz not null default now(),
    last_active_at timestamptz not null default now(),
    deleted_at timestamptz,                     -- soft delete (PIPA)
    deletion_purges_at timestamptz              -- 30일 후 hard purge
);

create index idx_users_apple_sub on users(apple_sub);
create index idx_users_active on users(last_active_at) where deleted_at is null;

-- ─────────────────────────────────────────────────────────────
-- consents (PIPA 23조 별도 동의)
-- ─────────────────────────────────────────────────────────────

create table consents (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users(id) on delete cascade,

    -- 별도 동의 항목
    sensitive_data_processing boolean not null,        -- 민감정보 처리
    voice_on_device_disclosed boolean not null,         -- 음성 on-device 처리 고지
    raw_quote_isolation_disclosed boolean not null,     -- raw quote 격리 고지
    no_ai_training_disclosed boolean not null,          -- AI 학습 미사용 고지
    data_residency_disclosed boolean not null,          -- 한국 데이터 거주 고지

    consented_at timestamptz not null default now(),
    revoked_at timestamptz,
    consent_text_version text not null,                 -- 동의문 버전 추적
    ip_address inet,                                    -- 동의 시 IP (감사 로그)
    user_agent text
);

create index idx_consents_user on consents(user_id) where revoked_at is null;

-- ─────────────────────────────────────────────────────────────
-- interviews — 영역별 인터뷰 진행 상태
-- ─────────────────────────────────────────────────────────────

create table interviews (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users(id) on delete cascade,
    domain domain_id not null,
    status interview_status not null default 'in_progress',
    skip_reason_value skip_reason,                   -- status='skipped' 시
    is_private_kept boolean not null default false,  -- status='private_kept' 시 true

    voice_input_used boolean not null default false,
    voice_input_session_count integer not null default 0,

    started_at timestamptz not null default now(),
    finalized_at timestamptz,
    restarted_count integer not null default 0,      -- 재시작 횟수

    unique (user_id, domain)
);

create index idx_interviews_user on interviews(user_id);
create index idx_interviews_user_status on interviews(user_id, status);

-- ─────────────────────────────────────────────────────────────
-- interview_answers — raw 답변 (암호화)
-- ─────────────────────────────────────────────────────────────
-- text_ciphertext = pgp_sym_encrypt(plaintext, key)
-- 저장 전 application-level encrypt. 본 column은 ciphertext만.

create table interview_answers (
    id uuid primary key default gen_random_uuid(),
    interview_id uuid not null references interviews(id) on delete cascade,
    user_id uuid not null references users(id) on delete cascade,
    domain domain_id not null,

    seq integer not null,                            -- 영역 내 답변 순서 (1, 2, 3 ...)
    is_open_question_answer boolean not null default false,
    parent_answer_id uuid references interview_answers(id) on delete cascade,
    follow_up_question_text text,                    -- LLM-A 결과 (paraphrase, public_safe)
    text_ciphertext bytea not null,                  -- 사용자 답변 ciphertext
    text_length integer not null,                    -- 길이만 평문 (메트릭)
    depth_level smallint not null default 1,         -- 1/2/3 (더 쉽게 단계)

    voice_input_seconds integer,                     -- 음성 사용 시 누적 초

    created_at timestamptz not null default now(),

    constraint depth_range check (depth_level between 1 and 3)
);

create index idx_answers_interview on interview_answers(interview_id, seq);
create index idx_answers_user_domain on interview_answers(user_id, domain);

-- ─────────────────────────────────────────────────────────────
-- analyses — 영역별 분석 (LLM-B 결과)
-- ─────────────────────────────────────────────────────────────
-- summary는 public_safe(plaintext, raw quote 금지). structured는 internal_only(ciphertext).

create table analyses (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users(id) on delete cascade,
    interview_id uuid not null references interviews(id) on delete cascade,
    domain domain_id not null,

    profile_version text not null,                   -- e.g. "v7"
    assessment_version text not null,

    -- summary (public_safe — match_visible)
    summary_where text not null,
    summary_why text not null,
    summary_how text not null,
    summary_tension_type text,
    summary_tension_text text,

    -- structured (internal_only — service_role only, ciphertext)
    structured_ciphertext bytea not null,

    -- depth metadata
    depth_level smallint not null default 1,

    -- skip 상태 분석은 분석문 빈 + 메타만
    is_from_skip boolean not null default false,
    is_from_private_kept boolean not null default false,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index idx_analyses_user_domain on analyses(user_id, domain);
create index idx_analyses_user on analyses(user_id);

-- ─────────────────────────────────────────────────────────────
-- answer_evidence — raw quote 격리 (self_review_only)
-- ─────────────────────────────────────────────────────────────

create table answer_evidence (
    id uuid primary key default gen_random_uuid(),
    analysis_id uuid not null references analyses(id) on delete cascade,
    user_id uuid not null references users(id) on delete cascade,
    domain domain_id not null,

    evidence_id text not null,                       -- ev_001, ev_002 ...
    quote_ciphertext bytea not null,                  -- raw quote ciphertext
    context text,                                     -- self_review_only 표시용 메타

    created_at timestamptz not null default now()
);

create index idx_evidence_analysis on answer_evidence(analysis_id);
create index idx_evidence_user on answer_evidence(user_id);

-- ─────────────────────────────────────────────────────────────
-- core_identities — 통합 핵심 유형 (LLM-D)
-- ─────────────────────────────────────────────────────────────

create table core_identities (
    user_id uuid primary key references users(id) on delete cascade,
    profile_version text not null,
    assessment_version text not null,

    label text not null,                              -- public_safe, 한 문장
    interpretation text not null,                     -- public_safe, 3-5 문장

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────
-- explicit_dealbreakers — 명시 dealbreaker
-- ─────────────────────────────────────────────────────────────
-- raw_user_text는 self_only(ciphertext). canonical은 매칭 알고리즘 사용.

create table explicit_dealbreakers (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users(id) on delete cascade,
    domain domain_id not null,
    seq integer not null,                            -- 영역 내 순서

    raw_user_text_ciphertext bytea,                  -- self_only
    canonical_target_id text,                        -- normalized canonical (e.g. "religion.strong_devotion")
    unacceptable_stances stance[],                   -- canonical 정규화 결과
    intensity_min_for_conflict intensity not null default 'moderate',
    scope stance_scope not null default 'partner',

    created_at timestamptz not null default now()
);

create index idx_dealbreakers_user on explicit_dealbreakers(user_id);
create index idx_dealbreakers_canonical on explicit_dealbreakers(canonical_target_id);

-- ─────────────────────────────────────────────────────────────
-- updated_at trigger 헬퍼
-- ─────────────────────────────────────────────────────────────

create or replace function set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

create trigger trg_analyses_updated before update on analyses
for each row execute function set_updated_at();

create trigger trg_core_identities_updated before update on core_identities
for each row execute function set_updated_at();
