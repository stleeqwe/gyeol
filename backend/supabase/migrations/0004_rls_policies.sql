-- 결 (Gyeol) — 0004 RLS policies
-- 시스템설계 v3 §3.2 + 5단계 비공개 범위(아키텍처 §4.2)

alter table users enable row level security;
alter table consents enable row level security;
alter table interviews enable row level security;
alter table interview_answers enable row level security;
alter table analyses enable row level security;
alter table answer_evidence enable row level security;
alter table core_identities enable row level security;
alter table explicit_dealbreakers enable row level security;
alter table normalized_profiles enable row level security;
alter table matches enable row level security;
alter table polished_output_cache enable row level security;
alter table chat_rooms enable row level security;
alter table chat_messages enable row level security;
alter table operator_review_queue enable row level security;
alter table canonical_principles enable row level security;
alter table canonical_targets enable row level security;
alter table canonical_axes enable row level security;

-- canonical_principles / canonical_targets / canonical_axes는 read-only public dictionary.
-- RLS를 켠 상태에서 select만 public read로 허용하고, write는 service_role만 수행.
create policy canonical_principles_public_read on canonical_principles
    for select using (true);

create policy canonical_targets_public_read on canonical_targets
    for select using (true);

create policy canonical_axes_public_read on canonical_axes
    for select using (true);

-- ─────────────────────────────────────────────────────────────
-- users
-- ─────────────────────────────────────────────────────────────

create policy users_self_read on users
    for select using (auth.uid() = id and deleted_at is null);

create policy users_self_update on users
    for update using (auth.uid() = id);

-- 가입은 service_role(Edge Function)만 — Apple JWT 검증 후 insert

-- ─────────────────────────────────────────────────────────────
-- consents — self only
-- ─────────────────────────────────────────────────────────────

create policy consents_self_read on consents
    for select using (auth.uid() = user_id);

create policy consents_self_insert on consents
    for insert with check (auth.uid() = user_id);

-- 동의 철회는 update가 아니라 새 row insert (감사 로그 보존)
-- revoked_at 갱신은 service_role

-- ─────────────────────────────────────────────────────────────
-- interviews
-- ─────────────────────────────────────────────────────────────

create policy interviews_self_read on interviews
    for select using (auth.uid() = user_id);

create policy interviews_self_insert on interviews
    for insert with check (auth.uid() = user_id);

create policy interviews_self_update on interviews
    for update using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- interview_answers — self only
-- ─────────────────────────────────────────────────────────────

create policy answers_self_all on interview_answers
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────
-- analyses — summary는 match_visible, structured는 service_role
-- ─────────────────────────────────────────────────────────────

create policy analyses_self_read on analyses
    for select using (auth.uid() = user_id);

-- 매칭 상대도 summary 필드 접근 가능 (단 structured_ciphertext는 column-level 차단)
-- 매칭 join 통해 viewer가 candidate analyses 읽기:
create policy analyses_match_visible on analyses
    for select using (
        exists (
            select 1 from matches m
            where m.candidate_id = analyses.user_id
              and m.viewer_id = auth.uid()
              and m.recommendation_status in ('ready', 'fallback_shown')
        )
    );

-- 양방향: candidate가 viewer 분석도 본다 (대화방 상호 존재 확인)
create policy analyses_chat_partner_visible on analyses
    for select using (
        exists (
            select 1 from chat_rooms r
            where (r.user_a_id = analyses.user_id and r.user_b_id = auth.uid())
               or (r.user_b_id = analyses.user_id and r.user_a_id = auth.uid())
        )
    );

-- structured_ciphertext는 column-level — view에서 노출 안 함 (앱 코드는 self 또는 service_role view 사용)

-- ─────────────────────────────────────────────────────────────
-- answer_evidence — self_review_only (본인만)
-- ─────────────────────────────────────────────────────────────

create policy evidence_self_only on answer_evidence
    for select using (auth.uid() = user_id);

-- 다른 사용자의 answer_evidence는 RLS로 절대 노출 안 됨 (service_role 외)

-- ─────────────────────────────────────────────────────────────
-- core_identities — self + match_visible
-- ─────────────────────────────────────────────────────────────

create policy core_identities_self_read on core_identities
    for select using (auth.uid() = user_id);

create policy core_identities_match_visible on core_identities
    for select using (
        exists (
            select 1 from matches m
            where m.candidate_id = core_identities.user_id
              and m.viewer_id = auth.uid()
              and m.recommendation_status in ('ready', 'fallback_shown')
        )
        or exists (
            select 1 from chat_rooms r
            where (r.user_a_id = core_identities.user_id and r.user_b_id = auth.uid())
               or (r.user_b_id = core_identities.user_id and r.user_a_id = auth.uid())
        )
    );

