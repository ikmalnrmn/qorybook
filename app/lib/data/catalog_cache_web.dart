/// Web: tidak ada penyimpanan file. Cache HTTP browser sudah cukup untuk katalog.
class CatalogCache {
  Future<String?> read() async => null;

  Future<DateTime?> modified() async => null;

  Future<void> write(String body) async {}
}
