// Android menyimpan salinan katalog sebagai file; web mengambilnya ulang setiap dibuka.
export 'catalog_cache_io.dart' if (dart.library.js_interop) 'catalog_cache_web.dart';
