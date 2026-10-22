import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../models/book.dart';

/// Memuat katalog: salinan terbaru yang tersimpan, atau bawaan aplikasi,
/// lalu memperbarui dari internet di latar belakang.
class CatalogRepository {
  static const _assetPath = 'assets/catalog.json';
  static const _minBooks = 100;

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'catalog.json'));
  }

  Future<Catalog> loadLocal() async {
    final file = await _cacheFile();
    if (await file.exists()) {
      try {
        final catalog = await compute(_parse, await file.readAsString());
        if (catalog.books.length >= _minBooks) return catalog;
      } catch (e) {
        debugPrint('Katalog tersimpan rusak, pakai bawaan: $e');
      }
    }
    return compute(_parse, await rootBundle.loadString(_assetPath));
  }

  /// Mengembalikan katalog baru bila ada pembaruan, atau null.
  Future<Catalog?> refresh({required DateTime? current, bool force = false}) async {
    if (AppConfig.catalogUrl.isEmpty) return null;
    final file = await _cacheFile();
    if (!force && await file.exists()) {
      final age = DateTime.now().difference(await file.lastModified());
      if (age < AppConfig.catalogRefreshInterval) return null;
    }
    try {
      final res = await http
          .get(Uri.parse(AppConfig.catalogUrl), headers: {'User-Agent': AppConfig.userAgent})
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      final body = utf8.decode(res.bodyBytes);
      final catalog = await compute(_parse, body);
      if (catalog.books.length < _minBooks) return null;
      await file.writeAsString(body, flush: true);
      final isNewer = current == null || catalog.generatedAt == null || catalog.generatedAt!.isAfter(current);
      return isNewer ? catalog : null;
    } catch (e) {
      debugPrint('Gagal memperbarui katalog: $e');
      return null;
    }
  }
}

Catalog _parse(String body) => Catalog.fromJson(jsonDecode(body) as Map<String, dynamic>);
