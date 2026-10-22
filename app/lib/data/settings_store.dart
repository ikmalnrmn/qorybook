import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Pengaturan kecil yang disimpan di SharedPreferences.
class SettingsStore {
  SettingsStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsStore> open() async => SettingsStore._(await SharedPreferences.getInstance());

  static const _kRecentSearches = 'recent_searches';
  static const _kCacheLimit = 'cache_limit_bytes';
  static const _kWarmLight = 'reader_warm_light';
  static const _kTwoPage = 'reader_two_page';
  static const _kProfileId = 'active_profile_id';

  static const _kOnboarded = 'onboarded';
  static const _kPinHash = 'parent_pin_hash';
  static const _kPinSalt = 'parent_pin_salt';
  static const _kFailedAttempts = 'parent_pin_failed';
  static const _kLockedUntil = 'parent_pin_locked_until';
  static const _kKioskPin = 'kiosk_pin_screen';
  static const _kKioskDnd = 'kiosk_dnd';
  static const _kKioskCalls = 'kiosk_allow_calls';

  int get activeProfileId => _prefs.getInt(_kProfileId) ?? 1;
  set activeProfileId(int v) => _prefs.setInt(_kProfileId, v);

  /// Waktu tambahan dari orang tua: batas harian dan jam tidur diabaikan sampai waktu ini.
  DateTime? extraTimeUntil(int profileId) {
    final ms = _prefs.getInt('extra_time_until_$profileId');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setExtraTimeUntil(int profileId, DateTime? until) => until == null
      ? _prefs.remove('extra_time_until_$profileId')
      : _prefs.setInt('extra_time_until_$profileId', until.millisecondsSinceEpoch);

  /// Orang tua sudah menyelesaikan pengaturan awal.
  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;
  set onboarded(bool v) => _prefs.setBool(_kOnboarded, v);

  String? get pinHash => _prefs.getString(_kPinHash);
  String? get pinSalt => _prefs.getString(_kPinSalt);

  Future<void> setPin(String hash, String salt) async {
    await _prefs.setString(_kPinHash, hash);
    await _prefs.setString(_kPinSalt, salt);
  }

  int get failedAttempts => _prefs.getInt(_kFailedAttempts) ?? 0;
  set failedAttempts(int v) => _prefs.setInt(_kFailedAttempts, v);

  DateTime? get lockedUntil {
    final ms = _prefs.getInt(_kLockedUntil);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  set lockedUntil(DateTime? v) =>
      v == null ? _prefs.remove(_kLockedUntil) : _prefs.setInt(_kLockedUntil, v.millisecondsSinceEpoch);

  /// Sematkan layar saat Mode Anak.
  bool get kioskPinScreen => _prefs.getBool(_kKioskPin) ?? true;
  set kioskPinScreen(bool v) => _prefs.setBool(_kKioskPin, v);

  /// Nyalakan Jangan Ganggu saat Mode Anak.
  bool get kioskDnd => _prefs.getBool(_kKioskDnd) ?? true;
  set kioskDnd(bool v) => _prefs.setBool(_kKioskDnd, v);

  /// Tetap izinkan telepon dari kontak berbintang saat Jangan Ganggu.
  bool get kioskAllowCalls => _prefs.getBool(_kKioskCalls) ?? true;
  set kioskAllowCalls(bool v) => _prefs.setBool(_kKioskCalls, v);

  List<String> get recentSearches => _prefs.getStringList(_kRecentSearches) ?? const [];

  Future<void> addRecentSearch(String query) {
    final q = query.trim();
    if (q.length < 2) return Future.value();
    final list = [q, ...recentSearches.where((e) => e.toLowerCase() != q.toLowerCase())].take(8).toList();
    return _prefs.setStringList(_kRecentSearches, list);
  }

  Future<void> clearRecentSearches() => _prefs.remove(_kRecentSearches);

  int get cacheLimitBytes => _prefs.getInt(_kCacheLimit) ?? AppConfig.defaultCacheLimitBytes;
  set cacheLimitBytes(int v) => _prefs.setInt(_kCacheLimit, v);

  /// Filter cahaya hangat di pembaca (nyaman untuk mata malam hari).
  bool get warmLight => _prefs.getBool(_kWarmLight) ?? false;
  set warmLight(bool v) => _prefs.setBool(_kWarmLight, v);

  /// Tampilkan dua halaman sekaligus saat layar mendatar.
  bool get twoPage => _prefs.getBool(_kTwoPage) ?? true;
  set twoPage(bool v) => _prefs.setBool(_kTwoPage, v);
}
