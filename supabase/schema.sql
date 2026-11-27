-- Projets et tâches + module Caisse : schéma Supabase (projet bskzcjhlnmkhafcfnrqo)
-- Régénéré depuis la base réelle le 27/11/2026 (catalogue Postgres) : tables, contraintes,
-- index, fonctions (schémas public et private), vues, déclencheurs, RLS et règles d'accès.
-- Ne pas exécuter tel quel sur une base existante : c'est la référence de l'état réel.
-- Les évolutions du module Caisse sont détaillées dans caisse/sql/ (migrations numérotées).

create schema if not exists private;

-- ---------------------------------------------------------------- Tables
create table if not exists public.activity (
  id bigint generated always as identity not null,
  kind text not null,
  item_id text not null,
  person_id text,
  at bigint default ((EXTRACT(epoch FROM now()) * (1000)::numeric))::bigint not null,
  action text not null,
  changes jsonb default '{}'::jsonb not null,
  constraint activity_pkey PRIMARY KEY (id),
  constraint activity_action_check CHECK ((action = ANY (ARRAY['create'::text, 'update'::text]))),
  constraint activity_kind_check CHECK ((kind = ANY (ARRAY['p'::text, 't'::text])))
);

create table if not exists public.app_users (
  id text not null,
  email text not null,
  role text default 'member'::text not null,
  constraint app_users_email_key UNIQUE (email),
  constraint app_users_pkey PRIMARY KEY (id),
  constraint app_users_email_check CHECK ((email = lower(email))),
  constraint app_users_role_check CHECK ((role = ANY (ARRAY['superadmin'::text, 'admin'::text, 'member'::text, 'billing'::text, 'viewer'::text])))
);

create table if not exists public.caisse_acces (
  person_id text not null,
  niveau text not null,
  created_at timestamp with time zone default now() not null,
  created_by text default private.my_person(),
  constraint caisse_acces_pkey PRIMARY KEY (person_id),
  constraint caisse_acces_niveau_check CHECK ((niveau = ANY (ARRAY['gestionnaire'::text, 'lecture'::text])))
);

create table if not exists public.caisse_alimentations (
  id uuid default gen_random_uuid() not null,
  date_op date default ((now() AT TIME ZONE 'Africa/Casablanca'::text))::date not null,
  montant numeric(12,2) not null,
  origine text default ''::text not null,
  note text default ''::text not null,
  created_by text default private.my_person(),
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint caisse_alimentations_pkey PRIMARY KEY (id),
  constraint caisse_alimentations_montant_check CHECK ((montant > (0)::numeric))
);

create table if not exists public.caisse_avances (
  id uuid default gen_random_uuid() not null,
  date_op date default ((now() AT TIME ZONE 'Africa/Casablanca'::text))::date not null,
  ouvrier_id uuid not null,
  project_id text,
  montant numeric(12,2) not null,
  note text default ''::text not null,
  created_by text default private.my_person(),
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint caisse_avances_pkey PRIMARY KEY (id),
  constraint caisse_avances_montant_check CHECK ((montant > (0)::numeric))
);

create table if not exists public.caisse_categories (
  id uuid default gen_random_uuid() not null,
  nom text not null,
  mots_cles text[] default '{}'::text[] not null,
  icone text default ''::text not null,
  ordre integer default 0 not null,
  actif boolean default true not null,
  constraint caisse_categories_nom_key UNIQUE (nom),
  constraint caisse_categories_pkey PRIMARY KEY (id)
);

create table if not exists public.caisse_conversations (
  ouvrier_id uuid not null,
  etape text not null,
  options jsonb default '[]'::jsonb not null,
  maj timestamp with time zone default now() not null,
  depense_ids uuid[] default '{}'::uuid[] not null,
  constraint caisse_conversations_pkey PRIMARY KEY (ouvrier_id),
  constraint caisse_conversations_etape_check CHECK ((etape = ANY (ARRAY['projet'::text, 'montant'::text])))
);

create table if not exists public.caisse_depenses (
  id uuid default gen_random_uuid() not null,
  date_op date default ((now() AT TIME ZONE 'Africa/Casablanca'::text))::date not null,
  project_id text,
  categorie_id uuid,
  montant numeric(12,2),
  libelle text default ''::text not null,
  payeur text default 'ouvrier'::text not null,
  ouvrier_id uuid,
  statut text default 'a_valider'::text not null,
  source text default 'saisie'::text not null,
  justificatif text,
  message_id uuid,
  validee_par text,
  validee_le timestamp with time zone,
  created_by text default private.my_person(),
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint caisse_depenses_pkey PRIMARY KEY (id),
  constraint caisse_depenses_montant_check CHECK (((montant IS NULL) OR (montant > (0)::numeric))),
  constraint caisse_depenses_payeur_check CHECK ((payeur = ANY (ARRAY['ouvrier'::text, 'direct'::text]))),
  constraint caisse_depenses_payeur_ck CHECK (((payeur = 'direct'::text) OR (ouvrier_id IS NOT NULL))),
  constraint caisse_depenses_source_check CHECK ((source = ANY (ARRAY['whatsapp_texte'::text, 'whatsapp_vocal'::text, 'whatsapp_photo'::text, 'saisie'::text, 'import'::text]))),
  constraint caisse_depenses_statut_check CHECK ((statut = ANY (ARRAY['a_valider'::text, 'validee'::text, 'rejetee'::text]))),
  constraint caisse_depenses_validee_ck CHECK (((statut <> 'validee'::text) OR ((montant IS NOT NULL) AND (project_id IS NOT NULL) AND (categorie_id IS NOT NULL))))
);

create table if not exists public.caisse_historique (
  id bigint generated always as identity not null,
  at timestamp with time zone default now() not null,
  person_id text,
  table_nom text not null,
  ligne_id text not null,
  action text not null,
  avant jsonb,
  apres jsonb,
  constraint caisse_historique_pkey PRIMARY KEY (id),
  constraint caisse_historique_action_check CHECK ((action = ANY (ARRAY['create'::text, 'update'::text, 'delete'::text])))
);

create table if not exists public.caisse_messages (
  id uuid default gen_random_uuid() not null,
  recu_le timestamp with time zone default now() not null,
  telephone text,
  ouvrier_id uuid,
  type text not null,
  texte text,
  media_path text,
  analyse_ia jsonb,
  wa_message_id text,
  wa_user_id text,
  profil_nom text,
  media_hash text,
  constraint caisse_messages_wa_message_id_key UNIQUE (wa_message_id),
  constraint caisse_messages_pkey PRIMARY KEY (id),
  constraint caisse_messages_expediteur_ck CHECK (((telephone IS NOT NULL) OR (wa_user_id IS NOT NULL))),
  constraint caisse_messages_type_check CHECK ((type = ANY (ARRAY['texte'::text, 'vocal'::text, 'photo'::text, 'autre'::text])))
);

