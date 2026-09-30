# Aurel Gym — Supabase

Banco: tfoljlaubarztsuurctt. O catálogo existente foi importado com 8 peças e 5 categorias.

- `products` e `categories`: leitura pública, administração pelo Supabase.
- `profiles`: nome e versão dos termos aceitos; acesso apenas ao próprio cliente.
- `favorites` e `cart_items`: seleção do cliente, com RLS e sincronização pelo site.
- Contas e senhas são gerenciadas pelo Supabase Auth. Não há senhas nas tabelas públicas.
- `save_preferences`: substitui atomicamente a seleção do cliente autenticado.

A chave em database.js é publicável. Nunca inserir service_role no navegador.

Em Authentication > URL Configuration, definir Site URL como o endereço público da loja e adicionar o endereço /login.html à lista de Redirect URLs. A confirmação de e-mail permanece sob as configurações do projeto.

Compras e pagamentos permanecem indisponíveis. A exclusão de contas não foi ativada.

SDK Supabase 2.117.2 incluído localmente em supabase.vendor.js. schema.sql registra a estrutura e o catálogo aplicados pelo MCP; não reaplicar em banco já configurado.
