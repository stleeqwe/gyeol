-- 결 (Gyeol) — 0006 MVP flow hardening
-- Realtime publication + one chat room per user pair.

do $$
begin
    alter publication supabase_realtime add table matches;
exception when duplicate_object then
    null;
end $$;

do $$
begin
    alter publication supabase_realtime add table chat_rooms;
exception when duplicate_object then
    null;
end $$;

do $$
begin
    alter publication supabase_realtime add table chat_messages;
exception when duplicate_object then
    null;
end $$;

create unique index if not exists idx_chat_rooms_user_pair_unique
on chat_rooms (
    least(user_a_id, user_b_id),
    greatest(user_a_id, user_b_id)
);

create or replace function sync_pair_interest()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    pair_match_id uuid;
    room_id uuid;
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

        if new.viewer_interest = 'interested' and exists (
            select 1 from matches mm
            where mm.viewer_id = new.candidate_id
              and mm.candidate_id = new.viewer_id
              and mm.viewer_interest = 'interested'
        ) then
            select cr.id into room_id
            from chat_rooms cr
            where least(cr.user_a_id, cr.user_b_id) = least(new.viewer_id, new.candidate_id)
              and greatest(cr.user_a_id, cr.user_b_id) = greatest(new.viewer_id, new.candidate_id)
            limit 1;

            if room_id is null then
                insert into chat_rooms (match_id, user_a_id, user_b_id, last_message_at)
                values (new.id, new.viewer_id, new.candidate_id, now())
                returning id into room_id;

                insert into chat_messages (room_id, is_system, body)
                values (room_id, true, '결을 통해 연결되었습니다. 자유롭게 대화를 시작하세요.');
            end if;
        end if;

        new.interest_at := now();
    end if;
    return new;
end;
$$;

revoke all on function sync_pair_interest() from public, anon, authenticated;
grant execute on function sync_pair_interest() to service_role;
