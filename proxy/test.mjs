// Uji Worker tanpa Cloudflare: node proxy/test.mjs
// Bagian "mock" tidak butuh internet. Bagian "live" memanggil BUDI sungguhan (lewati dengan OFFLINE=1).
import assert from 'node:assert/strict';
import worker, { corsHeaders, parseTarget } from './worker.js';

const BUDI = 'https://budi.kemendikdasmen.go.id/storage/book/6E71ptWg2zIvGHwbj6J6FVuPj6Ur44nIDvNkdJf0.pdf';
const proxied = (u, init) => new Request(`https://proxy.test/budi?u=${encodeURIComponent(u)}`, init);
const realFetch = globalThis.fetch;
let passed = 0;
const test = async (name, fn) => {
  await fn();
  passed++;
  console.log('ok -', name);
};

// ---- validasi (tanpa jaringan) ----
await test('parseTarget menolak host, skema, jalur, dan kredensial di luar daftar', () => {
  assert.equal(typeof parseTarget(BUDI), 'object');
  for (const bad of [
    '',
    'bukan url',
    'http://budi.kemendikdasmen.go.id/storage/x.pdf',
    'https://example.com/storage/x.pdf',
    'https://budi.kemendikdasmen.go.id.evil.com/storage/x.pdf',
    'https://budi.kemendikdasmen.go.id/admin',
    'https://user:pw@budi.kemendikdasmen.go.id/storage/x.pdf',
    'https://budi.kemendikdasmen.go.id:8443/storage/x.pdf',
  ]) {
    assert.equal(typeof parseTarget(bad), 'string', `harus ditolak: ${bad}`);
  }
});

await test('nama berkas dengan spasi tetap valid', () => {
  const t = parseTarget('https://budi.kemendikdasmen.go.id/storage/video/Cerita Rakyat.mov');
  assert.equal(typeof t, 'object');
  assert.match(t.pathname, /Cerita%20Rakyat\.mov$/);
});

await test('CORS: daftar origin, localhost, dan tanpa daftar', () => {
  assert.equal(corsHeaders('https://x.id', {})['Access-Control-Allow-Origin'], '*');
  const env = { ALLOWED_ORIGINS: 'https://qorybook.vercel.app, https://b.id' };
  assert.equal(corsHeaders('https://b.id', env)['Access-Control-Allow-Origin'], 'https://b.id');
  assert.equal(corsHeaders('http://localhost:8080', env)['Access-Control-Allow-Origin'], 'http://localhost:8080');
  assert.equal(corsHeaders('https://evil.com', env), null);
});

await test('permintaan: tanpa u → 400, jalur lain → 404, POST → 405, origin asing → 403', async () => {
  const env = { ALLOWED_ORIGINS: 'https://ok.id' };
  assert.equal((await worker.fetch(new Request('https://p.test/budi'), env)).status, 400);
  assert.equal((await worker.fetch(new Request('https://p.test/lain'), env)).status, 404);
  assert.equal((await worker.fetch(new Request('https://p.test/budi', { method: 'POST' }), env)).status, 405);
  const res = await worker.fetch(proxied(BUDI, { headers: { Origin: 'https://evil.com' } }), env);
  assert.equal(res.status, 403);
  const pre = await worker.fetch(proxied(BUDI, { method: 'OPTIONS', headers: { Origin: 'https://ok.id' } }), env);
  assert.equal(pre.status, 204);
  assert.match(pre.headers.get('Access-Control-Allow-Headers'), /Range/);
});

// ---- dengan fetch tiruan ----
const mockFetch = (handler) => {
  globalThis.fetch = async (url, init) => handler(String(url), init);
};

