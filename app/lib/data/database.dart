import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/profile.dart';

/// Posisi terakhir sebuah buku. Untuk PDF [position] = indeks halaman,
/// untuk audio/video = milidetik.
class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    required this.position,
    required this.length,
    required this.finished,
    required this.updatedAt,
  });

  final String bookId;
  final int position;
  final int length;
  final bool finished;
  final DateTime updatedAt;

  double get fraction => length <= 0 ? 0 : ((position + 1) / length).clamp(0.0, 1.0);

  factory ReadingProgress.fromRow(Map<String, Object?> r) => ReadingProgress(
    bookId: r['book_id'] as String,
    position: r['position'] as int,
    length: r['length'] as int,
    finished: (r['finished'] as int) == 1,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
  );
}

class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.page,
    required this.color,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final String bookId;
  final int page;
  final int color;
  final String note;
  final DateTime createdAt;

  factory Bookmark.fromRow(Map<String, Object?> r) => Bookmark(
    id: r['id'] as int,
    bookId: r['book_id'] as String,
    page: r['page'] as int,
    color: r['color'] as int,
    note: r['note'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
  );
}

class DownloadEntry {
  const DownloadEntry({
    required this.bookId,
    required this.path,
    required this.bytes,
    required this.lastOpened,
    required this.pinned,
  });

  final String bookId;
  final String path;
  final int bytes;
  final DateTime lastOpened;
  final bool pinned;

  factory DownloadEntry.fromRow(Map<String, Object?> r) => DownloadEntry(
    bookId: r['book_id'] as String,
    path: r['path'] as String,
    bytes: r['bytes'] as int,
    lastOpened: DateTime.fromMillisecondsSinceEpoch(r['last_opened'] as int),
    pinned: (r['pinned'] as int) == 1,
  );
}

