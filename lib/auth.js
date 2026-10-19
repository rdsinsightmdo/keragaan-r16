/* Keragaan Region 16 – login username + password & dekripsi data (AES-256-GCM).
   - data/auth.js berisi kunci data yang dibungkus per pengguna dengan kunci PBKDF2-SHA256 dari password.
   - Username tidak tersimpan sebagai teks (hanya hash), password tidak tersimpan sama sekali.
   - Kunci data hanya disimpan di sessionStorage tab ini (hilang saat tab/browser ditutup). */
const KRA = (() => {
  const SK = 'kr-key', ST = 'kr-last', SU = 'kr-user';
  const IDLE_MS = 30 * 60 * 1000;           // keluar otomatis setelah 30 menit tidak aktif
  const UID_SALT = new TextEncoder().encode('KR16-UID'), UID_ITER = 1000;
  const subtle = (window.crypto && window.crypto.subtle && window.isSecureContext) ? window.crypto.subtle : null;
  const b64d = s => Uint8Array.from(atob(s), c => c.charCodeAt(0));
  const b64e = u => btoa(String.fromCharCode.apply(null, Array.from(u)));
  const hex = u => Array.from(u, b => b.toString(16).padStart(2, '0')).join('');
  const normUser = u => String(u || '').trim().toLowerCase();
  let authCfg = null, authWait = [];
  window.KR_AUTH = cfg => { authCfg = cfg; authWait.forEach(f => f(cfg)); authWait = []; };
  function loadAuth() {
    if (authCfg) return Promise.resolve(authCfg);
    return new Promise((res, rej) => {
      authWait.push(res);
      const s = document.createElement('script'); s.src = 'data/auth.js?t=' + Date.now();
      s.onerror = () => rej(new Error('File data/auth.js tidak ditemukan. Jalankan Update_Data.bat.'));
      document.head.appendChild(s);
    });
  }
  async function pbkdf2(text, salt, iter) {
    if (subtle) {
      const base = await subtle.importKey('raw', new TextEncoder().encode(text), 'PBKDF2', false, ['deriveBits']);
      return new Uint8Array(await subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations: iter }, base, 256));
    }
    if (!window.KRC) throw new Error('Pustaka kripto cadangan tidak termuat.');
    return window.KRC.derive(text, salt, iter);
  }
  async function aesDecrypt(keyBytes, ivB64, ctB64) {
    const iv = b64d(ivB64), ct = b64d(ctB64);
    if (subtle) {
      const k = await subtle.importKey('raw', keyBytes, 'AES-GCM', false, ['decrypt']);
      return new Uint8Array(await subtle.decrypt({ name: 'AES-GCM', iv }, k, ct));
    }
    return window.KRC.decrypt(keyBytes, iv, ct);
  }
  async function inflate(u8) {
    const ds = new DecompressionStream('deflate');
    const buf = await new Response(new Blob([u8]).stream().pipeThrough(ds)).arrayBuffer();
    return new Uint8Array(buf);
  }
  async function decryptText(keyBytes, ivB64, ctB64) {
    return new TextDecoder().decode(await inflate(await aesDecrypt(keyBytes, ivB64, ctB64)));
  }
  function getKey() {
    try {
      const k = sessionStorage.getItem(SK), t = +sessionStorage.getItem(ST) || 0;
      if (!k) return null;
      if (Date.now() - t > IDLE_MS) { logout(true); return null; }
      return b64d(k);
    } catch (e) { return null; }
  }
  function user() { try { return sessionStorage.getItem(SU) || ''; } catch (e) { return ''; } }
  function touch() { try { sessionStorage.setItem(ST, String(Date.now())); } catch (e) {} }
  async function login(username, password) {
    const cfg = await loadAuth();
    if (cfg.v !== 2 || !cfg.users) throw new Error('Data masih memakai login PIN lama. Jalankan Kelola_Akun.bat lalu upload ulang.');
    const u = normUser(username);
    const id = hex((await pbkdf2(u, UID_SALT, UID_ITER)).slice(0, 16));
    const known = Object.prototype.hasOwnProperty.call(cfg.users, id);
    const ent = known ? cfg.users[id] : cfg.dummy;      // username tak dikenal tetap diproses (waktu sama)
    const kek = await pbkdf2(password, b64d(ent.s), ent.n);
    let key = null;
    try { key = await aesDecrypt(kek, ent.i, ent.k); } catch (e) { key = null; }
    if (!known || !key) return false;
    let ok = false;
    try { ok = (await decryptText(key, cfg.iv, cfg.check)) === 'KR-OK'; } catch (e) { ok = false; }
    if (!ok) return false;
    sessionStorage.setItem(SK, b64e(key)); sessionStorage.setItem(SU, u); touch();
    return true;
  }
  function logout(expired) {
    try { sessionStorage.removeItem(SK); sessionStorage.removeItem(ST); sessionStorage.removeItem(SU); } catch (e) {}
    if (expired !== true) location.replace('login.html');
  }
  function loginUrl() {   // selain dari index.html, kembali ke halaman asal setelah login
    const p = location.pathname.split('/').pop() || 'index.html';
    return p === 'index.html' ? 'login.html' : 'login.html?next=' + encodeURIComponent(p + location.search + location.hash);
  }
  function guard() {   // dipanggil di index.html dan rsf.html
    const k = getKey();
    if (!k) { location.replace(loginUrl()); return null; }
    touch();
    ['click', 'keydown', 'scroll', 'mousemove', 'touchstart'].forEach(ev => addEventListener(ev, () => {
      const t = +sessionStorage.getItem(ST) || 0; if (Date.now() - t > 30000) touch(); }, { passive: true }));
    setInterval(() => { if (!getKey()) { sessionStorage.setItem('kr-exp', '1'); location.replace(loginUrl()); } }, 60000);
    return k;
  }
  return { login, logout, guard, getKey, user, decryptText, secure: !!subtle };
})();
