/* Keragaan Region 16 – autentikasi PIN & dekripsi data (AES-256-GCM, kunci PBKDF2-SHA256 dari PIN).
   Kunci hanya disimpan di sessionStorage tab ini (hilang saat tab/browser ditutup). */
const KRA = (() => {
  const SK = 'kr-key', ST = 'kr-last';
  const IDLE_MS = 30 * 60 * 1000;           // keluar otomatis setelah 30 menit tidak aktif
  const subtle = (window.crypto && window.crypto.subtle && window.isSecureContext) ? window.crypto.subtle : null;
  const b64d = s => Uint8Array.from(atob(s), c => c.charCodeAt(0));
  const b64e = u => btoa(String.fromCharCode.apply(null, Array.from(u)));
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
  async function derive(pin, cfg) {
    const salt = b64d(cfg.salt);
    if (subtle) {
      const base = await subtle.importKey('raw', new TextEncoder().encode(pin), 'PBKDF2', false, ['deriveBits']);
      return new Uint8Array(await subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations: cfg.iter }, base, 256));
    }
    if (!window.KRC) throw new Error('Pustaka kripto cadangan tidak termuat.');
    return window.KRC.derive(pin, salt, cfg.iter);
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
  function touch() { try { sessionStorage.setItem(ST, String(Date.now())); } catch (e) {} }
  async function login(pin) {
    const cfg = await loadAuth();
    const key = await derive(pin, cfg);
    let ok = false;
    try { ok = (await decryptText(key, cfg.iv, cfg.check)) === 'KR-OK'; } catch (e) { ok = false; }
    if (!ok) return false;
    sessionStorage.setItem(SK, b64e(key)); touch();
    return true;
  }
  function logout(expired) {
    try { sessionStorage.removeItem(SK); sessionStorage.removeItem(ST); } catch (e) {}
    if (expired !== true) location.replace('login.html');
  }
  function guard() {   // dipanggil di index.html
    const k = getKey();
    if (!k) { location.replace('login.html' + (sessionStorage.getItem('kr-exp') ? '' : '')); return null; }
    touch();
    ['click', 'keydown', 'scroll', 'mousemove', 'touchstart'].forEach(ev => addEventListener(ev, () => {
      const t = +sessionStorage.getItem(ST) || 0; if (Date.now() - t > 30000) touch(); }, { passive: true }));
    setInterval(() => { if (!getKey()) { sessionStorage.setItem('kr-exp', '1'); location.replace('login.html'); } }, 60000);
    return k;
  }
  return { login, logout, guard, getKey, decryptText, secure: !!subtle };
})();
