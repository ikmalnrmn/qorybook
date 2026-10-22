# Qorybook

Aplikasi baca buku untuk anak (PAUD–SD) di bawah pengawasan orang tua. Isinya hanya buku bacaan
gratis dari pemerintah Indonesia:

- **SIBI** — <https://buku.kemendikdasmen.go.id> (Pusat Perbukuan)
- **BUDI** — <https://budi.kemendikdasmen.go.id> (Badan Bahasa)

Aplikasi tidak menyimpan file buku. Ia hanya membawa katalog (±1 MB); PDF/audio/video diambil
langsung dari server pemerintah saat dibuka, lalu disimpan sementara di HP.

## Struktur

| Folder | Isi |
|---|---|
| `catalog/` | `build_catalog.py`: pengumpul katalog SIBI + BUDI → `catalog.json` (Python, pustaka standar saja) |
| `.github/workflows/catalog.yml` | Menjalankan pengumpul setiap hari pukul 02.00 WIB dan menerbitkan `catalog.json` ke GitHub Pages |
| `app/` | Aplikasi Flutter (Android) |

## Katalog

```bash
cd catalog
python build_catalog.py --out dist/catalog.json --prev dist/catalog.json
```

`--prev` membuat proses berikutnya jauh lebih cepat: halaman detail BUDI yang sudah pernah dibaca
tidak diambil lagi. Jika hasilnya kurang dari 300 buku (misalnya karena situs sumber berubah),
katalog tidak ditulis supaya aplikasi tidak menerima katalog rusak.

Penyaringan:
- SIBI: jenjang A, B1–B3, C, PAUD; hanya yang punya PDF yang bisa diakses; buku guru dibuang.
  Domain lama `static.buku.kemdikbud.go.id` sudah mati, jadi alamatnya diganti ke mirror resmi
  `static.sc.cloudapp.web.id`.
- BUDI: jenjang PAUD dan SD; buku digital, komik, audio, dan video (braille `.brf` dilewati).

## Aplikasi

```bash
cd app
flutter pub get
flutter run                       # memakai katalog bawaan di assets/catalog.json
flutter build apk --release --dart-define=CATALOG_URL=https://<akun>.github.io/<repo>/catalog.json
```

Salin katalog terbaru ke aplikasi sebelum rilis:

```bash
cp catalog/dist/catalog.json app/assets/catalog.json
```

### Fitur (Fase 2)

- Beranda: Lanjutkan Membaca, Populer di Indonesia, Sering Dibaca di Rumah, tema, komik, audio, video, buku baru
- Jelajah: jenjang (PAUD / SD 1–3 / SD 4–6), jenis buku, tema, bahasa
- Pencarian offline yang toleran salah ketik
- Pembaca PDF (PdfRenderer bawaan Android): geser/ketuk tepi, ketuk dua kali untuk perbesar,
  dua halaman saat mendatar, cahaya hangat, penanda berwarna + catatan, lanjut otomatis, layar selesai
- Pemutar buku audio & video
- Rak Bukuku: favorit, sedang dibaca, selesai, penanda
- Simpan offline + batas simpanan sementara

### Mode Anak (Fase 3)

- **Pengaturan awal** (sekali): PIN orang tua 4 angka, profil anak pertama, dan daftar periksa izin.
- **Aplikasi selalu dibuka dalam Mode Anak.** Area Orang Tua hanya bisa dibuka dengan menekan lama
  ikon gembok di Beranda, lalu memasukkan PIN atau memakai sidik jari/kunci layar HP (`local_auth`).
- **Sematkan layar** (`Activity.startLockTask()` di `KioskChannel.kt`): tombol Home/Recent dan panel
  notifikasi tidak bisa dipakai. Android menampilkan dialog "Sematkan aplikasi?" saat pertama; bila
  ditolak atau sematan dilepas, muncul banner "Layar belum dikunci". Agar anak tidak bisa melepas
  sematan, HP harus punya kunci layar dan "Minta PIN sebelum melepas sematan" harus menyala.
- **Jangan Ganggu**: mode prioritas, hanya alarm (+ telepon dari kontak berbintang bila diizinkan),
  semua efek visual notifikasi disembunyikan. Pengaturan Jangan Ganggu milik orang tua disimpan dan
  dipulihkan saat keluar Mode Anak, saat aplikasi ditinggalkan tanpa sematan, atau saat aplikasi
  dibuka lagi setelah tertutup paksa. Butuh izin "Akses Jangan Ganggu" (diberikan sekali).
- **PIN** disimpan sebagai hash SHA-256 bergaram (20.000 putaran); 5 kali salah → terkunci 30 detik,
  bertambah dua kali lipat setiap salah lagi (maks. 10 menit).
- **Profil anak** (maks. 6): nama, avatar, dan jenjang yang boleh dilihat. Progres, penanda, favorit,
  dan riwayat baca terpisah per profil. Area Orang Tua menampilkan menit membaca 7 hari terakhir dan
  jumlah buku selesai.

### Aturan per anak (Fase 4)

- **Batas waktu harian** (15–120 menit atau tanpa batas): waktu di Mode Anak dihitung per profil per
  hari (tabel `screen_time`). Lima menit sebelum habis muncul pengingat; setelah habis, buku/pemutar
  ditutup (progres tetap tersimpan) dan tampil layar istirahat.
- **Jam tidur** (mis. 20.00–06.00, boleh melewati tengah malam): aplikasi menampilkan layar malam.
- Dari layar istirahat, orang tua menekan lama gembok → PIN → **tambah 15/30/60 menit** atau buka
  Area Orang Tua. Waktu tambahan mengabaikan batas harian dan jam tidur sampai habis.
- **Hanya buku pilihan orang tua**: anak hanya melihat buku yang dicentang orang tua di layar
  "Pilih buku" (cari, saring jenis, pilih semua yang tampil).

Batasan: tanpa Device Owner, Android selalu meminta konfirmasi sematan dan orang yang tahu kunci layar
HP tetap bisa melepasnya.

### Tes

```bash
flutter test                                                      # 34 tes
QORY_SHOTS=1 flutter test --update-goldens test/screens_test.dart # simpan tangkapan layar ke test/goldens
```
