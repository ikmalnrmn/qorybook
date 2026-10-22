import '../models/book.dart';
import 'labels.dart';

/// Pencarian lokal di katalog: cepat, offline, dan toleran salah ketik.
class BookSearch {
  BookSearch(List<Book> books) : _entries = books.map(_Entry.new).toList(growable: false);

  final List<_Entry> _entries;

  List<Book> search(String query, {int limit = 100, bool Function(Book)? where}) {
    final q = normalize(query);
    if (q.isEmpty) return const [];
    final tokens = q.split(' ');
    final scored = <(Book, int)>[];
    for (final e in _entries) {
      if (where != null && !where(e.book)) continue;
      final s = e.score(q, tokens);
      if (s > 0) scored.add((e.book, s));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      return byScore != 0 ? byScore : b.$1.views.compareTo(a.$1.views);
    });
    return [for (final s in scored.take(limit)) s.$1];
  }

  /// Kata yang sering muncul di judul, untuk saran pencarian.
  List<String> popularWords({int limit = 10}) {
    final counts = <String, int>{};
    for (final e in _entries) {
      for (final w in e.titleWords.toSet()) {
        if (w.length < 4 || _stopWords.contains(w)) continue;
        counts[w] = (counts[w] ?? 0) + 1;
      }
    }
    final list = counts.entries.where((e) => e.value >= 5).toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in list.take(limit)) e.key];
  }

  static const _stopWords = {
    'yang',
    'dari',
    'untuk',
    'dengan',
    'pada',
    'kita',
    'kami',
    'kamu',
    'tidak',
    'bisa',
    'jadi',
    'para',
    'sang',
    'buku',
    'cerita',
    'seri',
    'kelas',
    'jilid',
    'edisi',
    'ingin',
    'mana',
    'ketika',
    'jangan',
    'siapa',
    'semua',
    'suka',
    'baik',
    'baru',
    'hari',
    'mengenal',
    'kisah',
    'anak',
    'kecil',
    'cilik',
    'lagi',
    'akan',
    'juga',
    'mau',
    'mengapa',
    'bagaimana',
    'sudah',
    'belum',
    'sangat',
    'besar',
    'satu',
    'dua',
    'tiga',
    'milik',
    'punya',
    'tentang',
    'bersama',
    'ayo',
    'yuk',
    'aduh',
    'wah',
    'with',
    'the',
    'and',
    'your',
    'from',
    'this',
    'that',
    'have',
  };

  static String normalize(String s) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ñ': 'n',
      'ç': 'c',
    };
    final lower = s.toLowerCase();
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      buf.write(accents[ch] ?? ch);
    }
    return buf.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}

class _Entry {
  _Entry(this.book)
    : title = BookSearch.normalize(book.title),
      people = BookSearch.normalize('${book.authors} ${book.illustrators}'),
      extra = BookSearch.normalize(
        [...book.themes, kindLabel(book.kind), book.language, for (final l in book.levels) levelLabel(l)].join(' '),
      ) {
    titleWords = title.split(' ');
  }

  final Book book;
  final String title;
  final String people;
  final String extra;
  late final List<String> titleWords;

  int score(String q, List<String> tokens) {
    if (title == q) return 1000;
    if (title.startsWith(q)) return 800;
    if (title.contains(q)) return 600;

    var total = 0;
    for (final t in tokens) {
      if (titleWords.any((w) => w.startsWith(t))) {
        total += 120;
      } else if (people.contains(t)) {
        total += 70;
      } else if (extra.contains(t)) {
        total += 40;
      } else if (t.length >= 4 && titleWords.any((w) => _closeEnough(w, t))) {
        total += 50; // salah ketik kecil
      } else {
        return 0; // semua kata harus cocok
      }
    }
    return total;
  }

  static bool _closeEnough(String word, String token) {
    if ((word.length - token.length).abs() > 1) {
      // izinkan juga awalan yang mirip: "kelnci" ~ "kelinci"
      if (word.length > token.length) word = word.substring(0, token.length + 1);
      if ((word.length - token.length).abs() > 1) return false;
    }
    return _levenshtein(word, token) <= (token.length >= 7 ? 2 : 1);
  }

  static int _levenshtein(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev[b.length];
  }
}
