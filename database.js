(() => {
  'use strict';
  const client = supabase.createClient('https://tfoljlaubarztsuurctt.supabase.co', 'sb_publishable_NUQsSijBCU9cpGoS4FJ13w_Cw4KkzfO');
  let readyStore;
  const storeReady = new Promise(resolve => { readyStore = resolve; });
  document.addEventListener('aurel:ready', readyStore, { once: true });
  const userOf = user => user ? { id: user.id, email: user.email, name: user.user_metadata?.name || 'Cliente Aurel' } : null;
  let owner = null, saving = Promise.resolve();
  async function profile(user) {
    if (!user) return null;
    const { data, error } = await client.from('profiles').select('name').eq('id', user.id).maybeSingle();
    if (error) throw error;
    if (!data) {
      const { error } = await client.from('profiles').insert({ id: user.id, name: userOf(user).name, terms_version: user.user_metadata?.terms_version || null });
      if (error) throw error;
    }
    return { ...userOf(user), name: data?.name || userOf(user).name };
  }
  async function loadPreferences(user, mergeGuest = false) {
    if (!user) return;
    const results = await Promise.all([
      client.from('favorites').select('product_id').eq('user_id', user.id),
      client.from('cart_items').select('product_id,size,color,qty').eq('user_id', user.id)
    ]);
    for (const r of results) if (r.error) throw r.error;
    let favorites = results[0].data.map(x => x.product_id);
    let cart = results[1].data.map(x => ({ id: x.product_id, size: x.size, color: x.color, qty: x.qty }));
    if (mergeGuest) {
      try {
        const guestFavorites = JSON.parse(localStorage.getItem('aurel-favorites-v1') || '[]');
        const guestCart = JSON.parse(localStorage.getItem('aurel-cart-photo-v1') || '[]');
        const { data: pieces, error } = await client.from('products').select('id,sizes,colors').eq('active',true);
        if (error) throw error;
        const valid = new Map(pieces.map(x => [x.id,x]));
        favorites = [...new Set([...favorites, ...guestFavorites.filter(id => valid.has(id))])].slice(0,100);
        for (const item of guestCart) {
          const p = valid.get(item.id);
          if (!p || !p.sizes.includes(item.size) || !p.colors.includes(item.color) || !Number.isInteger(item.qty) || item.qty<1 || item.qty>20) continue;
          const existing = cart.find(x => x.id===item.id && x.size===item.size && x.color===item.color);
          if (existing) existing.qty=Math.min(20,existing.qty+item.qty); else cart.push(item);
        }
        cart=cart.slice(0,100);
        const saved = await client.rpc('save_preferences', {favorite_ids:favorites,items:cart});
        if(saved.error) throw saved.error;
      } catch(error) { console.warn('Aurel: seleção de visitante',error.message); }
    }
    localStorage.setItem('aurel-favorites-v1', JSON.stringify(favorites));
    localStorage.setItem('aurel-cart-photo-v1', JSON.stringify(cart));
    document.dispatchEvent(new Event('aurel:preferences'));
  }
  const ready = (async () => {
    const { data, error } = await client.auth.getSession();
    if (error) throw error;
    owner = data.session?.user.id || null;
    if (data.session) { await profile(data.session.user); await loadPreferences(data.session.user); }
  })().catch(error => console.warn('Aurel: sessão indisponível', error.message));
  async function catalogue(fallback) {
    await ready;
    try {
      const { data, error } = await client.from('products').select('id,name,category,audience,price,colors,sizes,tag,photo,position,zoom,description').eq('active', true).order('id');
      if (error) throw error;
      document.documentElement.dataset.catalogSource = 'supabase';
      return data.map(p => ({ ...p, price: Number(p.price), zoom: Number(p.zoom) }));
    } catch (error) {
      document.documentElement.dataset.catalogSource = 'fallback';
      console.warn('Aurel: catálogo offline', error.message);
      return fallback;
    }
  }
  function savePreferences(favorites, cart) {
    const snapshot = { favorite_ids: [...favorites], items: cart.map(x => ({ ...x })) };
    const expectedOwner = owner;
    if (!expectedOwner) return;
    saving = saving.catch(() => {}).then(async () => {
      if (owner !== expectedOwner) return;
      const { error } = await client.rpc('save_preferences', snapshot);
      if (error) {
        window.Aurel?.toast('Seleção salva neste navegador. Não foi possível sincronizar com sua conta.');
        throw error;
      }
    });
    saving.catch(error => console.warn('Aurel: sincronização', error.message));
  }
  client.auth.onAuthStateChange((event, session) => {
    const next = session?.user.id || null;
    if (next === owner) return;
    const mergeGuest = !owner && !!session && event === "SIGNED_IN";
    owner = next;
    setTimeout(async () => {
      try {
        await storeReady;
        if (session && owner === session.user.id) { await profile(session.user); await loadPreferences(session.user, mergeGuest); }
        else if (event === 'SIGNED_OUT') {
          localStorage.removeItem('aurel-favorites-v1'); localStorage.removeItem('aurel-cart-photo-v1');
          document.dispatchEvent(new Event('aurel:preferences'));
        }
        document.dispatchEvent(new Event('aurel:session'));
      } catch (error) { window.Aurel?.toast('Não foi possível carregar os dados da conta.'); }
    }, 0);
  });
  async function request(body) {
    await ready;
    let result;
    if (!body) {
      const { data, error } = await client.auth.getUser();
      if (error && !error.message.includes('session')) throw error;
      return { user: await profile(data?.user) };
    }
    if (body.action === 'login') result = await client.auth.signInWithPassword({ email: body.email, password: body.password });
    else if (body.action === 'register') {
      if (!body.terms || body.name.length < 2) throw new Error('Informe seu nome e aceite os termos.');
      result = await client.auth.signUp({ email: body.email, password: body.password, options: { data: { name: body.name, terms_version: body.terms }, emailRedirectTo: new URL('login.html', location.href).href } });
      if (result.error) throw result.error;
      if (!result.data.session) return { user: null, message: 'Confira seu e-mail para confirmar o cadastro. Depois, entre com sua senha.' };
    } else if (body.action === 'logout') {
      const { error } = await client.auth.signOut(); if (error) throw error; return { user: null };
    } else {
      const verified = await client.auth.signInWithPassword({ email: body.email, password: body.password });
      if (verified.error) throw new Error('Confira sua senha atual.');
      if (body.action === 'delete') {
        throw new Error('A exclusão de contas ainda não está disponível.');
      }
      if (body.action === 'profile') {
        const { error } = await client.from('profiles').update({ name: body.name }).eq('id', verified.data.user.id);
        if (error) throw error;
        result = await client.auth.updateUser({ data: { name: body.name } });
      } else if (body.action === 'password') {
        result = await client.auth.updateUser({ password: body.newPassword });
        if (!result.error) await client.auth.signOut({ scope: 'others' });
      } else throw new Error('Ação inválida.');
    }
    if (result.error) {
      const messages = { invalid_credentials: 'E-mail ou senha incorretos.', email_not_confirmed: 'Confirme seu e-mail antes de entrar.', over_email_send_rate_limit: 'Aguarde antes de pedir outro e-mail de confirmação.', user_already_exists: 'Este e-mail já está cadastrado.' };
      throw new Error(messages[result.error.code] || result.error.message);
    }
    return { user: await profile(result.data.user) };
  }
  window.AurelDB = { client, ready, storeReady, catalogue, savePreferences, request };
})();
