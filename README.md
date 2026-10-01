# Aurel Gym — Supabase

Banco: tfoljlaubarztsuurctt. O catálogo existente foi importado com 8 peças e 5 categorias.

- `products` e `categories`: leitura pública do catálogo ativo, edição pelo painel `admin.html`.
- `profiles`: nome, e-mail e versão dos termos aceitos; cada cliente lê seu perfil, administradores podem consultar os cadastros. O e-mail é sincronizado pelo Auth e não pode ser editado pela API pública.
- `favorites` e `cart_items`: seleção do cliente, com RLS e sincronização pelo site.
- Contas e senhas são gerenciadas pelo Supabase Auth. Não há senhas nas tabelas públicas.
- `save_preferences`: substitui atomicamente a seleção do cliente autenticado.

A chave em database.js é publicável. Nunca inserir service_role no navegador.

Em Authentication > URL Configuration, definir Site URL como `https://aurelgymjk.vercel.app` e adicionar `https://aurelgymjk.vercel.app/login.html` à lista de Redirect URLs, preservando endereços de outros sites que usam este projeto. A confirmação de e-mail permanece ativada. Sem essa configuração, o Supabase pode redirecionar os e-mails para localhost.

O cadastro agora cria o perfil no banco por um trigger interno, antes do primeiro login. A tela de conta oferece reenvio de confirmação e recuperação de senha; links expirados exibem uma orientação. Na recuperação, a senha é trocada pela sessão recebida do Supabase e as sessões são encerradas antes de um novo login.

## Painel de administração

- Acesse `admin.html` ou o botão “Painel de administrador” na página da conta autorizada.
- Crie e edite produtos, preços, imagens, cores, tamanhos e descrições; ative ou oculte peças sem apagar favoritos ou sacolas.
- Adicione categorias e remova categorias vazias.
- Consulte clientes com paginação. Senhas e tokens não são expostos.
- `aurel_admins` contém as contas autorizadas. Clientes não podem inserir, alterar ou excluir permissões. As políticas conferem o ID autenticado no banco, sem confiar em `user_metadata`.
- A conta escolhida pelo proprietário foi autorizada no banco. Ela precisa confirmar o e-mail para entrar; nenhuma senha ou confirmação foi alterada pelo SQL.
- Para conceder acesso a outra conta já cadastrada, um operador do banco deve inserir seu `auth.users.id` em `aurel_admins`. Essa operação não está disponível no navegador.

Compras e pagamentos permanecem indisponíveis. A exclusão de contas não foi ativada.

SDK Supabase 2.117.2 incluído localmente em supabase.vendor.js. `schema.sql` registra a estrutura e o catálogo iniciais. `admin_accounts.sql` registra a migração incremental aplicada em 01/10/2026. Não reaplicar esses arquivos em banco já configurado.

Validação: testes transacionais no banco confirmaram criação de perfil no cadastro, isolamento entre clientes, bloqueio de autoatribuição de administrador, leitura pública do catálogo e criação/edição de produtos pelo administrador. Os registros de teste foram desfeitos com rollback.
