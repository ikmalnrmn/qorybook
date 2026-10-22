import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qorybook/models/book.dart';

void main() {
  test('katalog bawaan valid dan hanya berisi PAUD–SD', () {
    final raw = File('assets/catalog.json').readAsStringSync();
    final catalog = Catalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(catalog.books.length, greaterThan(300));
    expect(catalog.byId.length, catalog.books.length, reason: 'id buku harus unik');

    const allowedLevels = {'paud', 'sd_awal', 'sd_tinggi'};
    for (final b in catalog.books) {
      expect(b.levels, isNotEmpty, reason: b.title);
      expect(b.levels.every(allowedLevels.contains), isTrue, reason: '${b.title}: ${b.levels}');
      expect(b.media, startsWith('https://'), reason: b.title);
      expect(b.media, isNot(contains('static.buku.kemdikbud.go.id')), reason: 'domain lama sudah mati');
      if (b.format == BookFormat.pdf) expect(b.media.toLowerCase(), endsWith('.pdf'), reason: b.title);
    }
  });
}
