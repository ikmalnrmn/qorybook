import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/book_files.dart';
import '../data/catalog_repository.dart';
import '../data/database.dart';
import '../data/settings_store.dart';
import '../models/book.dart';
import '../models/profile.dart';
import '../services/search.dart';

/// State utama aplikasi: katalog, profil aktif, progres, favorit.
class AppState extends ChangeNotifier {
  AppState({
    required this.db,
    required this.settings,
    required this.files,
    required CatalogRepository catalogRepository,
  }) : _catalogRepo = catalogRepository;

  final AppDatabase db;
  final SettingsStore settings;
  final BookFiles files;
  final CatalogRepository _catalogRepo;

  Catalog? catalog;
  BookSearch? _search;
  Object? loadError;

  /// Saran kata pencarian dari judul-judul di katalog.
  List<String> searchSuggestions = const [];

  int get profileId => settings.activeProfileId;

  List<ChildProfile> profiles = [];

  ChildProfile? get activeProfile => profiles.where((p) => p.id == profileId).firstOrNull ?? profiles.firstOrNull;

  /// Jenjang yang boleh dilihat profil aktif (diatur orang tua).
  Set<String> get allowedLevels {
    final levels = activeProfile?.levels ?? const <String>{};
    return levels.isEmpty ? const {'paud', 'sd_awal', 'sd_tinggi'} : levels;
  }

  bool get onboarded => settings.onboarded;

  Future<void> finishOnboarding() async {
    settings.onboarded = true;
    notifyListeners();
  }

  /// Buku pilihan orang tua untuk profil aktif.
  Set<String> approvedIds = {};

  Map<String, ReadingProgress> progress = {};
  List<String> favoriteIds = [];
  Map<String, int> homeReadingTime = {};

  /// Naik setiap kali penanda berubah, supaya daftar penanda dimuat ulang.
  int bookmarksVersion = 0;

  void bookmarksChanged() {
    bookmarksVersion++;
    notifyListeners();
  }

  Future<void> init() async {
    try {
      catalog = await _catalogRepo.loadLocal();
      _search = BookSearch(catalog!.books);
      searchSuggestions = _search!.popularWords();
      await _loadProfiles();
      await _loadUserData();
    } catch (e) {
      loadError = e;
    }
    notifyListeners();
    unawaited(refreshCatalog());
  }

  Future<void> refreshCatalog({bool force = false}) async {
    final fresh = await _catalogRepo.refresh(current: catalog?.generatedAt, force: force);
    if (fresh == null) return;
    catalog = fresh;
    _search = BookSearch(fresh.books);
    searchSuggestions = _search!.popularWords();
    notifyListeners();
  }

  Future<void> _loadProfiles() async {
    profiles = await db.profiles();
    if (profiles.isNotEmpty && !profiles.any((p) => p.id == settings.activeProfileId)) {
      settings.activeProfileId = profiles.first.id;
    }
  }

  // ---- profil anak ---------------------------------------------------------

  Future<void> switchProfile(int id) async {
    settings.activeProfileId = id;
    await _loadUserData();
    notifyListeners();
  }

  Future<int> addProfile(String name, String avatar, Set<String> levels) async {
    final id = await db.addProfile(name, avatar, levels);
    await _loadProfiles();
    notifyListeners();
    return id;
  }

  Future<void> updateProfile(ChildProfile profile) async {
    await db.updateProfile(profile);
    await _loadProfiles();
    notifyListeners();
  }

  /// Profil terakhir tidak bisa dihapus.
  Future<void> deleteProfile(int id) async {
    if (profiles.length <= 1) return;
    await db.deleteProfile(id);
    await _loadProfiles();
    await _loadUserData();
    notifyListeners();
  }

