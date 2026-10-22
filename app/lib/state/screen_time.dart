import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../data/database.dart';
import '../data/settings_store.dart';
import '../models/profile.dart';
import 'app_state.dart';
import 'kid_mode.dart';

enum ScreenTimeState {
  /// Boleh membaca.
  ok,

  /// Sisa waktu hari ini 5 menit atau kurang.
  almostUp,

  /// Batas harian sudah habis.
  limitReached,

  /// Sedang jam tidur.
  bedtime,
}

/// Menghitung waktu layar Mode Anak per profil per hari, lalu mengunci
/// aplikasi saat batas harian habis atau masuk jam tidur.
class ScreenTimeController extends ChangeNotifier with WidgetsBindingObserver {
  ScreenTimeController({
    required this.app,
    required this.kid,
    required this.db,
    required this.settings,
    DateTime Function()? clock,
    this.tickInterval = const Duration(seconds: 15),
  }) : _clock = clock ?? DateTime.now {
    app.addListener(_onDependencies);
    kid.addListener(_onDependencies);
  }

  final AppState app;
  final KidModeController kid;
  final AppDatabase db;
  final SettingsStore settings;
  final DateTime Function() _clock;
  final Duration tickInterval;

  static const warnBefore = Duration(minutes: 5);

  Timer? _timer;
  DateTime? _lastTick;
  bool _foreground = true;
  int? _profileId;
  String _day = '';

  /// Detik di Mode Anak hari ini untuk profil aktif.
  int usedSeconds = 0;
  ScreenTimeState state = ScreenTimeState.ok;

  ChildProfile? get _profile => app.activeProfile;

  bool get locked => state == ScreenTimeState.limitReached || state == ScreenTimeState.bedtime;

  /// Sisa waktu hari ini; null bila tanpa batas.
  Duration? get remaining {
    final limit = _profile?.dailyLimitMinutes ?? 0;
    if (limit <= 0) return null;
    return Duration(seconds: max(0, limit * 60 - usedSeconds));
  }

  DateTime? get extraUntil {
    final id = _profileId;
    if (id == null) return null;
    final until = settings.extraTimeUntil(id);
    return until != null && until.isAfter(_clock()) ? until : null;
  }

  static String dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await _reload();
    _syncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    app.removeListener(_onDependencies);
    kid.removeListener(_onDependencies);
    _timer?.cancel();
    super.dispose();
  }

  void _onDependencies() {
    if (app.profileId != _profileId || app.activeProfile == null) {
      unawaited(_reload());
    } else {
      _evaluate();
    }
    _syncTimer();
  }

  Future<void> _reload() async {
    _profileId = app.profileId;
    _day = dayKey(_clock());
    usedSeconds = await db.screenTime(_profileId!, _day);
    _evaluate(force: true);
  }

  bool get _counting => kid.active && _foreground;

  void _syncTimer() {
    if (_counting && _timer == null) {
      _lastTick = _clock();
      _timer = Timer.periodic(tickInterval, (_) => tick());
    } else if (!_counting && _timer != null) {
      unawaited(tick());
      _timer?.cancel();
      _timer = null;
      _lastTick = null;
    }
  }

  /// Catat waktu sejak detak terakhir. Dipanggil berkala oleh timer.
  Future<void> tick() async {
    final now = _clock();
    final last = _lastTick;
    _lastTick = now;
    final day = dayKey(now);
    if (day != _day) {
      _day = day;
      usedSeconds = await db.screenTime(app.profileId, day);
    }
    if (last != null && !locked) {
      // Batasi supaya HP yang tertidur tidak dihitung sebagai waktu membaca.
      final delta = now.difference(last).inSeconds.clamp(0, 60);
      if (delta > 0) {
        usedSeconds += delta;
        await db.addScreenTime(app.profileId, day, delta);
      }
    }
    _evaluate();
  }

  void _evaluate({bool force = false}) {
    final next = _compute();
    if (force || next != state) {
      state = next;
      notifyListeners();
    } else if (state == ScreenTimeState.almostUp) {
      notifyListeners(); // perbarui hitung mundur
    }
  }

  ScreenTimeState _compute() {
    final p = _profile;
    if (p == null || extraUntil != null) return ScreenTimeState.ok;
    if (p.bedtime?.contains(_clock()) ?? false) return ScreenTimeState.bedtime;
    final left = remaining;
    if (left == null) return ScreenTimeState.ok;
    if (left == Duration.zero) return ScreenTimeState.limitReached;
    if (left <= warnBefore) return ScreenTimeState.almostUp;
    return ScreenTimeState.ok;
  }

  /// Orang tua memberi waktu tambahan (mengabaikan batas harian & jam tidur).
  Future<void> grantExtra(Duration d) async {
    final id = _profileId;
    if (id == null) return;
    await settings.setExtraTimeUntil(id, _clock().add(d));
    _evaluate(force: true);
  }

  /// Waktu layar hari ini untuk profil mana pun (untuk Area Orang Tua).
  Future<int> usedToday(int profileId) => db.screenTime(profileId, dayKey(_clock()));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _evaluate();
    _syncTimer();
  }
}
