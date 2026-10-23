-- Run once in Supabase SQL Editor. Auth user must be created in Authentication > Users.
create table if not exists public.tracker_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null,
  revision bigint not null default 1,
  updated_at timestamptz not null default now(),
  constraint payload_shape check (jsonb_typeof(payload) = 'object')
);
alter table public.tracker_state enable row level security;
revoke all on public.tracker_state from anon;
grant select on public.tracker_state to authenticated;
drop policy if exists tracker_select_own on public.tracker_state;
create policy tracker_select_own on public.tracker_state for select to authenticated using (user_id = (select auth.uid()));
-- Mutations only through the atomic revision-checked RPC below.
revoke insert, update, delete on public.tracker_state from authenticated;
create or replace function public.save_tracker_state(expected_revision bigint, new_payload jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); result_revision bigint;
begin
 if uid is null then raise exception 'Authentication required'; end if;
 if jsonb_typeof(new_payload) <> 'object'
    or jsonb_typeof(new_payload->'supplements') <> 'array'
    or jsonb_typeof(new_payload->'logs') <> 'object'
    or jsonb_typeof(new_payload->'snapshots') <> 'object'
 then raise exception 'Invalid state document'; end if;
 if length(new_payload::text) > 4000000 then raise exception 'State exceeds safety limit'; end if;
 if expected_revision = 0 then
   insert into public.tracker_state(user_id,payload,revision) values(uid,new_payload,1)
   on conflict do nothing returning revision into result_revision;
 else
   update public.tracker_state set payload=new_payload, revision=revision+1, updated_at=now()
   where user_id=uid and revision=expected_revision returning revision into result_revision;
 end if;
 if result_revision is null then raise exception 'Conflict: cloud state was modified in another session. Export changes, then reload.';end if;
 return result_revision;
end $$;
revoke all on function public.save_tracker_state(bigint,jsonb) from public;
revoke all on function public.save_tracker_state(bigint,jsonb) from anon;
grant execute on function public.save_tracker_state(bigint,jsonb) to authenticated;
