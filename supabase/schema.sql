-- Projets et tâches : schéma Supabase (état actuel)
-- Accès : seuls les comptes de public.app_users peuvent se connecter.
--   admin  : voit et modifie tout, gère les paramètres et les utilisateurs.
--   member : voit les projets où il est responsable, pilote ou créa,
--            et les tâches de ces projets ou dont il est responsable.

create table if not exists public.people (
  id text primary key default gen_random_uuid()::text,
  name text not null default '',
  roles text[],                       -- listes où la personne est proposée (null = toutes)
  created_at bigint not null default (extract(epoch from now()) * 1000)::bigint
);

create table if not exists public.app_users (
  id text primary key references public.people(id) on delete cascade,
  email text not null unique check (email = lower(email)),
  role text not null default 'member' check (role in ('admin','member'))
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

-- Fonctions d'accès, dans un schéma non exposé par l'API
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.my_person() returns text
language sql stable security definer set search_path = '' as $$
  select id from public.app_users where email = lower(coalesce(auth.jwt() ->> 'email', '')) limit 1;
$$;
create or replace function private.is_member() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.app_users where email = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;
create or replace function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.app_users where email = lower(coalesce(auth.jwt() ->> 'email', '')) and role = 'admin');
$$;
create or replace function private.can_see_project(pid text) returns boolean
language sql stable security definer set search_path = '' as $$
  select pid is not null and (
    (select private.is_admin()) or exists (
      select 1 from public.projects p
      where p.id = pid and (select private.my_person()) = any (p.owners || p.pilots || p.creas)
    )
  );
$$;
revoke all on function private.my_person(), private.is_member(), private.is_admin(), private.can_see_project(text) from public, anon;
grant execute on function private.my_person(), private.is_member(), private.is_admin(), private.can_see_project(text) to authenticated;

alter table public.people    enable row level security;
alter table public.app_users enable row level security;
alter table public.projects  enable row level security;
alter table public.tasks     enable row level security;
alter table public.settings  enable row level security;

create policy "app_users: lecture" on public.app_users for select to authenticated
  using ((select private.is_admin()) or email = lower(coalesce(auth.jwt() ->> 'email', '')));
create policy "app_users: admin écrit" on public.app_users for insert to authenticated with check ((select private.is_admin()));
create policy "app_users: admin modifie" on public.app_users for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "app_users: admin supprime" on public.app_users for delete to authenticated using ((select private.is_admin()));

create policy "people: lecture membres" on public.people for select to authenticated using ((select private.is_member()));
create policy "people: admin écrit" on public.people for insert to authenticated with check ((select private.is_admin()));
create policy "people: admin modifie" on public.people for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "people: admin supprime" on public.people for delete to authenticated using ((select private.is_admin()));

create policy "settings: lecture membres" on public.settings for select to authenticated using ((select private.is_member()));
create policy "settings: admin écrit" on public.settings for insert to authenticated with check ((select private.is_admin()));
create policy "settings: admin modifie" on public.settings for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "settings: admin supprime" on public.settings for delete to authenticated using ((select private.is_admin()));

create policy "projects: lecture" on public.projects for select to authenticated
  using ((select private.is_admin()) or (select private.my_person()) = any (owners || pilots || creas));
create policy "projects: admin crée" on public.projects for insert to authenticated with check ((select private.is_admin()));
create policy "projects: modification" on public.projects for update to authenticated
  using ((select private.is_admin()) or (select private.my_person()) = any (owners || pilots || creas))
  with check ((select private.is_admin()) or (select private.my_person()) = any (owners || pilots || creas));
create policy "projects: admin supprime" on public.projects for delete to authenticated using ((select private.is_admin()));

create policy "tasks: lecture" on public.tasks for select to authenticated
  using ((select private.is_admin()) or (select private.my_person()) = any (owners) or private.can_see_project(project));
create policy "tasks: création" on public.tasks for insert to authenticated
  with check ((select private.is_admin()) or (select private.my_person()) = any (owners) or private.can_see_project(project));
create policy "tasks: modification" on public.tasks for update to authenticated
  using ((select private.is_admin()) or (select private.my_person()) = any (owners) or private.can_see_project(project))
  with check ((select private.is_admin()) or (select private.my_person()) = any (owners) or private.can_see_project(project));
create policy "tasks: suppression" on public.tasks for delete to authenticated
  using ((select private.is_admin()) or (select private.my_person()) = any (owners) or private.can_see_project(project));

-- Mises à jour en direct
alter table public.people    replica identity full;
alter table public.app_users replica identity full;
alter table public.projects  replica identity full;
alter table public.tasks     replica identity full;
alter table public.settings  replica identity full;
alter publication supabase_realtime add table public.people, public.app_users, public.projects, public.tasks, public.settings;

-- Premier administrateur (à adapter) :
-- insert into public.people (id, name) values ('u-admin', 'Prénom Nom');
-- insert into public.app_users (id, email, role) values ('u-admin', 'prenom@entreprise.com', 'admin');
