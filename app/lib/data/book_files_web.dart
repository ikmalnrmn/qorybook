import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../config.dart';
import '../models/book.dart';
import 'database.dart';

/// Versi web: tidak ada penyimpanan file, buku dibuka langsung dari URL-nya
/// (BUDI lewat proxy). API-nya sama dengan versi Android.
class BookFiles {
  BookFiles(this.db, {this.cacheLimitBytes = AppConfig.defaultCacheLimitBytes});

  final AppDatabase db;
  int cacheLimitBytes;

  bool get supportsOffline => false;

  /// Tidak dipakai di web, tetapi UI membacanya.
  final progress = <String, ValueNotifier<double?>>{};

  ValueNotifier<double?> progressOf(String bookId) => progress.putIfAbsent(bookId, () => ValueNotifier<double?>(null));

  Future<String?> localPath(Book book) async => null;

  /// Di web, "lokal" berarti URL yang bisa dibaca browser.
  Future<String> ensureLocal(Book book, {bool pin = false}) async => book.mediaUrl;

  Future<VideoPlayerController> videoController(Book book) async =>
      VideoPlayerController.networkUrl(Uri.parse(book.mediaUrl));

  Future<bool> isPinned(Book book) async => false;

  Future<void> setPinned(Book book, bool pinned) async {}

  Future<void> delete(Book book) async {}

  Future<int> usedBytes() async => 0;

  Future<void> clearCache({bool includePinned = false}) async {}
}
