/// Model katalog. Strukturnya mengikuti catalog.json yang dihasilkan
/// catalog/build_catalog.py.
library;

enum BookFormat { pdf, audio, video }

class Book {
  const Book({
    required this.id,
    required this.source,
    required this.title,
    required this.authors,
    required this.illustrators,
    required this.publisher,
    required this.levels,
    required this.readingLevel,
    required this.readingLevelLabel,
    required this.kind,
    required this.format,
    required this.language,
    required this.themes,
    required this.cover,
    required this.media,
    required this.pageUrl,
    required this.pages,
    required this.synopsis,
    required this.isbn,
    required this.rating,
    required this.views,
    required this.updatedAt,
  });

  final String id;
  final String source; // sibi | budi
  final String title;
  final String authors;
  final String illustrators;
  final String publisher;
  final List<String> levels; // paud | sd_awal | sd_tinggi
  final String? readingLevel; // A, B1, B2, B3, C (SIBI)
  final String? readingLevelLabel;
  final String kind; // buku | komik | audio | video
  final BookFormat format;
  final String language;
  final List<String> themes;
  final String cover;
  final String media;
  final String pageUrl;
  final int? pages;
  final String synopsis;
  final String isbn;
  final double? rating;
  final int views;
  final DateTime? updatedAt;

  String get sourceName => source == 'sibi' ? 'SIBI Kemendikdasmen' : 'BUDI Kemendikdasmen';

  String get mediaExtension {
    final path = Uri.tryParse(media)?.path.toLowerCase() ?? '';
    final ext = path.contains('.') ? path.split('.').last : '';
    if (RegExp(r'^[a-z0-9]{2,4}$').hasMatch(ext)) return ext;
    return switch (format) {
      BookFormat.pdf => 'pdf',
      BookFormat.video => 'mp4',
      BookFormat.audio => 'mp3',
    };
  }

  factory Book.fromJson(Map<String, dynamic> j) => Book(
    id: j['id'] as String,
    source: j['source'] as String? ?? '',
    title: j['title'] as String? ?? '',
    authors: _text(j['authors']),
    illustrators: _text(j['illustrators']),
    publisher: _text(j['publisher']),
    levels: (j['levels'] as List?)?.cast<String>() ?? const [],
    readingLevel: j['readingLevel'] as String?,
    readingLevelLabel: j['readingLevelLabel'] as String?,
    kind: j['kind'] as String? ?? 'buku',
    format: switch (j['format']) {
      'audio' => BookFormat.audio,
      'video' => BookFormat.video,
      _ => BookFormat.pdf,
    },
    language: j['language'] as String? ?? 'Indonesia',
    themes: (j['themes'] as List?)?.cast<String>() ?? const [],
    cover: j['cover'] as String? ?? '',
    media: j['media'] as String? ?? '',
    pageUrl: j['pageUrl'] as String? ?? '',
    pages: (j['pages'] as num?)?.toInt(),
    synopsis: j['synopsis'] as String? ?? '',
    isbn: j['isbn'] as String? ?? '',
    rating: (j['rating'] as num?)?.toDouble(),
    views: (j['views'] as num?)?.toInt() ?? 0,
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
  );
}

class TaxonomyItem {
  const TaxonomyItem(this.id, this.label, [this.count = 0]);

  final String id;
  final String label;
  final int count;

  factory TaxonomyItem.fromJson(Map<String, dynamic> j) =>
      TaxonomyItem(j['id'] as String, j['label'] as String, (j['count'] as num?)?.toInt() ?? 0);
}

class Catalog {
  Catalog({
    required this.generatedAt,
    required this.books,
    required this.levels,
    required this.kinds,
    required this.themes,
    required this.languages,
  }) : byId = {for (final b in books) b.id: b};

  final DateTime? generatedAt;
  final List<Book> books;
  final List<TaxonomyItem> levels;
  final List<TaxonomyItem> kinds;
  final List<TaxonomyItem> themes;
  final List<TaxonomyItem> languages;
  final Map<String, Book> byId;

  factory Catalog.fromJson(Map<String, dynamic> j) {
    final tax = j['taxonomy'] as Map<String, dynamic>? ?? const {};
    List<TaxonomyItem> items(String key) =>
        ((tax[key] as List?) ?? const []).map((e) => TaxonomyItem.fromJson(e as Map<String, dynamic>)).toList();
    return Catalog(
      generatedAt: DateTime.tryParse(j['generatedAt'] as String? ?? ''),
      books: ((j['books'] as List?) ?? const [])
          .map((e) => Book.fromJson(e as Map<String, dynamic>))
          .where((b) => b.title.isNotEmpty && b.media.isNotEmpty)
          .toList(growable: false),
      levels: items('levels'),
      kinds: items('kinds'),
      themes: items('themes'),
      languages: items('languages'),
    );
  }
}

/// Nilai kosong dari sumber kadang ditulis "-"; anggap saja kosong.
String _text(Object? v) {
  final s = (v as String? ?? '').trim();
  return const {'-', '–', '—', '.'}.contains(s) ? '' : s;
}
