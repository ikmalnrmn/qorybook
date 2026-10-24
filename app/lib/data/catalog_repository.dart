import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/book.dart';
import 'catalog_cache.dart';

/// Memuat katalog: salinan terbaru yang tersimpan, atau bawaan aplikasi,
/// lalu memperbarui dari internet di latar belakang.
class CatalogRepository {
  static const _assetPath = 'assets/catalog.json';
  static const _minBooks = 100;

  final _cache = CatalogCache();

  Future<Catalog> loadLocal() async {
    final cached = await _cache.read();
    if (cached != null) {
      try {
        final catalog = await compute(_parse, cached);
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
    final saved = await _cache.modified();
    if (!force && saved != null && DateTime.now().difference(saved) < AppConfig.catalogRefreshInterval) return null;
    try {
      // Browser melarang mengubah User-Agent dan header kustom memicu preflight CORS.
      final res = await http
          .get(Uri.parse(AppConfig.catalogUrl), headers: kIsWeb ? null : {'User-Agent': AppConfig.userAgent})
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      final body = utf8.decode(res.bodyBytes);
      final catalog = await compute(_parse, body);
      if (catalog.books.length < _minBooks) return null;
      await _cache.write(body);
      final isNewer = current == null || catalog.generatedAt == null || catalog.generatedAt!.isAfter(current);
      return isNewer ? catalog : null;
    } catch (e) {
      debugPrint('Gagal memperbarui katalog: $e');
      return null;
    }
  }
}

Catalog _parse(String body) => Catalog.fromJson(jsonDecode(body) as Map<String, dynamic>);
