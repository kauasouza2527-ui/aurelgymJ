-- Incremental migration for the existing Aurel Gym schema.
create schema if not exists private_aurel;
revoke all on schema private_aurel from public, anon, authenticated;

create table public.aurel_admins (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
alter table public.aurel_admins enable row level security;
revoke all on public.aurel_admins from public, anon, authenticated;
grant select on public.aurel_admins to authenticated;
grant all on public.aurel_admins to service_role;
create policy aurel_admin_self on public.aurel_admins for select to authenticated
 using (user_id = (select auth.uid()));

alter table public.profiles add column email text not null default '';
revoke insert, update, delete on public.profiles from authenticated;
grant insert (id, name, terms_version), update (name) on public.profiles to authenticated;
drop policy profiles_own on public.profiles;
create policy profiles_read on public.profiles for select to authenticated
 using (id = (select auth.uid()) or exists (select 1 from public.aurel_admins where user_id = (select auth.uid())));
create policy profiles_insert on public.profiles for insert to authenticated
 with check (id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated
 using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Only the Auth trigger may execute this internal function. The definer is
-- required because signup has no authenticated session yet.
create function private_aurel.sync_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
declare display_name text;
begin
 display_name := left(btrim(coalesce(new.raw_user_meta_data->>'name',new.raw_user_meta_data->>'nome_completo','')),80);
 if length(display_name) < 2 then display_name := 'Cliente Aurel'; end if;
 insert into public.profiles(id,name,email,terms_version)
 values (new.id,display_name,coalesce(new.email,''),left(new.raw_user_meta_data->>'terms_version',40))
 on conflict(id) do update set email=excluded.email;
 return new;
end $$;
revoke all on function private_aurel.sync_profile() from public, anon, authenticated;
create trigger aurel_sync_profile after insert or update of email on auth.users
 for each row execute function private_aurel.sync_profile();

insert into public.profiles(id,name,email,terms_version,created_at)
select id,
 case when length(btrim(coalesce(raw_user_meta_data->>'name',raw_user_meta_data->>'nome_completo',''))) >= 2
 then left(btrim(coalesce(raw_user_meta_data->>'name',raw_user_meta_data->>'nome_completo')),80)
 else 'Cliente Aurel' end,
 coalesce(email,''),left(raw_user_meta_data->>'terms_version',40),created_at
from auth.users on conflict(id) do update set email=excluded.email;

create sequence public.aurel_product_id_seq owned by public.products.id;
select setval('public.aurel_product_id_seq',coalesce((select max(id) from public.products),0)+1,false);
alter table public.products alter column id set default nextval('public.aurel_product_id_seq');
grant usage on sequence public.aurel_product_id_seq to authenticated;
grant insert,update,delete on public.products,public.categories to authenticated;
create policy products_admin on public.products for all to authenticated
 using (exists(select 1 from public.aurel_admins where user_id = (select auth.uid())))
 with check (exists(select 1 from public.aurel_admins where user_id = (select auth.uid())));
create policy categories_admin on public.categories for all to authenticated
 using (exists(select 1 from public.aurel_admins where user_id = (select auth.uid())))
 with check (exists(select 1 from public.aurel_admins where user_id = (select auth.uid())));

-- Administrator membership was assigned separately to the account selected by
-- the project owner. Public source files do not contain account identifiers.
