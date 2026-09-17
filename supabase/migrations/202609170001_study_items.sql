create table if not exists public.study_items (
  owner_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('schedule', 'task', 'note', 'subject', 'exam', 'reminder', 'calendar_category')),
  id text not null,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  primary key (owner_id, kind, id)
);

create index if not exists study_items_owner_updated_idx
  on public.study_items (owner_id, updated_at);

alter table public.study_items enable row level security;

create policy "Users read own items" on public.study_items
  for select to authenticated using (owner_id = (select auth.uid()));
create policy "Users insert own items" on public.study_items
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "Users update own items" on public.study_items
  for update to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

grant select, insert, update on public.study_items to authenticated;
