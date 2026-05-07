-- 결 (Gyeol) — backend hardening
-- Tighten client write surface, protect internal analysis columns, and add
-- server-side publish state for matching pool eligibility.

-- ─────────────────────────────────────────────────────────────
-- Server-side publish state
-- ─────────────────────────────────────────────────────────────

alter table users
add column if not exists profile_published_at timestamptz;

create index if not exists idx_users_published_active
on users(profile_published_at)
where deleted_at is null and profile_published_at is not null;

-- ─────────────────────────────────────────────────────────────
-- Answer idempotency
-- ─────────────────────────────────────────────────────────────

do $$
begin
    if not exists (
        select 1 from pg_class where relname = 'idx_answers_open_unique_seq'
    ) and not exists (
        select 1
        from interview_answers
        where parent_answer_id is null
        group by interview_id, seq
        having count(*) > 1
    ) then
        create unique index idx_answers_open_unique_seq
        on interview_answers(interview_id, seq)
        where parent_answer_id is null;
    end if;
end $$;

do $$
begin
    if not exists (
        select 1 from pg_class where relname = 'idx_answers_followup_unique_seq'
    ) and not exists (
        select 1
        from interview_answers
        where parent_answer_id is not null
        group by interview_id, parent_answer_id, seq
        having count(*) > 1
    ) then
        create unique index idx_answers_followup_unique_seq
        on interview_answers(interview_id, parent_answer_id, seq)
        where parent_answer_id is not null;
    end if;
end $$;

-- ─────────────────────────────────────────────────────────────
-- Client write surface: writes go through Edge Function facades
-- ─────────────────────────────────────────────────────────────

revoke insert, update, delete on table consents from anon, authenticated;
revoke insert, update, delete on table interviews from anon, authenticated;
revoke insert, update, delete on table interview_answers from anon, authenticated;
revoke insert, update, delete on table explicit_dealbreakers from anon, authenticated;

-- Match interest remains client-driven for realtime UX, but only that column.
revoke update on table matches from anon, authenticated;
grant update(viewer_interest) on table matches to authenticated;

-- ─────────────────────────────────────────────────────────────
-- analyses: public-safe columns are client-readable, structured stays internal
-- ─────────────────────────────────────────────────────────────

revoke select on table analyses from anon, authenticated;
grant select (
    id,
    user_id,
    interview_id,
    domain,
    profile_version,
    assessment_version,
    summary_where,
    summary_why,
    summary_how,
    summary_tension_type,
    summary_tension_text,
    depth_level,
    is_from_skip,
    is_from_private_kept,
    created_at,
    updated_at
) on table analyses to authenticated;

grant all on table analyses to service_role;