/// Semua data pengguna disimpan di perangkat saja.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static Future<AppDatabase> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'qorybook.db'),
      version: 2,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _migrateV2(db);
      },
      onCreate: (db, _) async {
        final batch = db.batch()
          ..execute('''
            CREATE TABLE profiles(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              avatar TEXT NOT NULL,
              levels TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )''')
          ..execute('''
            CREATE TABLE progress(
              profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
              book_id TEXT NOT NULL,
              position INTEGER NOT NULL,
              length INTEGER NOT NULL,
              finished INTEGER NOT NULL DEFAULT 0,
              started_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              PRIMARY KEY(profile_id, book_id)
            )''')
          ..execute('''
            CREATE TABLE bookmarks(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
              book_id TEXT NOT NULL,
              page INTEGER NOT NULL,
              color INTEGER NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              UNIQUE(profile_id, book_id, page)
            )''')
          ..execute('''
            CREATE TABLE favorites(
              profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
              book_id TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              PRIMARY KEY(profile_id, book_id)
            )''')
          ..execute('''
            CREATE TABLE sessions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
              book_id TEXT NOT NULL,
              started_at INTEGER NOT NULL,
              seconds INTEGER NOT NULL
            )''')
          ..execute('CREATE INDEX sessions_profile ON sessions(profile_id, started_at)')
          ..execute('''
            CREATE TABLE downloads(
              book_id TEXT PRIMARY KEY,
              path TEXT NOT NULL,
              bytes INTEGER NOT NULL,
              last_opened INTEGER NOT NULL,
              pinned INTEGER NOT NULL DEFAULT 0
            )''')
          ..insert('profiles', {
            'name': 'Anak',
            'avatar': 'fox',
            'levels': 'paud,sd_awal,sd_tinggi',
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        await batch.commit(noResult: true);
        await _migrateV2(db);
      },
    );
    return AppDatabase._(db);
  }

  /// Versi 2: batas waktu layar, jam tidur, dan daftar buku pilihan orang tua.
  static Future<void> _migrateV2(Database db) async {
    final batch = db.batch()
      ..execute('ALTER TABLE profiles ADD COLUMN daily_limit_minutes INTEGER NOT NULL DEFAULT 0')
      ..execute('ALTER TABLE profiles ADD COLUMN bedtime_start INTEGER')
      ..execute('ALTER TABLE profiles ADD COLUMN bedtime_end INTEGER')
      ..execute('ALTER TABLE profiles ADD COLUMN curated_only INTEGER NOT NULL DEFAULT 0')
      ..execute('''
        CREATE TABLE approved_books(
          profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
          book_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY(profile_id, book_id)
        )''')
      ..execute('''
        CREATE TABLE screen_time(
          profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
          day TEXT NOT NULL,
          seconds INTEGER NOT NULL,
          PRIMARY KEY(profile_id, day)
        )''');
    await batch.commit(noResult: true);
  }

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  // ---- profil anak ---------------------------------------------------------

  Future<List<ChildProfile>> profiles() async =>
      (await _db.query('profiles', orderBy: 'id ASC')).map(ChildProfile.fromRow).toList();

  Future<int> addProfile(String name, String avatar, Set<String> levels) =>
      _db.insert('profiles', {'name': name, 'avatar': avatar, 'levels': levels.join(','), 'created_at': _now});

  Future<void> updateProfile(ChildProfile p) => _db.update(
    'profiles',
    {
      'name': p.name,
      'avatar': p.avatar,
      'levels': p.levels.join(','),
      'daily_limit_minutes': p.dailyLimitMinutes,
      'bedtime_start': p.bedtime?.start,
      'bedtime_end': p.bedtime?.end,
      'curated_only': p.curatedOnly ? 1 : 0,
    },
    where: 'id = ?',
    whereArgs: [p.id],
  );

  /// Menghapus profil beserta progres, penanda, favorit, dan riwayatnya.
  Future<void> deleteProfile(int id) => _db.transaction((txn) async {
    for (final table in ['progress', 'bookmarks', 'favorites', 'sessions', 'approved_books', 'screen_time']) {
      await txn.delete(table, where: 'profile_id = ?', whereArgs: [id]);
    }
    await txn.delete('profiles', where: 'id = ?', whereArgs: [id]);
  });

  /// Jumlah buku selesai per profil.
  Future<int> finishedCount(int profileId) async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM progress WHERE profile_id = ? AND finished = 1', [
      profileId,
    ]);
    return (rows.single['n'] as num).toInt();
  }

  // ---- buku pilihan orang tua ----------------------------------------------

  Future<Set<String>> approvedBooks(int profileId) async {
    final rows = await _db.query(
      'approved_books',
      columns: ['book_id'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    return {for (final r in rows) r['book_id'] as String};
  }

  Future<void> setApproved(int profileId, Iterable<String> bookIds, bool approved) async {
    final batch = _db.batch();
    for (final id in bookIds) {
      if (approved) {
        batch.insert('approved_books', {
          'profile_id': profileId,
          'book_id': id,
          'created_at': _now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } else {
        batch.delete('approved_books', where: 'profile_id = ? AND book_id = ?', whereArgs: [profileId, id]);
      }
    }
    await batch.commit(noResult: true);
  }

  // ---- waktu layar ---------------------------------------------------------

  /// Detik di Mode Anak pada hari [day] (yyyy-mm-dd).
  Future<int> screenTime(int profileId, String day) async {
    final rows = await _db.query(
      'screen_time',
      columns: ['seconds'],
      where: 'profile_id = ? AND day = ?',
      whereArgs: [profileId, day],
    );
    return rows.isEmpty ? 0 : rows.single['seconds'] as int;
  }

  Future<void> addScreenTime(int profileId, String day, int seconds) => _db.transaction((txn) async {
    final n = await txn.rawUpdate('UPDATE screen_time SET seconds = seconds + ? WHERE profile_id = ? AND day = ?', [
      seconds,
      profileId,
      day,
    ]);
    if (n == 0) {
      await txn.insert('screen_time', {'profile_id': profileId, 'day': day, 'seconds': seconds});
    }
  });

  // ---- progres -------------------------------------------------------------

  Future<Map<String, ReadingProgress>> allProgress(int profileId) async {
    final rows = await _db.query('progress', where: 'profile_id = ?', whereArgs: [profileId]);
    return {for (final r in rows) r['book_id'] as String: ReadingProgress.fromRow(r)};
  }

  Future<ReadingProgress> saveProgress(
    int profileId,
    String bookId, {
    required int position,
    required int length,
    bool? finished,
  }) async {
    // Tanpa UPSERT karena SQLite di Android 9 ke bawah belum mendukungnya.
    final now = _now;
    return _db.transaction((txn) async {
      const where = 'profile_id = ? AND book_id = ?';
      final args = [profileId, bookId];
      final old = await txn.query('progress', where: where, whereArgs: args);
      if (old.isEmpty) {
        await txn.insert('progress', {
          'profile_id': profileId,
          'book_id': bookId,
          'position': position,
          'length': length,
          'finished': (finished ?? false) ? 1 : 0,
          'started_at': now,
          'updated_at': now,
        });
      } else {
        final wasFinished = (old.single['finished'] as int) == 1;
        await txn.update(
          'progress',
          {
            'position': position,
            'length': length,
            'finished': (wasFinished || (finished ?? false)) ? 1 : 0,
            'updated_at': now,
          },
          where: where,
          whereArgs: args,
        );
      }
      final rows = await txn.query('progress', where: where, whereArgs: args);
      return ReadingProgress.fromRow(rows.single);
    });
  }

  Future<void> removeProgress(int profileId, String bookId) =>
      _db.delete('progress', where: 'profile_id = ? AND book_id = ?', whereArgs: [profileId, bookId]);

  // ---- favorit -------------------------------------------------------------

  Future<List<String>> favorites(int profileId) async {
    final rows = await _db.query(
      'favorites',
      columns: ['book_id'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'created_at DESC',
    );
    return [for (final r in rows) r['book_id'] as String];
  }

  Future<void> setFavorite(int profileId, String bookId, bool value) async {
    if (value) {
      await _db.insert('favorites', {
        'profile_id': profileId,
        'book_id': bookId,
        'created_at': _now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await _db.delete('favorites', where: 'profile_id = ? AND book_id = ?', whereArgs: [profileId, bookId]);
    }
  }

  // ---- penanda halaman -----------------------------------------------------

  Future<List<Bookmark>> bookmarks(int profileId, {String? bookId}) async {
    final rows = await _db.query(
      'bookmarks',
      where: bookId == null ? 'profile_id = ?' : 'profile_id = ? AND book_id = ?',
      whereArgs: bookId == null ? [profileId] : [profileId, bookId],
      orderBy: bookId == null ? 'created_at DESC' : 'page ASC',
    );
    return rows.map(Bookmark.fromRow).toList();
  }

  Future<void> addBookmark(int profileId, String bookId, int page, int color, {String note = ''}) => _db.insert(
    'bookmarks',
    {'profile_id': profileId, 'book_id': bookId, 'page': page, 'color': color, 'note': note, 'created_at': _now},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> removeBookmark(int profileId, String bookId, int page) => _db.delete(
    'bookmarks',
    where: 'profile_id = ? AND book_id = ? AND page = ?',
    whereArgs: [profileId, bookId, page],
  );

  // ---- sesi baca (untuk "sering dibaca" & laporan) -------------------------

  Future<void> addSession(int profileId, String bookId, DateTime start, int seconds) {
    if (seconds < 5) return Future.value();
    return _db.insert('sessions', {
      'profile_id': profileId,
      'book_id': bookId,
      'started_at': start.millisecondsSinceEpoch,
      'seconds': seconds,
    });
  }

  /// Total detik membaca per buku, terbanyak dulu.
  Future<Map<String, int>> readingTimeByBook(int profileId, {DateTime? since}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT book_id, SUM(seconds) AS total, COUNT(*) AS opens FROM sessions
      WHERE profile_id = ? AND started_at >= ?
      GROUP BY book_id ORDER BY opens DESC, total DESC
    ''',
      [profileId, since?.millisecondsSinceEpoch ?? 0],
    );
    return {for (final r in rows) r['book_id'] as String: (r['total'] as num).toInt()};
  }

  /// Total detik membaca per hari (kunci yyyy-mm-dd).
  Future<Map<String, int>> readingTimeByDay(int profileId, DateTime since) async {
    final rows = await _db.rawQuery(
      '''
      SELECT date(started_at / 1000, 'unixepoch', 'localtime') AS day, SUM(seconds) AS total
      FROM sessions WHERE profile_id = ? AND started_at >= ?
      GROUP BY day
    ''',
      [profileId, since.millisecondsSinceEpoch],
    );
    return {for (final r in rows) r['day'] as String: (r['total'] as num).toInt()};
  }

  // ---- unduhan -------------------------------------------------------------

  Future<DownloadEntry?> download(String bookId) async {
    final rows = await _db.query('downloads', where: 'book_id = ?', whereArgs: [bookId]);
    return rows.isEmpty ? null : DownloadEntry.fromRow(rows.single);
  }

  Future<List<DownloadEntry>> downloads() async =>
      (await _db.query('downloads', orderBy: 'last_opened ASC')).map(DownloadEntry.fromRow).toList();

  Future<void> putDownload(String bookId, String path, int bytes, {bool? pinned}) async {
    final existing = await download(bookId);
    await _db.insert('downloads', {
      'book_id': bookId,
      'path': path,
      'bytes': bytes,
      'last_opened': _now,
      'pinned': (pinned ?? existing?.pinned ?? false) ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> touchDownload(String bookId) =>
      _db.update('downloads', {'last_opened': _now}, where: 'book_id = ?', whereArgs: [bookId]);

  Future<void> setPinned(String bookId, bool pinned) =>
      _db.update('downloads', {'pinned': pinned ? 1 : 0}, where: 'book_id = ?', whereArgs: [bookId]);

  Future<void> removeDownload(String bookId) => _db.delete('downloads', where: 'book_id = ?', whereArgs: [bookId]);
}