  /// Ringkasan untuk Area Orang Tua: (menit membaca 7 hari terakhir, buku selesai).
  Future<({int minutes, int finished})> weeklyStats(int id) async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final byDay = await db.readingTimeByDay(id, since);
    final seconds = byDay.values.fold<int>(0, (a, b) => a + b);
    return (minutes: (seconds / 60).round(), finished: await db.finishedCount(id));
  }

  // ---- buku pilihan orang tua ----------------------------------------------

  Future<Set<String>> approvedFor(int profileId) => db.approvedBooks(profileId);

  Future<void> setApproved(int profileId, Iterable<String> bookIds, bool approved) async {
    await db.setApproved(profileId, bookIds, approved);
    if (profileId == this.profileId) {
      approvedIds = await db.approvedBooks(profileId);
      notifyListeners();
    }
  }

  Future<void> _loadUserData() async {
    approvedIds = await db.approvedBooks(profileId);
    progress = await db.allProgress(profileId);
    favoriteIds = await db.favorites(profileId);
    homeReadingTime = await db.readingTimeByBook(profileId);
  }

  // ---- akses katalog -------------------------------------------------------

  bool isAllowed(Book b) {
    if (activeProfile?.curatedOnly ?? false) return approvedIds.contains(b.id);
    return b.levels.any(allowedLevels.contains);
  }

  /// Profil hanya boleh membaca buku pilihan, tetapi belum ada yang dipilih.
  bool get curatedButEmpty => (activeProfile?.curatedOnly ?? false) && approvedIds.isEmpty;

  List<Book> get books => catalog?.books.where(isAllowed).toList() ?? const [];

  Book? bookById(String id) {
    final b = catalog?.byId[id];
    return b != null && isAllowed(b) ? b : null;
  }

  List<Book> filter({String? level, String? kind, String? theme, String? language}) => books
      .where(
        (b) =>
            (level == null || b.levels.contains(level)) &&
            (kind == null || b.kind == kind) &&
            (theme == null || b.themes.contains(theme)) &&
            (language == null || b.language == language),
      )
      .toList();

  List<Book> search(String query) => _search?.search(query, where: isAllowed) ?? const [];

  /// Populer berdasarkan jumlah dilihat di sumber (BUDI).
  List<Book> get popular {
    final list = books.where((b) => b.views > 0).toList()..sort((a, b) => b.views.compareTo(a.views));
    return list;
  }

  List<Book> get newest {
    final list = books.where((b) => b.updatedAt != null).toList()..sort((a, b) => b.updatedAt!.compareTo(a.updatedAt!));
    return list;
  }

  /// Buku yang paling sering dibuka di perangkat ini.
  List<Book> get frequentAtHome => [for (final id in homeReadingTime.keys) ?bookById(id)];

  List<Book> get continueReading {
    final entries = progress.values.where((p) => !p.finished && p.position > 0).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [for (final p in entries) ?bookById(p.bookId)];
  }

  List<Book> get finishedBooks {
    final entries = progress.values.where((p) => p.finished).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [for (final p in entries) ?bookById(p.bookId)];
  }

  List<Book> get favorites => [for (final id in favoriteIds) ?bookById(id)];

  List<Book> related(Book book, {int limit = 12}) {
    final scored = <(Book, int)>[];
    for (final b in books) {
      if (b.id == book.id) continue;
      var s = 0;
      s += b.themes.where(book.themes.contains).length * 3;
      if (b.levels.any(book.levels.contains)) s += 2;
      if (b.kind == book.kind) s += 1;
      if (b.authors.isNotEmpty && b.authors == book.authors) s += 2;
      if (s >= 3) scored.add((b, s));
    }
    scored.sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : b.$1.views.compareTo(a.$1.views));
    return [for (final s in scored.take(limit)) s.$1];
  }

  // ---- data pengguna -------------------------------------------------------

  bool isFavorite(String bookId) => favoriteIds.contains(bookId);

  Future<void> toggleFavorite(String bookId) async {
    final value = !isFavorite(bookId);
    await db.setFavorite(profileId, bookId, value);
    if (value) {
      favoriteIds = [bookId, ...favoriteIds];
    } else {
      favoriteIds = favoriteIds.where((id) => id != bookId).toList();
    }
    notifyListeners();
  }

  Future<void> saveProgress(String bookId, {required int position, required int length, bool? finished}) async {
    final p = await db.saveProgress(profileId, bookId, position: position, length: length, finished: finished);
    progress = {...progress, bookId: p};
    notifyListeners();
  }

  Future<void> resetProgress(String bookId) async {
    await db.removeProgress(profileId, bookId);
    progress = {...progress}..remove(bookId);
    notifyListeners();
  }

  Future<void> recordSession(String bookId, DateTime start) async {
    final seconds = DateTime.now().difference(start).inSeconds;
    await db.addSession(profileId, bookId, start, seconds);
    homeReadingTime = await db.readingTimeByBook(profileId);
    notifyListeners();
  }
}
