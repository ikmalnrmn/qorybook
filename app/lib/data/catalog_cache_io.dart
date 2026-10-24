import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Salinan katalog terbaru di penyimpanan aplikasi.
class CatalogCache {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'catalog.json'));
  }

  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  /// Kapan salinan terakhir ditulis, atau null bila belum ada.
  Future<DateTime?> modified() async {
    final file = await _file();
    return await file.exists() ? file.lastModified() : null;
  }

  Future<void> write(String body) async => (await _file()).writeAsString(body, flush: true);
}
