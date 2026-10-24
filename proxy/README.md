# Qorybook versi web (iPhone) dan proxy BUDI

Versi web memakai kode Flutter yang sama dengan aplikasi Android. Dua hal berbeda:

- **Pembaca PDF** memakai pdf.js (`app/web/pdfjs/`, `app/web/qory_pdf.js`), bukan `PdfRenderer` Android.
- **Server BUDI tidak mengirim header CORS**, jadi browser menolak PDF, sampul, dan media dari sana
  (1.139 dari 1.421 buku). `worker.js` meneruskan permintaannya dan menambahkan header CORS.
  Server SIBI dan katalog di GitHub Pages sudah punya CORS, jadi tidak lewat proxy.

## Batas versi web

- Tidak ada kunci layar. Orang tua memakai **Akses Terpandu** iPhone (panduan tampil di aplikasi).
- Tidak ada simpan offline; buku selalu dimuat dari server.
- Buku BUDI melewati Worker, jadi jumlah permintaan ke Cloudflare ikut bertambah (paket gratis: 100.000
  permintaan per hari). Berkas PDF di-cache di Cloudflare selama 24 jam.
- Sidik jari/Face ID untuk membuka Area Orang Tua tidak tersedia; hanya PIN.

## 1. Pasang proxy (sekali)

Butuh akun Cloudflare (gratis) dan Node.js.

```bash
cd proxy
npx wrangler login
npx wrangler deploy
```

Hasilnya alamat seperti `https://qorybook-proxy.AKUN.workers.dev`. Catat alamat itu.

Setelah situs web punya alamat tetap, batasi proxy hanya untuk situs itu: isi `ALLOWED_ORIGINS` di
`wrangler.toml` (mis. `"https://qorybook.vercel.app"`), lalu `npx wrangler deploy` lagi. `localhost`
selalu diizinkan untuk pengembangan.

## 2. Build web

```bash
cd app
flutter build web --release \
  --dart-define=PROXY_URL=https://qorybook-proxy.AKUN.workers.dev \
  --dart-define=CATALOG_URL=https://ikmalnrmn.github.io/qorybook/catalog.json
```

Opsional untuk penghitung pengguna (lihat `backend/supabase/001_telemetry.sql`):
`--dart-define=TELEMETRY_URL=... --dart-define=TELEMETRY_KEY=...`.

Hasilnya di `app/build/web`. Unggah isi folder itu ke hosting statis mana pun (Vercel, Cloudflare Pages,
GitHub Pages). Tidak ada pengaturan server khusus, tetapi `.wasm` harus disajikan sebagai
`application/wasm` (semua hosting di atas sudah begitu).

## 3. Pasang di iPhone

Buka alamat situs di **Safari** → tombol Bagikan → **Tambah ke Layar Utama**. Aplikasi terbuka layar penuh
seperti aplikasi biasa. (Chrome di iPhone tidak menawarkan opsi ini.)

## Uji lokal

```bash
node proxy/test.mjs                  # uji Worker; OFFLINE=1 melewati uji ke BUDI sungguhan
node proxy/dev-server.mjs 8787       # Worker di komputer sendiri
```

Lalu build web dengan `--dart-define=PROXY_URL=http://localhost:8787` dan sajikan `app/build/web`
(mis. `python -m http.server 8080`).

## Catatan teknis

- Database di web adalah SQLite WebAssembly (`app/web/sqlite3.wasm`) yang disimpan di IndexedDB browser,
  dengan skema yang sama seperti di Android. Versi `sqlite3.wasm` harus sama dengan paket `sqlite3` di
  `pubspec.lock` (sekarang 3.5.2); unduh ulang dari rilis `simolus3/sqlite3.dart` bila paketnya naik.
- pdf.js 3.11.174 disajikan dari situs sendiri (tanpa CDN). Lisensinya (Apache-2.0) ada di `app/web/pdfjs/LICENSE`.
- Worker hanya melayani `https://budi.kemendikdasmen.go.id/storage/...`, menolak pengalihan ke host lain,
  dan membatasi berkas 300 MB.
