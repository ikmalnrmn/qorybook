// Qorybook web proxy (Cloudflare Worker).
//
// Server BUDI (budi.kemendikdasmen.go.id) tidak mengirim header CORS, jadi browser menolak
// PDF, sampul, dan media dari sana. Worker ini meneruskan permintaan GET/HEAD ke BUDI dan
// menambahkan header CORS. Hanya host dan jalur yang diizinkan di bawah yang dilayani,
// supaya tidak bisa dipakai sebagai proxy terbuka.
//
//   GET /budi?u=<URL BUDI yang di-encode>
//
// Variabel opsional (wrangler.toml / dashboard):
//   ALLOWED_ORIGINS  daftar origin situs web yang boleh memakai proxy, dipisah koma.
//                    Kosong = semua origin (hanya bila kamu tidak peduli kuota).

const ALLOWED_HOSTS = new Set(['budi.kemendikdasmen.go.id']);
const ALLOWED_PATH_PREFIX = '/storage/';
const MAX_BYTES = 300 * 1024 * 1024;
const MAX_REDIRECTS = 3;
const UPSTREAM_UA = 'Qorybook-Web/1.0 (+https://github.com/ikmalnrmn/qorybook)';

// Header permintaan yang boleh diteruskan ke BUDI (Range penting untuk PDF).
const FORWARD_REQUEST_HEADERS = ['range', 'if-range', 'if-none-match', 'if-modified-since', 'accept'];
// Header respons yang diteruskan ke browser.
const FORWARD_RESPONSE_HEADERS = [
  'content-type',
  'content-length',
  'content-range',
  'accept-ranges',
  'etag',
  'last-modified',
];

export default {
  async fetch(request, env = {}) {
    const origin = request.headers.get('Origin');
    const cors = corsHeaders(origin, env);

    if (request.method === 'OPTIONS') {
      if (cors === null) return text('Origin tidak diizinkan', 403);
      return new Response(null, {
        status: 204,
        headers: {
          ...cors,
          'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
          'Access-Control-Allow-Headers': 'Range, If-Range, If-None-Match, If-Modified-Since',
          'Access-Control-Max-Age': '86400',
        },
      });
    }
    if (request.method !== 'GET' && request.method !== 'HEAD') return text('Metode tidak didukung', 405);
    if (cors === null) return text('Origin tidak diizinkan', 403);

    const url = new URL(request.url);
    if (url.pathname === '/' || url.pathname === '/health') return text('Qorybook proxy OK', 200, cors);
    if (url.pathname !== '/budi') return text('Tidak ditemukan', 404, cors);

    const target = parseTarget(url.searchParams.get('u'));
    if (typeof target === 'string') return text(target, 400, cors);

    const headers = new Headers({ 'User-Agent': UPSTREAM_UA });
    for (const name of FORWARD_REQUEST_HEADERS) {
      const value = request.headers.get(name);
      if (value) headers.set(name, value);
    }

    let upstream;
    let current = target;
    for (let hop = 0; ; hop++) {
      try {
        upstream = await fetch(current.toString(), {
          method: request.method,
          headers,
          redirect: 'manual',
          // Cache Cloudflare: berkas BUDI bernama hash, jadi aman disimpan lama.
          cf: { cacheEverything: true, cacheTtl: 86400 },
        });
      } catch {
        return text('Server BUDI tidak dapat dihubungi', 502, cors);
      }
      if (upstream.status >= 300 && upstream.status < 400 && upstream.status !== 304) {
        const next = parseTarget(new URL(upstream.headers.get('Location') ?? '', current).toString());
        if (typeof next === 'string' || hop >= MAX_REDIRECTS) return text('Pengalihan tidak diizinkan', 502, cors);
        current = next;
        continue;
      }
      break;
    }

    const length = Number(upstream.headers.get('content-length') ?? 0);
    if (length > MAX_BYTES) return text('Berkas terlalu besar', 413, cors);

    const out = new Headers(cors);
    for (const name of FORWARD_RESPONSE_HEADERS) {
      const value = upstream.headers.get(name);
      if (value) out.set(name, value);
    }
    out.set('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges, ETag');
    if (upstream.ok || upstream.status === 304) {
      out.set('Cache-Control', 'public, max-age=86400');
    } else {
      out.set('Cache-Control', 'no-store');
    }
    return new Response(request.method === 'HEAD' ? null : upstream.body, { status: upstream.status, headers: out });
  },
};

/** URL BUDI yang valid, atau string pesan galat. */
export function parseTarget(raw) {
  if (!raw) return 'Parameter u wajib diisi';
  let target;
  try {
    target = new URL(raw);
  } catch {
    return 'URL tidak valid';
  }
  if (target.protocol !== 'https:') return 'Hanya https yang diizinkan';
  if (target.username || target.password) return 'URL tidak valid';
  if (!ALLOWED_HOSTS.has(target.hostname)) return 'Host tidak diizinkan';
  if (target.port && target.port !== '443') return 'Host tidak diizinkan';
  if (!target.pathname.startsWith(ALLOWED_PATH_PREFIX)) return 'Jalur tidak diizinkan';
  return target;
}

/** Header CORS untuk [origin], atau null bila origin ditolak. */
export function corsHeaders(origin, env = {}) {
  const allowed = (env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (allowed.length === 0) return { 'Access-Control-Allow-Origin': '*' };
  // Permintaan tanpa Origin (mis. <img> biasa) tidak butuh CORS; layani saja.
  if (!origin) return { 'Access-Control-Allow-Origin': allowed[0], Vary: 'Origin' };
  const isLocal = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  if (allowed.includes(origin) || isLocal) return { 'Access-Control-Allow-Origin': origin, Vary: 'Origin' };
  return null;
}

function text(body, status, extra = {}) {
  return new Response(body, { status, headers: { 'Content-Type': 'text/plain; charset=utf-8', ...extra } });
}
