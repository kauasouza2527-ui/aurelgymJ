-- Aurel Gym demo checkout and sales dashboard schema.
-- Apply once to the connected Supabase project.
create table public.aurel_orders (
 id uuid primary key default gen_random_uuid(),
 order_number text not null unique check (order_number ~ '^AG-[0-9]{8}-[A-Z0-9]{6}$'),
 customer_user_id uuid references auth.users(id) on delete set null,
 customer_name text not null check (length(btrim(customer_name)) between 2 and 100),
 customer_email text not null check (length(customer_email) between 5 and 254),
 cpf_last4 text not null check (cpf_last4 ~ '^[0-9]{4}$'),
 cep text not null check (cep ~ '^[0-9]{8}$'),
 address_line text not null check (length(btrim(address_line)) between 3 and 160),
 address_number text not null check (length(btrim(address_number)) between 1 and 20),
 complement text not null default '' check (length(complement) <= 100),
 neighborhood text not null check (length(btrim(neighborhood)) between 2 and 100),
 city text not null check (length(btrim(city)) between 2 and 100),
 state text not null check (state ~ '^[A-Z]{2}$'),
 payment_method text not null check (payment_method in ('pix','cartao','boleto')),
 payment_status text not null default 'simulado_sem_cobranca',
 order_status text not null default 'registrado' check (order_status in ('registrado','separando','enviado','concluido','cancelado')),
 total numeric(10,2) not null default 0 check (total >= 0),
 items jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) between 1 and 100),
 created_at timestamptz not null default now()
);
create index aurel_orders_created_at_idx on public.aurel_orders(created_at desc);
create index aurel_orders_customer_user_id_idx on public.aurel_orders(customer_user_id);
create index aurel_orders_status_idx on public.aurel_orders(order_status);
alter table public.aurel_orders enable row level security;
revoke all on public.aurel_orders from public, anon, authenticated;
grant insert (order_number,customer_name,customer_email,cpf_last4,cep,address_line,address_number,complement,neighborhood,city,state,payment_method,items) on public.aurel_orders to anon, authenticated;
grant select on public.aurel_orders to authenticated;
grant update (order_status) on public.aurel_orders to authenticated;
grant all on public.aurel_orders to service_role;
create policy aurel_orders_guest_create on public.aurel_orders for insert to anon, authenticated
 with check (order_status = 'registrado' and payment_status = 'simulado_sem_cobranca');
create policy aurel_orders_admin_read on public.aurel_orders for select to authenticated
 using (exists(select 1 from public.aurel_admins where user_id = (select auth.uid())));
create policy aurel_orders_admin_update on public.aurel_orders for update to authenticated
 using (exists(select 1 from public.aurel_admins where user_id = (select auth.uid())))
 with check (exists(select 1 from public.aurel_admins where user_id = (select auth.uid())));
create function public.aurel_prepare_order() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare item jsonb; product_row public.products%rowtype; clean_items jsonb := '[]'::jsonb; computed_total numeric(10,2) := 0; qty_value integer;
begin
 if jsonb_typeof(new.items) <> 'array' or jsonb_array_length(new.items) < 1 or jsonb_array_length(new.items) > 100 then raise exception 'Carrinho inválido'; end if;
 for item in select value from jsonb_array_elements(new.items) loop
  if jsonb_typeof(item) <> 'object' or coalesce(item->>'id','') !~ '^[0-9]{1,10}$' or coalesce(item->>'qty','') !~ '^[0-9]{1,2}$' then raise exception 'Item inválido'; end if;
  qty_value := (item->>'qty')::integer;
  if qty_value < 1 or qty_value > 20 then raise exception 'Quantidade inválida'; end if;
  select * into product_row from public.products where id = (item->>'id')::integer and active = true;
  if not found then raise exception 'Produto indisponível'; end if;
  if not (coalesce(item->>'size','') = any(product_row.sizes)) or not (coalesce(item->>'color','') = any(product_row.colors)) then raise exception 'Opção de produto indisponível'; end if;
  clean_items := clean_items || jsonb_build_array(jsonb_build_object('id',product_row.id,'name',product_row.name,'category',product_row.category,'price',product_row.price,'photo',product_row.photo,'qty',qty_value,'size',item->>'size','color',item->>'color','line_total',product_row.price * qty_value));
  computed_total := computed_total + product_row.price * qty_value;
 end loop;
 new.items := clean_items; new.total := computed_total; new.payment_status := 'simulado_sem_cobranca'; new.order_status := 'registrado'; new.customer_user_id := (select auth.uid());
 return new;
end $$;
revoke all on function public.aurel_prepare_order() from public, anon, authenticated;
create trigger aurel_orders_prepare before insert on public.aurel_orders for each row execute function public.aurel_prepare_order();
