-- 결 (Gyeol) — 0003 matching tables
-- 매칭알고리즘 v7 §4.3, §4.4, §4.5 + 시스템설계 v3 §3.1

-- ─────────────────────────────────────────────────────────────
-- matches — viewer-candidate 페어
-- ─────────────────────────────────────────────────────────────
-- viewer_id가 candidate_id를 본 view (방향성 있음). A→B와 B→A는 별도 row.

create table matches (
    id uuid primary key default gen_random_uuid(),
    viewer_id uuid not null references users(id) on delete cascade,
    candidate_id uuid not null references users(id) on delete cascade,

    -- 호환 점수 + qualitative
    final_score numeric(4,3) not null,                                   -- 0.000 ~ 1.000
    qualitative_label qualitative_label not null,
    queue_reason queue_reason not null,
    comparable_domain_count smallint not null,
    comparable_domain_weight_sum numeric(4,3) not null,

    -- 1단계 — basic (전체 페어)
    compatibility_assessment_basic jsonb not null,                       -- alignment_by_domain (level만)
    shared_sacred_targets text[] not null default '{}',
    assessment_version text not null,

    -- 3단계 — explanation_payload (최종 큐 후보만)
    explanation_payload jsonb,                                           -- pair_reason_atoms + public sentences
    boundary_check_payload jsonb,                                        -- queue_reason='boundary_check' 시
    explanation_built_at timestamptz,

    -- 4단계 — narrative
    matrix_pattern text,
    matrix_template_id text,
    recommendation_status recommendation_status not null default 'pending',
    recommendation_narrative jsonb,                                      -- {headline, alignment_narrative, tension_narrative}

    -- 후편집
    polish_cache_key text,
    polish_applied boolean not null default false,
    polish_validation_passed boolean not null default true,
    polish_failure_reason text,

    -- interest 양방향
    viewer_interest match_interest not null default 'pending',
    candidate_interest match_interest not null default 'pending',
    interest_at timestamptz,

    -- 표시 제외 사유
    hidden_reason text,                                                  -- 'needs_review_hidden' 외

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),

    constraint matches_distinct_users check (viewer_id <> candidate_id),
    unique (viewer_id, candidate_id)
);

create index idx_matches_viewer_status on matches(viewer_id, recommendation_status, final_score desc);
create index idx_matches_candidate on matches(candidate_id);
create index idx_matches_pending_explanation on matches(viewer_id) where explanation_payload is null and recommendation_status = 'pending';
create index idx_matches_interest on matches(viewer_id, candidate_id) where viewer_interest = 'interested' and candidate_interest = 'interested';

create trigger trg_matches_updated before update on matches
for each row execute function set_updated_at();

-- ─────────────────────────────────────────────────────────────
-- polished_output_cache — viewer 분리 캐시 (service_role only)
-- ─────────────────────────────────────────────────────────────

create table polished_output_cache (
    cache_key text primary key,                                          -- SHA-256 hex

    viewer_id uuid not null references users(id) on delete cascade,
    candidate_id uuid not null references users(id) on delete cascade,
    viewer_profile_version text not null,
    candidate_profile_version text not null,
    assessment_version text not null,
    template_library_version text not null,
    polish_prompt_version text not null,
    draft_hash text not null,

    polished_headline text not null,
    polished_alignment_narrative text not null,
    polished_tension_narrative text not null,

    validation_passed boolean not null,
    validation_failure_reason text,

    cached_at timestamptz not null default now(),
    expires_at timestamptz not null
);

create index idx_polished_cache_viewer on polished_output_cache(viewer_id);
create index idx_polished_cache_expires on polished_output_cache(expires_at);

-- ─────────────────────────────────────────────────────────────
-- chat_rooms / chat_messages
-- ─────────────────────────────────────────────────────────────

create table chat_rooms (
    id uuid primary key default gen_random_uuid(),
    match_id uuid not null references matches(id) on delete cascade,
    user_a_id uuid not null references users(id) on delete cascade,    -- viewer
    user_b_id uuid not null references users(id) on delete cascade,    -- candidate
    created_at timestamptz not null default now(),
    last_message_at timestamptz,
    unique (match_id)
);

create index idx_rooms_user_a on chat_rooms(user_a_id);
create index idx_rooms_user_b on chat_rooms(user_b_id);

create table chat_messages (
    id uuid primary key default gen_random_uuid(),
    room_id uuid not null references chat_rooms(id) on delete cascade,
    sender_id uuid references users(id) on delete cascade,             -- null = 시스템 메시지
    is_system boolean not null default false,
    body text not null,                                                -- 본 앱은 텍스트 only, 200자 cap
    created_at timestamptz not null default now()
);

create index idx_messages_room_created on chat_messages(room_id, created_at desc);

-- 새 메시지가 들어오면 last_message_at 갱신
create or replace function bump_room_last_message()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
    update chat_rooms set last_message_at = new.created_at where id = new.room_id;
    return new;
end;
$$;

create trigger trg_messages_bump_room after insert on chat_messages
for each row execute function bump_room_last_message();

-- ─────────────────────────────────────────────────────────────
-- operator_review_queue — 운영자 검토 큐
-- ─────────────────────────────────────────────────────────────

create table operator_review_queue (
    id uuid primary key default gen_random_uuid(),
    issue_type text not null,                                          -- 'raw_quote_in_summary', 'unmapped_dealbreaker', 'tension_generation_failed', 'polish_validation_failed', 'recommendation_status_needs_review'
    related_user_id uuid references users(id) on delete cascade,
    related_match_id uuid references matches(id) on delete cascade,
    related_analysis_id uuid references analyses(id) on delete cascade,
    payload jsonb,
    priority smallint not null default 5,                              -- 1(highest) .. 9(lowest)
    status text not null default 'pending',                            -- 'pending', 'in_review', 'resolved', 'dismissed'
    created_at timestamptz not null default now(),
    resolved_at timestamptz
);

create index idx_review_queue_status_priority on operator_review_queue(status, priority);
create index idx_review_queue_issue on operator_review_queue(issue_type);
