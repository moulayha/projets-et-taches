-- Projets et tâches : schéma Supabase
-- Toutes les données ne sont lisibles et modifiables que par les comptes
-- dont l'adresse email figure dans public.allowed_users.

create table if not exists public.allowed_users (
  email text primary key check (email = lower(email))
);

-- La fonction de contrôle vit dans un schéma non exposé par l'API
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_allowed()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.allowed_users
    where email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
revoke all on function private.is_allowed() from public, anon;
grant execute on function private.is_allowed() to authenticated;

create table if not exists public.people (
  id text primary key default gen_random_uuid()::text,
  name text not null default '',
  roles text[],                       -- null = proposé dans toutes les listes
  created_at bigint not null default (extract(epoch from now()) * 1000)::bigint
);

create table if not exists public.projects (
  id text primary key default gen_random_uuid()::text,
  code text not null default '',
  name text not null default '',
  status text,
  owners text[] not null default '{}',
  pilots text[] not null default '{}',
  creas text[] not null default '{}',
  billing text,
  start_date date,
  end_date date,
  priority text,
  client text,
  summary text not null default '',
  blocked_by text[] not null default '{}',
  notes text not null default '',
  created_at bigint not null default (extract(epoch from now()) * 1000)::bigint
);

create table if not exists public.tasks (
  id text primary key default gen_random_uuid()::text,
  name text not null default '',
  status text,
  owners text[] not null default '{}',
  due date,
  done_on date,
  priority text,
  tags text[] not null default '{}',
  project text references public.projects(id) on delete set null,
  parent text references public.tasks(id) on delete set null,
  blocked_by text[] not null default '{}',
  notes text not null default '',
  created_at bigint not null default (extract(epoch from now()) * 1000)::bigint
);
create index if not exists tasks_project_idx on public.tasks(project);
create index if not exists tasks_parent_idx on public.tasks(parent);

-- Listes paramétrables (clients, états d'avancement) : une ligne id = 'options'
create table if not exists public.settings (
  id text primary key,
  data jsonb not null default '{}'::jsonb
);

-- Sécurité : RLS partout
alter table public.allowed_users enable row level security;
alter table public.people   enable row level security;
alter table public.projects enable row level security;
alter table public.tasks    enable row level security;
alter table public.settings enable row level security;

-- Chacun peut seulement vérifier s'il est lui-même autorisé
create policy "allowed_users: lire sa propre ligne" on public.allowed_users
  for select to authenticated
  using (email = lower(coalesce(auth.jwt() ->> 'email', '')));

create policy "people: membres autorisés" on public.people
  for all to authenticated using ((select private.is_allowed())) with check ((select private.is_allowed()));
create policy "projects: membres autorisés" on public.projects
  for all to authenticated using ((select private.is_allowed())) with check ((select private.is_allowed()));
create policy "tasks: membres autorisés" on public.tasks
  for all to authenticated using ((select private.is_allowed())) with check ((select private.is_allowed()));
create policy "settings: membres autorisés" on public.settings
  for all to authenticated using ((select private.is_allowed())) with check ((select private.is_allowed()));

-- Mises à jour en direct
alter table public.people   replica identity full;
alter table public.projects replica identity full;
alter table public.tasks    replica identity full;
alter table public.settings replica identity full;
alter publication supabase_realtime add table public.people, public.projects, public.tasks, public.settings;