create table if not exists public.caisse_ouvriers (
  id uuid default gen_random_uuid() not null,
  nom text not null,
  telephone text,
  actif boolean default true not null,
  note text default ''::text not null,
  created_at timestamp with time zone default now() not null,
  wa_user_id text,
  constraint caisse_ouvriers_telephone_key UNIQUE (telephone),
  constraint caisse_ouvriers_pkey PRIMARY KEY (id),
  constraint caisse_ouvriers_nom_check CHECK ((btrim(nom) <> ''::text)),
  constraint caisse_ouvriers_telephone_check CHECK ((telephone ~ '^\+[0-9]{8,15}$'::text))
);

create table if not exists public.caisse_projets_reglages (
  project_id text not null,
  nom_court text,
  budget numeric(12,2),
  masque_whatsapp boolean default false not null,
  constraint caisse_projets_reglages_nom_court_key UNIQUE (nom_court),
  constraint caisse_projets_reglages_pkey PRIMARY KEY (project_id),
  constraint caisse_projets_reglages_budget_check CHECK (((budget IS NULL) OR (budget >= (0)::numeric))),
  constraint caisse_projets_reglages_nom_court_check CHECK (((nom_court IS NULL) OR (btrim(nom_court) <> ''::text)))
);

create table if not exists public.caisse_reglages (
  id text not null,
  data jsonb default '{}'::jsonb not null,
  constraint caisse_reglages_pkey PRIMARY KEY (id)
);

create table if not exists public.countdown_secret (
  id integer default 1 not null,
  pin_hash text not null,
  constraint countdown_secret_pkey PRIMARY KEY (id),
  constraint countdown_secret_id_check CHECK ((id = 1))
);

create table if not exists public.countdown_state (
  id integer default 1 not null,
  status text default 'idle'::text not null,
  duration_ms bigint default 300000 not null,
  end_at timestamp with time zone,
  remaining_ms bigint default 300000 not null,
  updated_at timestamp with time zone default now() not null,
  constraint countdown_state_pkey PRIMARY KEY (id),
  constraint countdown_state_id_check CHECK ((id = 1)),
  constraint countdown_state_status_check CHECK ((status = ANY (ARRAY['idle'::text, 'running'::text, 'paused'::text])))
);

create table if not exists public.people (
  id text default (gen_random_uuid())::text not null,
  name text default ''::text not null,
  roles text[],
  created_at bigint default ((EXTRACT(epoch FROM now()) * (1000)::numeric))::bigint not null,
  color text,
  constraint people_pkey PRIMARY KEY (id)
);

create table if not exists public.projects (
  id text default (gen_random_uuid())::text not null,
  code text default ''::text not null,
  name text default ''::text not null,
  status text,
  owners text[] default '{}'::text[] not null,
  pilots text[] default '{}'::text[] not null,
  creas text[] default '{}'::text[] not null,
  billing text,
  start_date date,
  end_date date,
  priority text,
  client text,
  summary text default ''::text not null,
  blocked_by text[] default '{}'::text[] not null,
  notes text default ''::text not null,
  created_at bigint default ((EXTRACT(epoch FROM now()) * (1000)::numeric))::bigint not null,
  created_by text,
  archived_at bigint,
  drive_url text,
  constraint projects_pkey PRIMARY KEY (id)
);

create table if not exists public.settings (
  id text not null,
  data jsonb default '{}'::jsonb not null,
  constraint settings_pkey PRIMARY KEY (id)
);

create table if not exists public.tasks (
  id text default (gen_random_uuid())::text not null,
  name text default ''::text not null,
  status text,
  owners text[] default '{}'::text[] not null,
  due date,
  done_on date,
  priority text,
  tags text[] default '{}'::text[] not null,
  project text,
  parent text,
  blocked_by text[] default '{}'::text[] not null,
  notes text default ''::text not null,
  created_at bigint default ((EXTRACT(epoch FROM now()) * (1000)::numeric))::bigint not null,
  archived_at bigint,
  constraint tasks_pkey PRIMARY KEY (id)
);

