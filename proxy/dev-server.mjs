// Menjalankan Worker di komputer sendiri untuk pengembangan: node proxy/dev-server.mjs [port]
// Lalu build web dengan --dart-define=PROXY_URL=http://localhost:8787
import { createServer } from 'node:http';
import { Readable } from 'node:stream';
import worker from './worker.js';

const port = Number(process.argv[2] ?? 8787);
createServer(async (req, res) => {
  const headers = new Headers();
  for (const [k, v] of Object.entries(req.headers)) if (v) headers.set(k, Array.isArray(v) ? v.join(',') : v);
  const request = new Request(`http://localhost:${port}${req.url}`, { method: req.method, headers });
  const out = await worker.fetch(request, { ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS ?? '' });
  res.writeHead(out.status, Object.fromEntries(out.headers));
  if (out.body && req.method !== 'HEAD') Readable.fromWeb(out.body).pipe(res);
  else res.end();
}).listen(port, () => console.log(`Qorybook proxy lokal di http://localhost:${port}`));