-- ─────────────────────────────────────────────────────────────
-- explicit_dealbreakers — raw_user_text는 self_only, canonical은 service_role
-- ─────────────────────────────────────────────────────────────

create policy dealbreakers_self_all on explicit_dealbreakers
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 매칭 상대에게도 *fact 자체*(영역에 dealbreaker 입력했음)는 노출되어야 하나
-- raw_user_text_ciphertext는 절대 노출 안 됨. 앱은 service_role 쿼리 또는 view 사용.

-- ─────────────────────────────────────────────────────────────
-- normalized_profiles — service_role only
-- ─────────────────────────────────────────────────────────────

-- RLS enabled 후 어떤 policy도 추가 안 함 → 모든 일반 user select 차단.
-- service_role bypass 사용.

-- ─────────────────────────────────────────────────────────────
-- matches — viewer-self read
-- ─────────────────────────────────────────────────────────────

create policy matches_viewer_self on matches
    for select using (auth.uid() = viewer_id);

-- candidate도 양방향 [관심 있음] 후에는 자기 row 읽기 가능 (chat_rooms 존재 확인)
create policy matches_candidate_after_chat on matches
    for select using (
        auth.uid() = candidate_id
        and exists (
            select 1 from chat_rooms r
            where r.match_id = matches.id
        )
    );

create policy matches_viewer_interest_update on matches
    for update using (auth.uid() = viewer_id) with check (auth.uid() = viewer_id);

-- candidate_interest 갱신은 candidate 본인의 viewer_id=candidate인 row 갱신을 통해 일어남.
-- 즉 본 row를 candidate가 직접 update하지 않고, candidate 자기 viewer-row(역방향)에서 viewer_interest 갱신 → trigger로 짝 row의 candidate_interest 갱신.
-- 아래 trigger 참조.

create or replace function sync_pair_interest()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    pair_match_id uuid;
begin
    if new.viewer_interest is distinct from old.viewer_interest then
        select id into pair_match_id
        from matches
        where viewer_id = new.candidate_id and candidate_id = new.viewer_id;

        if pair_match_id is not null then
            update matches
            set candidate_interest = new.viewer_interest,
                updated_at = now()
            where id = pair_match_id;
        end if;

        -- 양방향 [관심 있음] 시 chat_rooms 자동 생성
        if new.viewer_interest = 'interested' and exists (
            select 1 from matches mm
            where mm.viewer_id = new.candidate_id
              and mm.candidate_id = new.viewer_id
              and mm.viewer_interest = 'interested'
        ) and not exists (
            select 1 from chat_rooms where match_id = new.id
        ) then
            insert into chat_rooms (match_id, user_a_id, user_b_id, last_message_at)
            values (new.id, new.viewer_id, new.candidate_id, now());

            insert into chat_messages (room_id, is_system, body)
            select cr.id, true, '결을 통해 연결되었습니다. 자유롭게 대화를 시작하세요.'
            from chat_rooms cr where cr.match_id = new.id;
        end if;

        new.interest_at := now();
    end if;
    return new;
end;
$$;

revoke all on function sync_pair_interest() from public, anon, authenticated;
grant execute on function sync_pair_interest() to service_role;

create trigger trg_matches_sync_interest before update of viewer_interest on matches
for each row execute function sync_pair_interest();

-- ─────────────────────────────────────────────────────────────
-- polished_output_cache — service_role only (RLS enabled, no policy)
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
-- chat_rooms / chat_messages — participants only
-- ─────────────────────────────────────────────────────────────

create policy rooms_participant on chat_rooms
    for select using (auth.uid() = user_a_id or auth.uid() = user_b_id);

create policy messages_participant_read on chat_messages
    for select using (
        exists (
            select 1 from chat_rooms r
            where r.id = chat_messages.room_id
              and (r.user_a_id = auth.uid() or r.user_b_id = auth.uid())
        )
    );

create policy messages_participant_insert on chat_messages
    for insert with check (
        sender_id = auth.uid()
        and is_system = false
        and exists (
            select 1 from chat_rooms r
            where r.id = chat_messages.room_id
              and (r.user_a_id = auth.uid() or r.user_b_id = auth.uid())
        )
        and char_length(body) between 1 and 200
    );

-- ─────────────────────────────────────────────────────────────
-- operator_review_queue — service_role only
-- ─────────────────────────────────────────────────────────────

-- (RLS enabled, no policy → 일반 user select 차단)
