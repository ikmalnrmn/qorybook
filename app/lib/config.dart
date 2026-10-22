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
}
