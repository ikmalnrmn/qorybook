import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../models/book.dart';
import 'database.dart';

/// Mengunduh file buku saat dibuka dan menyimpannya di cache terbatas.
/// Buku yang "disimpan offline" (pinned) tidak ikut terhapus.
class BookFiles {
  BookFiles(this._db, {this.cacheLimitBytes = AppConfig.defaultCacheLimitBytes});

  final AppDatabase _db;
  int cacheLimitBytes;
  final _client = http.Client();
  final _inFlight = <String, Future<File>>{};

  /// Progres unduhan per buku (0..1), untuk ditampilkan di UI.
  final progress = <String, ValueNotifier<double?>>{};

  ValueNotifier<double?> progressOf(String bookId) => progress.putIfAbsent(bookId, () => ValueNotifier<double?>(null));

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'books'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File?> localFile(Book book) async {
    final entry = await _db.download(book.id);
    if (entry == null) return null;
    final file = File(entry.path);
    if (await file.exists()) return file;
    await _db.removeDownload(book.id);
    return null;
  }

  Future<bool> isPinned(Book book) async => (await _db.download(book.id))?.pinned ?? false;

  /// File lokal buku; diunduh dulu bila belum ada.
  Future<File> ensureLocal(Book book, {bool pin = false}) {
    return _inFlight.putIfAbsent(book.id, () async {
      try {
        final existing = await localFile(book);
        if (existing != null) {
          await _db.touchDownload(book.id);
          if (pin) await _db.setPinned(book.id, true);
          return existing;
        }
        final file = await _download(book);
        await _db.putDownload(book.id, file.path, await file.length(), pinned: pin);
        unawaited(_evict());
        return file;
      } finally {
        _inFlight.remove(book.id);
      }
    });
  }

  Future<File> _download(Book book) async {
    final dir = await _dir();
    final safeId = book.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final target = File(p.join(dir.path, '$safeId.${book.mediaExtension}'));
    final part = File('${target.path}.part');
    final notifier = progressOf(book.id)..value = 0;

    final req = http.Request('GET', Uri.parse(book.media))..headers['User-Agent'] = AppConfig.userAgent;
    final res = await _client.send(req).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      notifier.value = null;
      throw HttpException('Server mengembalikan ${res.statusCode}', uri: req.url);
    }
    final total = res.contentLength ?? 0;
    var received = 0;
    final sink = part.openWrite();
    try {
      await for (final chunk in res.stream.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) notifier.value = received / total;
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await part.exists()) await part.delete();
      notifier.value = null;
      rethrow;
    }
    await sink.close();
    if (total > 0 && received < total) {
      await part.delete();
      notifier.value = null;
      throw const HttpException('Unduhan terputus');
    }
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
    notifier.value = null;
    return target;
  }

  Future<void> setPinned(Book book, bool pinned) async {
    if (pinned) {
      await ensureLocal(book, pin: true);
    } else {
      await _db.setPinned(book.id, false);
      unawaited(_evict());
    }
  }

  Future<void> delete(Book book) async {
    final entry = await _db.download(book.id);
    if (entry == null) return;
    final file = File(entry.path);
    if (await file.exists()) await file.delete();
    await _db.removeDownload(book.id);
  }

  Future<int> usedBytes() async => (await _db.downloads()).fold<int>(0, (sum, e) => sum + e.bytes);

  Future<void> clearCache({bool includePinned = false}) async {
    for (final e in await _db.downloads()) {
      if (e.pinned && !includePinned) continue;
      final f = File(e.path);
      if (await f.exists()) await f.delete();
      await _db.removeDownload(e.bookId);
    }
  }

  /// Hapus file yang paling lama tidak dibuka sampai di bawah batas.
  Future<void> _evict() async {
    final entries = await _db.downloads(); // urut last_opened ASC
    var used = entries.fold<int>(0, (sum, e) => sum + e.bytes);
    for (final e in entries) {
      if (used <= cacheLimitBytes) break;
      if (e.pinned) continue;
      final f = File(e.path);
      if (await f.exists()) await f.delete();
      await _db.removeDownload(e.bookId);
      used -= e.bytes;
    }
  }
}