await test('meneruskan Range + User-Agent jujur, mengembalikan 206 dengan header CORS', async () => {
  let seen;
  mockFetch((url, init) => {
    seen = { url, headers: new Headers(init.headers), method: init.method };
    return new Response('abc', {
      status: 206,
      headers: { 'Content-Type': 'application/pdf', 'Content-Range': 'bytes 0-2/100', 'Accept-Ranges': 'bytes', 'Set-Cookie': 'x=1' },
    });
  });
  const res = await worker.fetch(proxied(BUDI, { headers: { Range: 'bytes=0-2', Origin: 'https://a.id' } }), {});
  assert.equal(res.status, 206);
  assert.equal(await res.text(), 'abc');
  assert.equal(seen.headers.get('range'), 'bytes=0-2');
  assert.match(seen.headers.get('user-agent'), /^Qorybook-Web/);
  assert.doesNotMatch(seen.headers.get('user-agent'), /bot/i);
  assert.equal(res.headers.get('content-range'), 'bytes 0-2/100');
  assert.equal(res.headers.get('access-control-allow-origin'), '*');
  assert.match(res.headers.get('access-control-expose-headers'), /Content-Range/);
  assert.equal(res.headers.get('set-cookie'), null, 'cookie upstream tidak boleh bocor');
});

await test('pengalihan ke host lain ditolak', async () => {
  mockFetch(() => new Response(null, { status: 302, headers: { Location: 'https://evil.com/storage/x.pdf' } }));
  assert.equal((await worker.fetch(proxied(BUDI), {})).status, 502);
});

await test('pengalihan di dalam BUDI diikuti', async () => {
  let n = 0;
  mockFetch((url) => {
    n++;
    return n === 1
      ? new Response(null, { status: 301, headers: { Location: '/storage/book/lain.pdf' } })
      : new Response('ok', { status: 200 });
  });
  const res = await worker.fetch(proxied(BUDI), {});
  assert.equal(res.status, 200);
  assert.equal(n, 2);
});

await test('berkas terlalu besar → 413; error upstream tidak di-cache; gagal jaringan → 502', async () => {
  mockFetch(() => new Response('x', { status: 200, headers: { 'Content-Length': String(400 * 1024 * 1024) } }));
  assert.equal((await worker.fetch(proxied(BUDI), {})).status, 413);
  mockFetch(() => new Response('nf', { status: 404 }));
  const nf = await worker.fetch(proxied(BUDI), {});
  assert.equal(nf.status, 404);
  assert.equal(nf.headers.get('cache-control'), 'no-store');
  mockFetch(() => {
    throw new Error('down');
  });
  assert.equal((await worker.fetch(proxied(BUDI), {})).status, 502);
});

await test('HEAD tidak membawa badan', async () => {
  mockFetch(() => new Response(null, { status: 200, headers: { 'Content-Length': '10' } }));
  const res = await worker.fetch(proxied(BUDI, { method: 'HEAD' }), {});
  assert.equal(res.status, 200);
  assert.equal(await res.text(), '');
});

// ---- BUDI sungguhan ----
globalThis.fetch = realFetch;
if (process.env.OFFLINE) {
  console.log('live dilewati (OFFLINE=1)');
} else {
  await test('live: Range ke PDF BUDI mengembalikan 206 dan awalan %PDF', async () => {
    const res = await worker.fetch(proxied(BUDI, { headers: { Range: 'bytes=0-1023', Origin: 'https://x.id' } }), {});
    assert.equal(res.status, 206);
    assert.match(res.headers.get('content-range'), /^bytes 0-1023\//);
    assert.equal(res.headers.get('access-control-allow-origin'), '*');
    const buf = Buffer.from(await res.arrayBuffer());
    assert.equal(buf.length, 1024);
    assert.equal(buf.subarray(0, 4).toString(), '%PDF');
  });
  await test('live: sampul JPEG BUDI', async () => {
    const cover = 'https://budi.kemendikdasmen.go.id/storage/image/hsrTp9AX1DEmHDNzlWk0QNKxqDB3l5tm9IweJ50S.jpg';
    const res = await worker.fetch(proxied(cover), {});
    assert.equal(res.status, 200);
    assert.match(res.headers.get('content-type'), /image\/jpeg/);
    assert.ok((await res.arrayBuffer()).byteLength > 1000);
  });
}
console.log(`\n${passed} uji lulus`);
