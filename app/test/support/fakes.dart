import 'dart:convert';
import 'dart:io';

import 'package:qorybook/data/catalog_repository.dart';
import 'package:qorybook/data/database.dart';
import 'package:qorybook/models/book.dart';
import 'package:qorybook/models/profile.dart';
import 'package:qorybook/services/kiosk.dart';

/// Database di memori untuk widget test (tanpa sqflite).
class FakeDatabase implements AppDatabase {
  final profileRows = <ChildProfile>[
    const ChildProfile(id: 1, name: 'Anak', avatar: 'fox', levels: {'paud', 'sd_awal', 'sd_tinggi'}),
  ];
  final progressRows = <String, ReadingProgress>{};

  @override
  Future<List<ChildProfile>> profiles() async => List.of(profileRows);

  @override
  Future<int> addProfile(String name, String avatar, Set<String> levels) async {
    final id = profileRows.fold<int>(0, (m, p) => p.id > m ? p.id : m) + 1;
    profileRows.add(ChildProfile(id: id, name: name, avatar: avatar, levels: levels));
    return id;
  }

  @override
  Future<void> updateProfile(ChildProfile p) async {
    final i = profileRows.indexWhere((e) => e.id == p.id);
    if (i >= 0) profileRows[i] = p;
  }

  @override
  Future<void> deleteProfile(int id) async => profileRows.removeWhere((p) => p.id == id);

  @override
  Future<int> finishedCount(int profileId) async => progressRows.values.where((p) => p.finished).length;

  final approved = <int, Set<String>>{};
  final screenSeconds = <String, int>{};

  @override
  Future<Set<String>> approvedBooks(int profileId) async => {...?approved[profileId]};

  @override
  Future<void> setApproved(int profileId, Iterable<String> bookIds, bool value) async {
    final set = approved.putIfAbsent(profileId, () => {});
    value ? set.addAll(bookIds) : set.removeAll(bookIds);
  }

  @override
  Future<int> screenTime(int profileId, String day) async => screenSeconds['$profileId|$day'] ?? 0;

  @override
  Future<void> addScreenTime(int profileId, String day, int seconds) async =>
      screenSeconds['$profileId|$day'] = (screenSeconds['$profileId|$day'] ?? 0) + seconds;
  final favoriteIds = <String>[];
  final marks = <Bookmark>[];
  final sessions = <String, int>{};
  final downloadRows = <String, DownloadEntry>{};

  @override
  Future<Map<String, ReadingProgress>> allProgress(int profileId) async => Map.of(progressRows);

  @override
  Future<ReadingProgress> saveProgress(
    int profileId,
    String bookId, {
    required int position,
    required int length,
    bool? finished,
  }) async {
    final old = progressRows[bookId];
    return progressRows[bookId] = ReadingProgress(
      bookId: bookId,
      position: position,
      length: length,
      finished: (old?.finished ?? false) || (finished ?? false),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> removeProgress(int profileId, String bookId) async => progressRows.remove(bookId);

  @override
  Future<List<String>> favorites(int profileId) async => List.of(favoriteIds);

  @override
  Future<void> setFavorite(int profileId, String bookId, bool value) async {
    favoriteIds.remove(bookId);
    if (value) favoriteIds.insert(0, bookId);
  }

  @override
  Future<List<Bookmark>> bookmarks(int profileId, {String? bookId}) async =>
      marks.where((m) => bookId == null || m.bookId == bookId).toList();

  @override
  Future<void> addBookmark(int profileId, String bookId, int page, int color, {String note = ''}) async {
    marks.removeWhere((m) => m.bookId == bookId && m.page == page);
    marks.add(
      Bookmark(id: marks.length + 1, bookId: bookId, page: page, color: color, note: note, createdAt: DateTime.now()),
    );
  }

  @override
  Future<void> removeBookmark(int profileId, String bookId, int page) async =>
      marks.removeWhere((m) => m.bookId == bookId && m.page == page);

  @override
  Future<void> addSession(int profileId, String bookId, DateTime start, int seconds) async =>
      sessions[bookId] = (sessions[bookId] ?? 0) + seconds;

  @override
  Future<Map<String, int>> readingTimeByBook(int profileId, {DateTime? since}) async => Map.of(sessions);

  @override
  Future<Map<String, int>> readingTimeByDay(int profileId, DateTime since) async => {};

  @override
  Future<DownloadEntry?> download(String bookId) async => downloadRows[bookId];

  @override
  Future<List<DownloadEntry>> downloads() async => downloadRows.values.toList();

  @override
  Future<void> putDownload(String bookId, String path, int bytes, {bool? pinned}) async {
    downloadRows[bookId] = DownloadEntry(
      bookId: bookId,
      path: path,
      bytes: bytes,
      lastOpened: DateTime.now(),
      pinned: pinned ?? false,
    );
  }

  @override
  Future<void> touchDownload(String bookId) async {}

  @override
  Future<void> setPinned(String bookId, bool pinned) async {}

  @override
  Future<void> removeDownload(String bookId) async => downloadRows.remove(bookId);
}

/// Katalog dari assets/catalog.json tanpa path_provider.
class FakeCatalogRepository extends CatalogRepository {
  @override
  Future<Catalog> loadLocal() async =>
      Catalog.fromJson(jsonDecode(File('assets/catalog.json').readAsStringSync()) as Map<String, dynamic>);

  @override
  Future<Catalog?> refresh({required DateTime? current, bool force = false}) async => null;
}

/// Kanal kiosk palsu yang mencatat panggilan.
class FakeKiosk extends KioskService {
  final calls = <String>[];
  bool pinned = false;
  bool dndActive = false;
  bool dndAccess = true;

  @override
  Future<KioskStatus> status() async => KioskStatus(
    pinned: pinned,
    dndAccess: dndAccess,
    dndActive: dndActive,
    deviceSecure: true,
    pinToUnpin: true,
    available: true,
  );

  @override
  Future<void> startLockTask() async {
    calls.add('pin');
    pinned = true;
  }

  @override
  Future<void> stopLockTask() async {
    calls.add('unpin');
    pinned = false;
  }

  @override
  Future<bool> enableDnd({required bool allowCalls}) async {
    calls.add('dnd:on');
    dndActive = dndAccess;
    return dndAccess;
  }

  @override
  Future<void> restoreDnd() async {
    calls.add('dnd:off');
    dndActive = false;
  }

  @override
  Future<void> openDndAccessSettings() async => calls.add('open:dnd');

  @override
  Future<void> openSecuritySettings() async => calls.add('open:security');

  @override
  Future<bool> openUrl(String url) async {
    calls.add('open:$url');
    return true;
  }
}
