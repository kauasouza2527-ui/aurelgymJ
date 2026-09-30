create table public.categories (
 name text primary key check (length(name) between 1 and 60)
);
create table public.products (
 id integer primary key,
 name text not null check(length(name) between 1 and 120),
 category text not null references public.categories(name),
 audience text not null check(audience in ('Feminino','Masculino','Unissex')),
 price numeric(10,2) not null check(price >= 0),
 colors text[] not null check(cardinality(colors)>0),
 sizes text[] not null check(cardinality(sizes)>0),
 tag text not null default '', photo text not null,
 position text not null default '50% 50%', zoom numeric not null default 1 check(zoom > 0),
 description text not null default '', active boolean not null default true,
 created_at timestamptz not null default now()
);
create index products_category_idx on public.products(category);
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null check(length(name) between 2 and 80),
 terms_version text,
 created_at timestamptz not null default now()
);
create table public.favorites (
 user_id uuid not null references auth.users(id) on delete cascade,
 product_id integer not null references public.products(id) on delete cascade,
 primary key(user_id,product_id)
);
create index favorites_product_idx on public.favorites(product_id);
create table public.cart_items (
 user_id uuid not null references auth.users(id) on delete cascade,
 product_id integer not null references public.products(id) on delete cascade,
 size text not null, color text not null, qty integer not null check(qty between 1 and 20),
 primary key(user_id,product_id,size,color)
);
create index cart_items_product_idx on public.cart_items(product_id);
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.profiles enable row level security;
alter table public.favorites enable row level security;
alter table public.cart_items enable row level security;
revoke all on public.categories, public.products, public.profiles, public.favorites, public.cart_items from anon, authenticated;
grant select on public.categories, public.products to anon, authenticated;
grant select,insert,update,delete on public.profiles, public.favorites, public.cart_items to authenticated;
grant all on public.categories, public.products, public.profiles, public.favorites, public.cart_items to service_role;
create policy categories_read on public.categories for select to anon,authenticated using(true);
create policy products_read on public.products for select to anon,authenticated using(active);
create policy profiles_own on public.profiles for all to authenticated using((select auth.uid())=id) with check((select auth.uid())=id);
create policy favorites_own on public.favorites for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy cart_own on public.cart_items for all to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create function public.save_preferences(favorite_ids integer[], items jsonb) returns void
language plpgsql security invoker set search_path='' as $$
declare uid uuid := auth.uid();
begin
 if uid is null then raise exception 'Autenticação necessária'; end if;
 if cardinality(favorite_ids)>100 or jsonb_typeof(items)<>'array' or jsonb_array_length(items)>100 then raise exception 'Seleção inválida'; end if;
 if exists(select 1 from jsonb_array_elements(items) x left join public.products p on p.id=(x->>'id')::integer where p.id is null or not p.active or not (x->>'size'=any(p.sizes)) or not (x->>'color'=any(p.colors))) then raise exception 'Peça ou opção inválida'; end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 delete from public.favorites where user_id=uid;
 insert into public.favorites(user_id,product_id) select uid, id from unnest(favorite_ids) id on conflict do nothing;
 delete from public.cart_items where user_id=uid;
 insert into public.cart_items(user_id,product_id,size,color,qty)
 select uid,(x->>'id')::integer,x->>'size',x->>'color',(x->>'qty')::integer from jsonb_array_elements(items) x;
end $$;
revoke all on function public.save_preferences(integer[],jsonb) from public,anon;
grant execute on function public.save_preferences(integer[],jsonb) to authenticated;

-- Importação do catálogo existente no GitHub.
insert into public.categories(name) values ('Camisetas'),('Conjuntos'),('Leggings'),('Shorts'),('Tops');
insert into public.products(id,name,category,audience,price,colors,sizes,tag,photo,position,zoom,description) values
(1,'Legging Flow','Leggings','Feminino',159.9,array['Preto']::text[],array['PP','P','M','G','GG']::text[],'ESSENCIAL','images/set-black.jpg','50% 82%',1.45,'Legging preta de cintura alta e comprimento até o tornozelo. Linhas simples para combinar com o seu ritmo.'),
(2,'Top Essential','Tops','Feminino',89.9,array['Preto']::text[],array['PP','P','M','G']::text[],'TREINO','images/set-black.jpg','50% 28%',1.5,'Top esportivo preto de alças finas. Um essencial para usar com legging e montar uma combinação monocromática.'),
(3,'Short Training','Shorts','Masculino',109.9,array['Preto']::text[],array['P','M','G','GG']::text[],'EM MOVIMENTO','images/training-man.jpg','64% 12%',1,'Short esportivo escuro com detalhes em vermelho. Uma proposta para compor o visual dos seus treinos.'),
(4,'Camiseta Everyday','Camisetas','Unissex',99.9,array['Branco']::text[],array['PP','P','M','G','GG']::text[],'ESSENCIAL','images/white-tee.jpg','50% 45%',1,'Camiseta branca de manga curta e gola redonda. Uma base versátil para o treino leve e o cotidiano.'),
(6,'Conjunto Studio','Conjuntos','Feminino',249.9,array['Preto']::text[],array['P','M','G']::text[],'LOOK COMPLETO','images/set-black.jpg','50% 50%',1,'Top de alças finas e legging preta em uma composição coordenada. Um visual completo, do seu jeito.'),
(7,'Camiseta Graphic','Camisetas','Masculino',119.9,array['Preto']::text[],array['P','M','G','GG']::text[],'LIFESTYLE','images/tee-other.jpg','50% 49%',1.12,'Camiseta preta com estampa gráfica branca, manga curta e modelagem reta. Personalidade para os momentos fora do treino.'),
(8,'Legging Energy','Leggings','Feminino',179.9,array['Laranja']::text[],array['P','M','G','GG']::text[],'MAIS ENERGIA','images/training-a.jpg','45% 50%',1,'Legging em tom alaranjado para trazer cor à sua combinação esportiva. Use com peças neutras para destacar o visual.'),
(10,'Top Pulse','Tops','Feminino',99.9,array['Azul']::text[],array['PP','P','M','G','GG']::text[],'AUREL ACTIVE','images/training-d.jpg','7% 30%',1.15,'Top esportivo azul de alças largas. Uma opção para combinar com peças pretas e brancas na sua rotina de movimento.');
