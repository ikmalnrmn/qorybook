import 'package:flutter/foundation.dart' show kIsWeb;

/// Pengaturan build. Alamat katalog diisi saat build:
///   `flutter build apk --dart-define=CATALOG_URL=https://AKUN.github.io/REPO/catalog.json`
/// Jika kosong, aplikasi memakai katalog bawaan (assets/catalog.json).
class AppConfig {
  static const catalogUrl = String.fromEnvironment('CATALOG_URL');

  /// Katalog diperiksa ulang paling cepat setiap interval ini.
  static const catalogRefreshInterval = Duration(hours: 12);

  /// Batas default cache file buku sebelum yang lama dihapus.
  static const defaultCacheLimitBytes = 500 * 1024 * 1024;

  static const userAgent = 'Qorybook/1.0 (Android; aplikasi baca anak)';

  /// Halaman Saweria untuk donasi Keluarga Literasi. Bisa diganti saat build:
  ///   `--dart-define=DONATION_URL=https://saweria.co/AKUN`
  /// Jika dikosongkan, tombol donasi memberi tahu bahwa tautannya segera hadir.
  static const donationUrl = String.fromEnvironment('DONATION_URL', defaultValue: 'https://saweria.co/qorybook');

  /// Backend penghitung pengguna (Supabase). Kosong = tidak ada yang dikirim. Isi saat build:
  ///   `--dart-define=TELEMETRY_URL=https://PROYEK.supabase.co --dart-define=TELEMETRY_KEY=ANON_KEY`
  static const telemetryUrl = String.fromEnvironment('TELEMETRY_URL');
  static const telemetryKey = String.fromEnvironment('TELEMETRY_KEY');

  /// Dari mana APK ini dibagikan (mis. `drive`, `promo`), untuk membandingkan jalur unduhan.
  static const installSource = String.fromEnvironment('INSTALL_SOURCE', defaultValue: 'drive');

  static const appVersion = '1.0.0';
  static String get platform => kIsWeb ? 'web' : 'android';

  /// Alamat Cloudflare Worker (folder `proxy/`) untuk build web. Server BUDI tidak mengirim
  /// header CORS, jadi browser hanya bisa memuat PDF dan sampulnya lewat proxy:
  ///   `flutter build web --dart-define=PROXY_URL=https://qorybook-proxy.AKUN.workers.dev`
  static const proxyUrl = String.fromEnvironment('PROXY_URL');

  /// Di web, URL BUDI dialihkan lewat proxy; URL lain dan build Android tidak berubah.
  static String viaProxy(String url) {
    if (!kIsWeb || proxyUrl.isEmpty) return url;
    if (Uri.tryParse(url)?.host != 'budi.kemendikdasmen.go.id') return url;
    return '${proxyUrl.replaceAll(RegExp(r'/+$'), '')}/budi?u=${Uri.encodeComponent(url)}';
  }

  /// Bagian donasi yang disalurkan untuk pendidikan anak yatim dan dhuafa.
  static const donationCharityPercent = 20;
}