-- ---------------------------------------------------------------- Clés étrangères
alter table public.app_users add constraint app_users_id_fkey FOREIGN KEY (id) REFERENCES people(id) ON DELETE CASCADE;
alter table public.caisse_acces add constraint caisse_acces_person_id_fkey FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE;
alter table public.caisse_avances add constraint caisse_avances_ouvrier_id_fkey FOREIGN KEY (ouvrier_id) REFERENCES caisse_ouvriers(id) ON DELETE RESTRICT;
alter table public.caisse_avances add constraint caisse_avances_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE RESTRICT;
alter table public.caisse_conversations add constraint caisse_conversations_ouvrier_id_fkey FOREIGN KEY (ouvrier_id) REFERENCES caisse_ouvriers(id) ON DELETE CASCADE;
alter table public.caisse_depenses add constraint caisse_depenses_categorie_id_fkey FOREIGN KEY (categorie_id) REFERENCES caisse_categories(id) ON DELETE RESTRICT;
alter table public.caisse_depenses add constraint caisse_depenses_message_id_fkey FOREIGN KEY (message_id) REFERENCES caisse_messages(id) ON DELETE SET NULL;
alter table public.caisse_depenses add constraint caisse_depenses_ouvrier_id_fkey FOREIGN KEY (ouvrier_id) REFERENCES caisse_ouvriers(id) ON DELETE RESTRICT;
alter table public.caisse_depenses add constraint caisse_depenses_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE RESTRICT;
alter table public.caisse_messages add constraint caisse_messages_ouvrier_id_fkey FOREIGN KEY (ouvrier_id) REFERENCES caisse_ouvriers(id) ON DELETE SET NULL;
alter table public.caisse_projets_reglages add constraint caisse_projets_reglages_project_id_fkey FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;
alter table public.tasks add constraint tasks_parent_fkey FOREIGN KEY (parent) REFERENCES tasks(id) ON DELETE SET NULL;
alter table public.tasks add constraint tasks_project_fkey FOREIGN KEY (project) REFERENCES projects(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------- Index
CREATE INDEX activity_item_at ON public.activity USING btree (item_id, at DESC);
CREATE INDEX caisse_avances_ouvrier_idx ON public.caisse_avances USING btree (ouvrier_id);
CREATE INDEX caisse_avances_project_idx ON public.caisse_avances USING btree (project_id);
CREATE INDEX caisse_depenses_categorie_idx ON public.caisse_depenses USING btree (categorie_id);
CREATE INDEX caisse_depenses_message_idx ON public.caisse_depenses USING btree (message_id);
CREATE INDEX caisse_depenses_ouvrier_idx ON public.caisse_depenses USING btree (ouvrier_id);
CREATE INDEX caisse_depenses_project_idx ON public.caisse_depenses USING btree (project_id);
CREATE INDEX caisse_depenses_statut_idx ON public.caisse_depenses USING btree (statut);
CREATE INDEX caisse_historique_ligne_idx ON public.caisse_historique USING btree (table_nom, ligne_id);
CREATE INDEX caisse_messages_inconnus_idx ON public.caisse_messages USING btree (recu_le DESC) WHERE (ouvrier_id IS NULL);
CREATE INDEX caisse_messages_media_hash_idx ON public.caisse_messages USING btree (media_hash) WHERE (media_hash IS NOT NULL);
CREATE INDEX caisse_messages_ouvrier_idx ON public.caisse_messages USING btree (ouvrier_id);
CREATE UNIQUE INDEX caisse_ouvriers_wa_user_id_key ON public.caisse_ouvriers USING btree (wa_user_id) WHERE (wa_user_id IS NOT NULL);
CREATE INDEX tasks_parent_idx ON public.tasks USING btree (parent);
CREATE INDEX tasks_project_idx ON public.tasks USING btree (project);

-- ---------------------------------------------------------------- Fonctions
CREATE OR REPLACE FUNCTION private.caisse_compte_protege(pid text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (select 1 from public.app_users u where u.id = pid and u.role = 'billing')
      or exists (select 1 from public.caisse_acces a where a.person_id = pid);
$function$
;

CREATE OR REPLACE FUNCTION private.caisse_ecriture()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select coalesce(private.caisse_niveau() in ('super', 'gestionnaire'), false);
$function$
;

CREATE OR REPLACE FUNCTION private.caisse_journal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if tg_op = 'INSERT' then
    insert into public.caisse_historique (person_id, table_nom, ligne_id, action, apres)
      values (private.my_person(), tg_table_name, (to_jsonb(new) ->> (tg_argv[0])), 'create', to_jsonb(new));
    return new;
  elsif tg_op = 'UPDATE' then
    insert into public.caisse_historique (person_id, table_nom, ligne_id, action, avant, apres)
      values (private.my_person(), tg_table_name, (to_jsonb(new) ->> (tg_argv[0])), 'update', to_jsonb(old), to_jsonb(new));
    return new;
  else
    insert into public.caisse_historique (person_id, table_nom, ligne_id, action, avant)
      values (private.my_person(), tg_table_name, (to_jsonb(old) ->> (tg_argv[0])), 'delete', to_jsonb(old));
    return old;
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION private.caisse_lecture()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select private.caisse_niveau() is not null;
$function$
;

CREATE OR REPLACE FUNCTION private.caisse_maj()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  new.updated_at := now();
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION private.caisse_niveau()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case
    when u.role = 'superadmin' then 'super'
    when u.role = 'admin'      then null
    when u.role = 'billing'    then 'gestionnaire'
    else (select a.niveau from public.caisse_acces a where a.person_id = u.id)
  end
  from public.app_users u
  where u.email = lower(coalesce(auth.jwt() ->> 'email', ''))
  limit 1;
$function$
;

CREATE OR REPLACE FUNCTION private.caisse_projet_actif(pid text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.projects p
    where p.id = pid and p.archived_at is null
      and p.status = any (coalesce(
        (select array_agg(x) from public.caisse_reglages r, jsonb_array_elements_text(r.data -> 'statuts_actifs') x where r.id = 'options'),
        array[]::text[]))
  );
$function$
;

CREATE OR REPLACE FUNCTION private.caisse_validation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.statut = 'validee' and (tg_op = 'INSERT' or old.statut is distinct from 'validee') then
    new.validee_par := private.my_person();
    new.validee_le  := now();
  elsif new.statut <> 'validee' then
    new.validee_par := null;
    new.validee_le  := null;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION private.caisse_verif_projet()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.project_id is not null
     and (tg_op = 'INSERT' or new.project_id is distinct from old.project_id)
     and not private.caisse_projet_actif(new.project_id) then
    raise exception 'Ce projet n''est pas actif pour la caisse' using errcode = 'check_violation';
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION private.caisse_verrou_app_users()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'authenticated' or private.is_super() then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op in ('UPDATE', 'DELETE') and (old.role = 'billing' or exists (select 1 from public.caisse_acces a where a.person_id = old.id)) then
    raise exception 'Seul un super admin peut modifier un compte qui a accès à la caisse' using errcode = '42501';
  end if;
  if tg_op in ('INSERT', 'UPDATE') and new.role = 'billing' then
    raise exception 'Seul un super admin peut donner le rôle facturation' using errcode = '42501';
  end if;
  if tg_op = 'INSERT' and exists (select 1 from public.caisse_acces a where a.person_id = new.id) then
    raise exception 'Seul un super admin peut créer un compte qui a accès à la caisse' using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' and old.id = private.my_person() and new.role is distinct from old.role then
    raise exception 'Tu ne peux pas modifier ton propre rôle' using errcode = '42501';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $function$
;

CREATE OR REPLACE FUNCTION private.caisse_verrou_people()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if coalesce(auth.jwt() ->> 'role', '') = 'authenticated' and not private.is_super()
     and private.caisse_compte_protege(old.id) then
    raise exception 'Seul un super admin peut supprimer une personne qui a accès à la caisse' using errcode = '42501';
  end if;
  return old;
end $function$
;

CREATE OR REPLACE FUNCTION private.can_bill()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (select 1 from public.app_users where email = lower(coalesce(auth.jwt() ->> 'email', '')) and role in ('superadmin','admin','billing'));
$function$
;

CREATE OR REPLACE FUNCTION private.can_edit()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (select 1 from public.app_users where email = lower(coalesce(auth.jwt() ->> 'email', '')) and role in ('superadmin','admin','member'));
$function$
;

CREATE OR REPLACE FUNCTION private.digest_email(pid text, force boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  d0 date := (now() at time zone 'Africa/Casablanca')::date;
  d1 date := d0 + 6;
  em text; nm text;
  done_ps text[];
  late text; week text; projs text;
  nlate int; nweek int; nproj int;
  td text := 'padding:7px 10px;border-bottom:1px solid #eceae4;font-size:14px;vertical-align:top';
  sec text; body text; subj text;
begin
  select u.email, p.name into em, nm from public.app_users u join public.people p on p.id = u.id where u.id = pid;
  if em is null then return null; end if;
  done_ps := coalesce((select array_agg(x ->> 'n') from public.settings s, jsonb_array_elements(s.data -> 'pstat') x
                       where s.id = 'options' and x ->> 'g' = 'done'), array['Terminé', 'Annulé']);

  select count(*), string_agg(format('<tr><td style="%s">%s</td><td style="%s;color:#6b6b6b">%s</td><td style="%s;color:#b3362a;white-space:nowrap">%s · %s j de retard</td></tr>',
           td, private.h(coalesce(nullif(t.name, ''), 'Sans titre')), td, private.h(coalesce(pr.name, '')), td, to_char(t.due, 'DD/MM'), d0 - t.due), '' order by t.due)
    into nlate, late
  from public.tasks t left join public.projects pr on pr.id = t.project
  where pid = any(t.owners) and t.archived_at is null and t.status is distinct from 'Terminé' and t.due < d0;

  select count(*), string_agg(format('<tr><td style="%s">%s</td><td style="%s;color:#6b6b6b">%s</td><td style="%s;white-space:nowrap">%s</td></tr>',
           td, private.h(coalesce(nullif(t.name, ''), 'Sans titre')), td, private.h(coalesce(pr.name, '')), td,
           case when t.due = d0 then 'Aujourd’hui' else to_char(t.due, 'DD/MM') end), '' order by t.due)
    into nweek, week
  from public.tasks t left join public.projects pr on pr.id = t.project
  where pid = any(t.owners) and t.archived_at is null and t.status is distinct from 'Terminé' and t.due between d0 and d1;

  select count(*), string_agg(format('<tr><td style="%s">%s</td><td style="%s;color:#6b6b6b">%s</td><td style="%s;white-space:nowrap">%s</td></tr>',
           td, private.h(coalesce(nullif(pr.name, ''), 'Sans titre')), td, private.h(coalesce(pr.client, '')), td,
           case when pr.start_date between d0 and d1 and pr.end_date is not null and pr.end_date <> pr.start_date then 'Début ' || to_char(pr.start_date, 'DD/MM') || ' → ' || to_char(pr.end_date, 'DD/MM')
                when pr.start_date between d0 and d1 then 'Le ' || to_char(pr.start_date, 'DD/MM')
                else 'Fin ' || to_char(pr.end_date, 'DD/MM') end), '' order by coalesce(pr.start_date, pr.end_date))
    into nproj, projs
  from public.projects pr
  where pr.archived_at is null and not (coalesce(pr.status, '') = any(done_ps))
    and (pid = any(pr.owners) or pid = any(pr.pilots) or pid = any(pr.creas) or pr.created_by = pid)
    and (pr.start_date between d0 and d1 or pr.end_date between d0 and d1);

  if nlate + nweek + nproj = 0 and not force then return null; end if;

  sec := 'margin:26px 0 8px;font-size:16px;font-family:Arial,sans-serif';
  body := '<div style="font-family:Arial,Helvetica,sans-serif;color:#1c2321;max-width:640px;margin:0 auto">'
    || '<div style="background:#0f6b66;color:#fff;padding:18px 22px;border-radius:10px 10px 0 0"><div style="font-size:12px;letter-spacing:2px;opacity:.85">WEEKLY STATUS</div>'
    || '<div style="font-size:20px;font-weight:bold;margin-top:4px">Ta semaine du ' || to_char(d0, 'DD/MM') || ' au ' || to_char(d1, 'DD/MM') || '</div></div>'
    || '<div style="border:1px solid #e0e5e3;border-top:0;border-radius:0 0 10px 10px;padding:6px 22px 22px">'
    || '<p style="font-size:15px">Bonjour ' || private.h(split_part(coalesce(nm, ''), ' ', 1)) || ',</p>';
  if nlate > 0 then
    body := body || '<h2 style="' || sec || ';color:#b3362a">En retard (' || nlate || ')</h2><table style="width:100%;border-collapse:collapse">' || late || '</table>';
  end if;
  if nweek > 0 then
    body := body || '<h2 style="' || sec || '">À faire cette semaine (' || nweek || ')</h2><table style="width:100%;border-collapse:collapse">' || week || '</table>';
  end if;
  if nproj > 0 then
    body := body || '<h2 style="' || sec || '">Tes projets cette semaine (' || nproj || ')</h2><table style="width:100%;border-collapse:collapse">' || projs || '</table>';
  end if;
  if nlate + nweek + nproj = 0 then
    body := body || '<p style="font-size:14px;color:#6b6b6b">Rien de prévu pour toi cette semaine : aucune tâche en retard, aucune échéance, aucun projet qui commence ou se termine.</p>';
  end if;
  body := body || '<p style="margin-top:26px"><a href="https://status.clicevent.ma" style="background:#0f6b66;color:#fff;text-decoration:none;padding:10px 18px;border-radius:8px;font-size:14px;display:inline-block">Ouvrir WEEKLY STATUS</a></p>'
    || '<p style="font-size:12px;color:#8a8f8d;margin-top:22px">Email automatique envoyé chaque semaine aux membres de l’équipe. Les réglages se trouvent dans Paramètres → Email hebdomadaire.</p></div></div>';

  subj := 'Ta semaine : ' || coalesce(nullif(concat_ws(' · ',
         case when nweek + nlate > 0 then (nweek + nlate) || ' tâche' || case when nweek + nlate > 1 then 's' else '' end
              || case when nlate > 0 then ' dont ' || nlate || ' en retard' else '' end end,
         case when nproj > 0 then nproj || ' projet' || case when nproj > 1 then 's' else '' end end), ''), 'rien de prévu');
  return jsonb_build_object('from', 'WEEKLY STATUS <weekly-status@ownload.net>', 'to', jsonb_build_array(em), 'subject', subj, 'html', body);
end $function$
;

CREATE OR REPLACE FUNCTION private.digest_tick()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  cfg jsonb; st jsonb; loc timestamp := now() at time zone 'Africa/Casablanca'; pids text[]; r jsonb;
begin
  select data -> 'digest' into cfg from public.settings where id = 'options';
  if cfg is null or not coalesce((cfg ->> 'enabled')::boolean, false) then return; end if;
  if extract(isodow from loc)::int <> coalesce((cfg ->> 'day')::int, 1) then return; end if;
  if extract(hour from loc)::int <> coalesce((cfg ->> 'hour')::int, 8) then return; end if;
  select data into st from public.settings where id = 'digest_state';
  if st ->> 'lastDate' = loc::date::text then return; end if;
  select array_agg(x) into pids from jsonb_array_elements_text(coalesce(cfg -> 'recipients', '[]'::jsonb)) x;
  r := private.send_digest(pids, 'auto');
  insert into public.settings (id, data) values ('digest_state',
    jsonb_build_object('lastDate', loc::date::text, 'lastAt', (extract(epoch from now()) * 1000)::bigint, 'lastCount', coalesce((r ->> 'sent')::int, 0)))
  on conflict (id) do update set data = excluded.data;
end $function$
;

CREATE OR REPLACE FUNCTION private.h(t text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select replace(replace(replace(replace(coalesce(t, ''), '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;')
$function$
;

CREATE OR REPLACE FUNCTION private.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (select 1 from public.app_users where email = lower(coalesce(auth.jwt() ->> 'email', '')) and role in ('admin','superadmin'));
$function$
;

CREATE OR REPLACE FUNCTION private.is_allowed()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.allowed_users
    where email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$function$
;

CREATE OR REPLACE FUNCTION private.is_member()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (select 1 from public.app_users where email = lower(coalesce(auth.jwt() ->> 'email', '')));
$function$
;

CREATE OR REPLACE FUNCTION private.is_super()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (select 1 from public.app_users where email = lower(coalesce(auth.jwt() ->> 'email', '')) and role = 'superadmin');
$function$
;

CREATE OR REPLACE FUNCTION private.log_activity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  ch jsonb := '{}'::jsonb; k text; o jsonb; n jsonb;
  knd text := case when tg_table_name = 'projects' then 'p' else 't' end;
begin
  if tg_op = 'DELETE' then
    delete from public.activity where item_id = old.id;
    return old;
  end if;
  if tg_op = 'INSERT' then
    insert into public.activity (kind, item_id, person_id, action) values (knd, new.id, private.my_person(), 'create');
    return new;
  end if;
  o := to_jsonb(old); n := to_jsonb(new);
  for k in select jsonb_object_keys(n) loop
    continue when k in ('id', 'created_at');
    if (o -> k) is distinct from (n -> k) then
      if k in ('notes', 'summary') then
        ch := ch || jsonb_build_object(k, jsonb_build_array(null, null));
      else
        ch := ch || jsonb_build_object(k, jsonb_build_array(o -> k, n -> k));
      end if;
    end if;
  end loop;
  if ch <> '{}'::jsonb then
    insert into public.activity (kind, item_id, person_id, action, changes) values (knd, new.id, private.my_person(), 'update', ch);
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION private.my_person()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select id from public.app_users where email = lower(coalesce(auth.jwt() ->> 'email', '')) limit 1;
$function$
;

CREATE OR REPLACE FUNCTION private.send_digest(pids text[], kind text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  emails jsonb := '[]'::jsonb; e jsonb; k text; rid bigint; n int := 0; pid text;
begin
  select decrypted_secret into k from vault.decrypted_secrets where name = 'resend_api_key' limit 1;
  if k is null then return jsonb_build_object('ok', false, 'error', 'no_key'); end if;
  foreach pid in array coalesce(pids, array[]::text[]) loop
    e := private.digest_email(pid, kind = 'test');
    if e is not null then emails := emails || jsonb_build_array(e); n := n + 1; end if;
  end loop;
  if n > 0 then
    select net.http_post(url := 'https://api.resend.com/emails/batch',
                         body := emails,
                         headers := jsonb_build_object('Authorization', 'Bearer ' || k, 'Content-Type', 'application/json'),
                         timeout_milliseconds := 15000) into rid;
  end if;
  insert into private.digest_log (kind, recipients, request_id) values (kind, n, rid);
  return jsonb_build_object('ok', true, 'sent', n, 'request_id', rid);
end $function$
;

CREATE OR REPLACE FUNCTION public.caisse_bot_projets()
 RETURNS TABLE(id text, code text, name text, client text, nom_court text, masque_whatsapp boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select p.id, p.code, p.name, p.client, r.nom_court, coalesce(r.masque_whatsapp, false)
  from public.projects p
  left join public.caisse_projets_reglages r on r.project_id = p.id
  where private.caisse_projet_actif(p.id)
  order by coalesce(r.nom_court, p.name);
$function$
;

CREATE OR REPLACE FUNCTION public.caisse_mon_acces()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select private.caisse_niveau();
$function$
;

CREATE OR REPLACE FUNCTION public.countdown_check_pin(p_pin text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not exists (select 1 from public.countdown_secret s where s.pin_hash = extensions.crypt(p_pin, s.pin_hash)) then
    raise exception 'PIN incorrect' using errcode = '28000';
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.countdown_control(p_pin text, p_action text, p_duration_ms bigint DEFAULT NULL::bigint)
 RETURNS countdown_state
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare st public.countdown_state;
begin
  perform public.countdown_check_pin(p_pin);
  select * into st from public.countdown_state where id = 1 for update;

  if p_action = 'start' then
    if p_duration_ms is null or p_duration_ms < 1000 or p_duration_ms > 360000000 then
      raise exception 'Durée invalide';
    end if;
    update public.countdown_state set status='running', duration_ms=p_duration_ms,
      remaining_ms=p_duration_ms, end_at = now() + make_interval(secs => p_duration_ms/1000.0), updated_at=now()
      where id=1 returning * into st;
  elsif p_action = 'pause' and st.status = 'running' then
    update public.countdown_state set status='paused',
      remaining_ms = greatest(0, (extract(epoch from (st.end_at - now()))*1000)::bigint),
      end_at=null, updated_at=now() where id=1 returning * into st;
  elsif p_action = 'resume' and st.status = 'paused' then
    update public.countdown_state set status='running',
      end_at = now() + make_interval(secs => st.remaining_ms/1000.0), updated_at=now()
      where id=1 returning * into st;
  elsif p_action = 'reset' then
    update public.countdown_state set status='idle', end_at=null,
      duration_ms = coalesce(p_duration_ms, st.duration_ms),
      remaining_ms = coalesce(p_duration_ms, st.duration_ms), updated_at=now()
      where id=1 returning * into st;
  elsif p_action = 'check' then
    null;
  end if;
  return st;
end $function$
;

CREATE OR REPLACE FUNCTION public.countdown_server_now()
 RETURNS timestamp with time zone
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$ select now() $function$
;

CREATE OR REPLACE FUNCTION public.digest_check(rid bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r record;
begin
  if not private.is_admin() then raise exception 'Réservé aux administrateurs' using errcode = '42501'; end if;
  select status_code, error_msg, left(content, 400) as content into r from net._http_response where id = rid;
  if not found then return jsonb_build_object('pending', true); end if;
  return jsonb_build_object('pending', false, 'status', r.status_code, 'error', r.error_msg, 'content', r.content);
end $function$
;

CREATE OR REPLACE FUNCTION public.send_digest_test()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me text := private.my_person();
begin
  if not private.is_admin() or me is null then raise exception 'Réservé aux administrateurs' using errcode = '42501'; end if;
  return private.send_digest(array[me], 'test');
end $function$
;

CREATE OR REPLACE FUNCTION public.set_billing(pid text, val text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not (private.can_bill() or exists (select 1 from public.projects p where p.id = pid and private.can_edit() and p.created_by = private.my_person())) then
    raise exception 'Action non autorisée' using errcode = '42501';
  end if;
  if val is not null and length(val) > 100 then raise exception 'Valeur trop longue' using errcode = '22001'; end if;
  update public.projects set billing = nullif(val, '') where id = pid;
end $function$
;

CREATE OR REPLACE FUNCTION public.set_client_info(cname text, rs text, ice text, addr text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not private.can_bill() then raise exception 'Action non autorisée' using errcode = '42501'; end if;
  if length(coalesce(rs,'')) > 300 or length(coalesce(ice,'')) > 50 or length(coalesce(addr,'')) > 500 then
    raise exception 'Valeur trop longue' using errcode = '22001';
  end if;
  update public.settings s set data = jsonb_set(s.data, '{clients}', (
      select coalesce(jsonb_agg(case when c ->> 'n' = cname
               then (c - 'rs' - 'ice' - 'addr') || jsonb_strip_nulls(jsonb_build_object('rs', nullif(btrim(rs), ''), 'ice', nullif(btrim(ice), ''), 'addr', nullif(btrim(addr), '')))
               else c end order by ord), '[]'::jsonb)
      from jsonb_array_elements(coalesce(s.data -> 'clients', '[]'::jsonb)) with ordinality t(c, ord)))
  where s.id = 'options';
end $function$
;

CREATE OR REPLACE FUNCTION public.set_project_archived(pid text, archive boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  cur bigint; ts bigint := (extract(epoch from now()) * 1000)::bigint; n int := 0;
begin
  if not (private.can_bill() or exists (select 1 from public.projects p where p.id = pid and private.can_edit() and p.created_by = private.my_person())) then
    raise exception 'Action non autorisée' using errcode = '42501';
  end if;
  select archived_at into cur from public.projects where id = pid;
  if not found then raise exception 'Projet introuvable' using errcode = 'P0002'; end if;
  if archive then
    if cur is not null then return jsonb_build_object('ok', true, 'tasks', 0, 'archived_at', cur); end if;
    update public.projects set archived_at = ts where id = pid;
    update public.tasks set archived_at = ts where project = pid and archived_at is null;
    get diagnostics n = row_count;
    return jsonb_build_object('ok', true, 'tasks', n, 'archived_at', ts);
  else
    if cur is null then return jsonb_build_object('ok', true, 'tasks', 0); end if;
    update public.projects set archived_at = null where id = pid;
    -- on ramène les tâches archivées en même temps que le projet
    update public.tasks set archived_at = null where project = pid and archived_at = cur;
    get diagnostics n = row_count;
    return jsonb_build_object('ok', true, 'tasks', n);
  end if;
end $function$
;

-- ---------------------------------------------------------------- Vues
create or replace view public.caisse_couts_projets with (security_invoker=true) as
 SELECT d.project_id,
    p.name AS projet,
    p.status,
    c.nom AS categorie,
    sum(d.montant) AS total,
    count(*) AS nb_lignes
   FROM caisse_depenses d
     JOIN projects p ON p.id = d.project_id
     LEFT JOIN caisse_categories c ON c.id = d.categorie_id
  WHERE d.statut = 'validee'::text
  GROUP BY d.project_id, p.name, p.status, c.nom;

create or replace view public.caisse_projets_actifs with (security_invoker=true) as
 SELECT p.id,
    p.code,
    p.name,
    p.client,
    p.status,
    r.nom_court,
    r.budget,
    COALESCE(r.masque_whatsapp, false) AS masque_whatsapp
   FROM projects p
     LEFT JOIN caisse_projets_reglages r ON r.project_id = p.id
  WHERE private.caisse_lecture() AND private.caisse_projet_actif(p.id);

create or replace view public.caisse_solde_principal with (security_invoker=true) as
 SELECT a.total AS alimentations,
    v.total AS avances,
    d.total AS depenses_directes,
    a.total - v.total - d.total AS solde
   FROM ( SELECT COALESCE(sum(caisse_alimentations.montant), 0::numeric) AS total
           FROM caisse_alimentations) a,
    ( SELECT COALESCE(sum(caisse_avances.montant), 0::numeric) AS total
           FROM caisse_avances) v,
    ( SELECT COALESCE(sum(caisse_depenses.montant), 0::numeric) AS total
           FROM caisse_depenses
          WHERE caisse_depenses.payeur = 'direct'::text AND caisse_depenses.statut = 'validee'::text) d
  WHERE private.caisse_lecture();

create or replace view public.caisse_soldes_ouvriers with (security_invoker=true) as
 SELECT o.id AS ouvrier_id,
    o.nom,
    o.actif,
    COALESCE(av.total, 0::numeric) AS avances,
    COALESCE(dp.total, 0::numeric) AS depenses,
    COALESCE(av.total, 0::numeric) - COALESCE(dp.total, 0::numeric) AS solde,
    COALESCE(dp.a_valider, 0::bigint) AS nb_a_valider
   FROM caisse_ouvriers o
     LEFT JOIN ( SELECT caisse_avances.ouvrier_id,
            sum(caisse_avances.montant) AS total
           FROM caisse_avances
          GROUP BY caisse_avances.ouvrier_id) av ON av.ouvrier_id = o.id
     LEFT JOIN ( SELECT caisse_depenses.ouvrier_id,
            sum(caisse_depenses.montant) FILTER (WHERE caisse_depenses.statut = 'validee'::text) AS total,
            count(*) FILTER (WHERE caisse_depenses.statut = 'a_valider'::text) AS a_valider
           FROM caisse_depenses
          WHERE caisse_depenses.payeur = 'ouvrier'::text
          GROUP BY caisse_depenses.ouvrier_id) dp ON dp.ouvrier_id = o.id;

-- ---------------------------------------------------------------- Déclencheurs
CREATE TRIGGER caisse_verrou BEFORE INSERT OR DELETE OR UPDATE ON public.app_users FOR EACH ROW EXECUTE FUNCTION private.caisse_verrou_app_users();
CREATE TRIGGER caisse_journal AFTER INSERT OR DELETE OR UPDATE ON public.caisse_acces FOR EACH ROW EXECUTE FUNCTION private.caisse_journal('person_id');
CREATE TRIGGER caisse_alim_maj BEFORE UPDATE ON public.caisse_alimentations FOR EACH ROW EXECUTE FUNCTION private.caisse_maj();
CREATE TRIGGER caisse_journal AFTER INSERT OR DELETE OR UPDATE ON public.caisse_alimentations FOR EACH ROW EXECUTE FUNCTION private.caisse_journal('id');
CREATE TRIGGER caisse_avances_maj BEFORE UPDATE ON public.caisse_avances FOR EACH ROW EXECUTE FUNCTION private.caisse_maj();
CREATE TRIGGER caisse_avances_projet BEFORE INSERT OR UPDATE ON public.caisse_avances FOR EACH ROW EXECUTE FUNCTION private.caisse_verif_projet();
CREATE TRIGGER caisse_journal AFTER INSERT OR DELETE OR UPDATE ON public.caisse_avances FOR EACH ROW EXECUTE FUNCTION private.caisse_journal('id');
CREATE TRIGGER caisse_journal AFTER INSERT OR DELETE OR UPDATE ON public.caisse_categories FOR EACH ROW EXECUTE FUNCTION private.caisse_journal('id');
CREATE TRIGGER caisse_depenses_maj BEFORE UPDATE ON public.caisse_depenses FOR EACH ROW EXECUTE FUNCTION private.caisse_maj();
CREATE TRIGGER caisse_depenses_projet BEFORE INSERT OR UPDATE ON public.caisse_depenses FOR EACH ROW EXECUTE FUNCTION private.caisse_verif_projet();
CREATE TRIGGER caisse_depenses_valid BEFORE INSERT OR UPDATE ON public.caisse_depenses FOR EACH ROW EXECUTE FUNCTION private.caisse_validation();
CREATE TRIGGER caisse_journal AFTER INSERT OR DELETE OR UPDATE ON public.caisse_depenses FOR EACH ROW EXECUTE FUNCTION private.caisse_journal('id');
CREATE TRIGGER caisse_journal AFTER INSERT OR DELETE OR UPDATE ON public.caisse_ouvriers FOR EACH ROW EXECUTE FUNCTION private.caisse_journal('id');
CREATE TRIGGER caisse_journal AFTER INSERT OR DELETE OR UPDATE ON public.caisse_projets_reglages FOR EACH ROW EXECUTE FUNCTION private.caisse_journal('project_id');
CREATE TRIGGER caisse_journal AFTER INSERT OR DELETE OR UPDATE ON public.caisse_reglages FOR EACH ROW EXECUTE FUNCTION private.caisse_journal('id');
CREATE TRIGGER caisse_verrou BEFORE DELETE ON public.people FOR EACH ROW EXECUTE FUNCTION private.caisse_verrou_people();
CREATE TRIGGER projects_activity AFTER INSERT OR DELETE OR UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION private.log_activity();
CREATE TRIGGER tasks_activity AFTER INSERT OR DELETE OR UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION private.log_activity();

-- ---------------------------------------------------------------- Sécurité au niveau des lignes
alter table public.activity enable row level security;
alter table public.app_users enable row level security;
alter table public.caisse_acces enable row level security;
alter table public.caisse_alimentations enable row level security;
alter table public.caisse_avances enable row level security;
alter table public.caisse_categories enable row level security;
alter table public.caisse_conversations enable row level security;
alter table public.caisse_depenses enable row level security;
alter table public.caisse_historique enable row level security;
alter table public.caisse_messages enable row level security;
alter table public.caisse_ouvriers enable row level security;
alter table public.caisse_projets_reglages enable row level security;
alter table public.caisse_reglages enable row level security;
alter table public.countdown_secret enable row level security;
alter table public.countdown_state enable row level security;
alter table public.people enable row level security;
alter table public.projects enable row level security;
alter table public.settings enable row level security;
alter table public.tasks enable row level security;

create policy "activity: lecture membres" on public.activity as permissive for select to authenticated
  using (( SELECT private.is_member() AS is_member));
create policy "app_users: admin modifie" on public.app_users as permissive for update to authenticated
  using ((( SELECT private.is_admin() AS is_admin) AND (( SELECT private.is_super() AS is_super) OR (role <> 'superadmin'::text))))
  with check ((( SELECT private.is_admin() AS is_admin) AND (( SELECT private.is_super() AS is_super) OR (role <> 'superadmin'::text))));
create policy "app_users: admin supprime" on public.app_users as permissive for delete to authenticated
  using ((( SELECT private.is_admin() AS is_admin) AND (( SELECT private.is_super() AS is_super) OR (role <> 'superadmin'::text))));
create policy "app_users: admin écrit" on public.app_users as permissive for insert to authenticated
  with check ((( SELECT private.is_admin() AS is_admin) AND (( SELECT private.is_super() AS is_super) OR (role <> 'superadmin'::text))));
create policy "app_users: lecture" on public.app_users as permissive for select to authenticated
  using ((( SELECT private.is_admin() AS is_admin) OR (email = lower(COALESCE((auth.jwt() ->> 'email'::text), ''::text)))));
create policy "caisse_acces: lecture" on public.caisse_acces as permissive for select to authenticated
  using ((( SELECT private.is_super() AS is_super) OR (person_id = ( SELECT private.my_person() AS my_person))));
create policy "caisse_acces: super modifie" on public.caisse_acces as permissive for update to authenticated
  using (( SELECT private.is_super() AS is_super))
  with check (( SELECT private.is_super() AS is_super));
create policy "caisse_acces: super supprime" on public.caisse_acces as permissive for delete to authenticated
  using (( SELECT private.is_super() AS is_super));
create policy "caisse_acces: super écrit" on public.caisse_acces as permissive for insert to authenticated
  with check (( SELECT private.is_super() AS is_super));
create policy "caisse_alimentations: création" on public.caisse_alimentations as permissive for insert to authenticated
  with check (( SELECT private.caisse_ecriture() AS caisse_ecriture));
create policy "caisse_alimentations: lecture" on public.caisse_alimentations as permissive for select to authenticated
  using (( SELECT private.caisse_lecture() AS caisse_lecture));
create policy "caisse_alimentations: modification" on public.caisse_alimentations as permissive for update to authenticated
  using (( SELECT private.caisse_ecriture() AS caisse_ecriture))
  with check (( SELECT private.caisse_ecriture() AS caisse_ecriture));
create policy "caisse_alimentations: suppression" on public.caisse_alimentations as permissive for delete to authenticated
  using (( SELECT private.caisse_ecriture() AS caisse_ecriture));
create policy "caisse_avances: création" on public.caisse_avances as permissive for insert to authenticated
  with check (( SELECT private.caisse_ecriture() AS caisse_ecriture));
create policy "caisse_avances: lecture" on public.caisse_avances as permissive for select to authenticated
  using (( SELECT private.caisse_lecture() AS caisse_lecture));
create policy "caisse_avances: modification" on public.caisse_avances as permissive for update to authenticated
  using (( SELECT private.caisse_ecriture() AS caisse_ecriture))
  with check (( SELECT private.caisse_ecriture() AS caisse_ecriture));
create policy "caisse_avances: suppression" on public.caisse_avances as permissive for delete to authenticated
  using (( SELECT private.caisse_ecriture() AS caisse_ecriture));
create policy "caisse_categories: lecture" on public.caisse_categories as permissive for select to authenticated
  using (( SELECT private.caisse_lecture() AS caisse_lecture));
create policy "caisse_categories: super modifie" on public.caisse_categories as permissive for update to authenticated
  using (( SELECT private.is_super() AS is_super))
  with check (( SELECT private.is_super() AS is_super));
create policy "caisse_categories: super supprime" on public.caisse_categories as permissive for delete to authenticated
  using (( SELECT private.is_super() AS is_super));
create policy "caisse_categories: super écrit" on public.caisse_categories as permissive for insert to authenticated
  with check (( SELECT private.is_super() AS is_super));
create policy "caisse_depenses: création" on public.caisse_depenses as permissive for insert to authenticated
  with check (( SELECT private.caisse_ecriture() AS caisse_ecriture));
create policy "caisse_depenses: lecture" on public.caisse_depenses as permissive for select to authenticated
  using (( SELECT private.caisse_lecture() AS caisse_lecture));
create policy "caisse_depenses: modification" on public.caisse_depenses as permissive for update to authenticated
  using (( SELECT private.caisse_ecriture() AS caisse_ecriture))
  with check (( SELECT private.caisse_ecriture() AS caisse_ecriture));
create policy "caisse_depenses: suppression" on public.caisse_depenses as permissive for delete to authenticated
  using (( SELECT private.caisse_ecriture() AS caisse_ecriture));
create policy "caisse_historique: lecture" on public.caisse_historique as permissive for select to authenticated
  using (( SELECT private.caisse_lecture() AS caisse_lecture));
create policy "caisse_messages: lecture" on public.caisse_messages as permissive for select to authenticated
  using (( SELECT private.caisse_lecture() AS caisse_lecture));
create policy "caisse_messages: super associe" on public.caisse_messages as permissive for update to authenticated
  using (( SELECT private.is_super() AS is_super))
  with check (( SELECT private.is_super() AS is_super));
create policy "caisse_ouvriers: lecture" on public.caisse_ouvriers as permissive for select to authenticated
  using (( SELECT private.caisse_lecture() AS caisse_lecture));
create policy "caisse_ouvriers: super modifie" on public.caisse_ouvriers as permissive for update to authenticated
  using (( SELECT private.is_super() AS is_super))
  with check (( SELECT private.is_super() AS is_super));
create policy "caisse_ouvriers: super supprime" on public.caisse_ouvriers as permissive for delete to authenticated
  using (( SELECT private.is_super() AS is_super));
create policy "caisse_ouvriers: super écrit" on public.caisse_ouvriers as permissive for insert to authenticated
  with check (( SELECT private.is_super() AS is_super));
create policy "caisse_projets_reglages: lecture" on public.caisse_projets_reglages as permissive for select to authenticated
  using (( SELECT private.caisse_lecture() AS caisse_lecture));
create policy "caisse_projets_reglages: super modifie" on public.caisse_projets_reglages as permissive for update to authenticated
  using (( SELECT private.is_super() AS is_super))
  with check (( SELECT private.is_super() AS is_super));
create policy "caisse_projets_reglages: super supprime" on public.caisse_projets_reglages as permissive for delete to authenticated
  using (( SELECT private.is_super() AS is_super));
create policy "caisse_projets_reglages: super écrit" on public.caisse_projets_reglages as permissive for insert to authenticated
  with check (( SELECT private.is_super() AS is_super));
create policy "caisse_reglages: lecture" on public.caisse_reglages as permissive for select to authenticated
  using (( SELECT private.caisse_lecture() AS caisse_lecture));
create policy "caisse_reglages: super modifie" on public.caisse_reglages as permissive for update to authenticated
  using (( SELECT private.is_super() AS is_super))
  with check (( SELECT private.is_super() AS is_super));
create policy "caisse_reglages: super supprime" on public.caisse_reglages as permissive for delete to authenticated
  using (( SELECT private.is_super() AS is_super));
create policy "caisse_reglages: super écrit" on public.caisse_reglages as permissive for insert to authenticated
  with check (( SELECT private.is_super() AS is_super));
create policy "countdown lecture publique" on public.countdown_state as permissive for select to anon, authenticated
  using (true);
create policy "people: admin modifie" on public.people as permissive for update to authenticated
  using (( SELECT private.is_admin() AS is_admin))
  with check (( SELECT private.is_admin() AS is_admin));
create policy "people: admin supprime" on public.people as permissive for delete to authenticated
  using ((( SELECT private.is_admin() AS is_admin) AND (( SELECT private.is_super() AS is_super) OR (NOT (EXISTS ( SELECT 1
   FROM app_users u
  WHERE ((u.id = people.id) AND (u.role = 'superadmin'::text))))))));
create policy "people: admin écrit" on public.people as permissive for insert to authenticated
  with check (( SELECT private.is_admin() AS is_admin));
create policy "people: lecture membres" on public.people as permissive for select to authenticated
  using (( SELECT private.is_member() AS is_member));
create policy "projects: création" on public.projects as permissive for insert to authenticated
  with check ((( SELECT private.can_edit() AS can_edit) AND (( SELECT private.is_admin() AS is_admin) OR (created_by = ( SELECT private.my_person() AS my_person)))));
create policy "projects: lecture" on public.projects as permissive for select to authenticated
  using (( SELECT private.is_member() AS is_member));
create policy "projects: modification" on public.projects as permissive for update to authenticated
  using ((( SELECT private.is_admin() AS is_admin) OR (( SELECT private.can_edit() AS can_edit) AND (created_by = ( SELECT private.my_person() AS my_person)))))
  with check ((( SELECT private.is_admin() AS is_admin) OR (( SELECT private.can_edit() AS can_edit) AND (created_by = ( SELECT private.my_person() AS my_person)))));
create policy "projects: suppression" on public.projects as permissive for delete to authenticated
  using ((( SELECT private.is_admin() AS is_admin) OR (( SELECT private.can_edit() AS can_edit) AND (created_by = ( SELECT private.my_person() AS my_person)))));
create policy "settings: admin modifie" on public.settings as permissive for update to authenticated
  using (( SELECT private.is_admin() AS is_admin))
  with check (( SELECT private.is_admin() AS is_admin));
create policy "settings: admin supprime" on public.settings as permissive for delete to authenticated
  using (( SELECT private.is_admin() AS is_admin));
create policy "settings: admin écrit" on public.settings as permissive for insert to authenticated
  with check (( SELECT private.is_admin() AS is_admin));
create policy "settings: lecture membres" on public.settings as permissive for select to authenticated
  using (( SELECT private.is_member() AS is_member));
create policy "tasks: création" on public.tasks as permissive for insert to authenticated
  with check (( SELECT private.can_edit() AS can_edit));
create policy "tasks: lecture" on public.tasks as permissive for select to authenticated
  using (( SELECT private.is_member() AS is_member));
create policy "tasks: modification" on public.tasks as permissive for update to authenticated
  using (( SELECT private.can_edit() AS can_edit))
  with check (( SELECT private.can_edit() AS can_edit));
create policy "tasks: suppression" on public.tasks as permissive for delete to authenticated
  using (( SELECT private.can_edit() AS can_edit));
