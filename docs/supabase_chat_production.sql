-- Production chat hardening for Gracy
-- Run this in Supabase SQL Editor after backing up your current policies.

create table if not exists public.chat_members (
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create index if not exists idx_chat_members_user_id
on public.chat_members (user_id);

insert into public.chat_members (room_id, user_id)
select
  cr.id,
  split_part(cr.room_hash, '_', 1)::uuid as user_id
from public.chat_rooms cr
where split_part(cr.room_hash, '_', 1) <> ''
on conflict (room_id, user_id) do nothing;

insert into public.chat_members (room_id, user_id)
select
  cr.id,
  split_part(cr.room_hash, '_', 2)::uuid as user_id
from public.chat_rooms cr
where split_part(cr.room_hash, '_', 2) <> ''
on conflict (room_id, user_id) do nothing;

alter table public.chat_rooms enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;

drop policy if exists "chat_rooms_select_authenticated" on public.chat_rooms;
drop policy if exists "chat_rooms_insert_authenticated" on public.chat_rooms;
drop policy if exists "chat_members_select_authenticated" on public.chat_members;
drop policy if exists "chat_members_insert_authenticated" on public.chat_members;
drop policy if exists "messages_select_authenticated" on public.messages;
drop policy if exists "messages_insert_authenticated" on public.messages;

create policy "chat_rooms_select_authenticated"
on public.chat_rooms
for select
to authenticated
using (
  exists (
    select 1
    from public.chat_members cm
    where cm.room_id = chat_rooms.id
      and cm.user_id = auth.uid()
  )
);

create policy "chat_rooms_insert_authenticated"
on public.chat_rooms
for insert
to authenticated
with check (true);

create policy "chat_members_select_authenticated"
on public.chat_members
for select
to authenticated
using (user_id = auth.uid());

create policy "chat_members_insert_authenticated"
on public.chat_members
for insert
to authenticated
with check (true);

create policy "messages_select_authenticated"
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.chat_members cm
    where cm.room_id = messages.room_id
      and cm.user_id = auth.uid()
  )
);

create policy "messages_insert_authenticated"
on public.messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1
    from public.chat_members cm
    where cm.room_id = messages.room_id
      and cm.user_id = auth.uid()
  )
);
