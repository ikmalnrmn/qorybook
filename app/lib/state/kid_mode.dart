import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/settings_store.dart';
import '../services/kiosk.dart';

/// Mengatur masuk/keluar Mode Anak: sematkan layar + Jangan Ganggu.
class KidModeController extends ChangeNotifier with WidgetsBindingObserver {
  KidModeController({required this.settings, this.kiosk = const KioskService()});

  final SettingsStore settings;
  final KioskService kiosk;

  bool _active = false;
  KioskStatus status = const KioskStatus();
  Timer? _poll;

  /// Mode Anak sedang berjalan.
  bool get active => _active;

  /// Sematkan layar diminta orang tua tetapi belum aktif (dialog ditolak atau sematan dilepas).
  bool get needsPinning => _active && settings.kioskPinScreen && status.available && !status.pinned;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    // Pulihkan Jangan Ganggu bila sesi sebelumnya berakhir tanpa sempat keluar dengan benar.
    await kiosk.restoreDnd();
    await refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    final s = await kiosk.status();
    final changed =
        s.pinned != status.pinned ||
        s.dndAccess != status.dndAccess ||
        s.dndActive != status.dndActive ||
        s.deviceSecure != status.deviceSecure ||
        s.pinToUnpin != status.pinToUnpin ||
        s.available != status.available;
    status = s;
    if (changed) notifyListeners();
  }

  Future<void> enter() async {
    _active = true;
    notifyListeners();
    if (settings.kioskDnd) await kiosk.enableDnd(allowCalls: settings.kioskAllowCalls);
    if (settings.kioskPinScreen) await kiosk.startLockTask();
    await refresh();
    _poll?.cancel();
    // Dialog "Sematkan aplikasi?" tidak memberi kabar; periksa berkala.
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }

  /// Minta Android menyematkan layar lagi.
  Future<void> pinAgain() async {
    await kiosk.startLockTask();
    await refresh();
  }

  Future<void> exit() async {
    _active = false;
    _poll?.cancel();
    notifyListeners();
    await kiosk.stopLockTask();
    await kiosk.restoreDnd();
    await refresh();
  }

  /// Terapkan perubahan pengaturan dari Area Orang Tua.
  Future<void> applySettings() async {
    if (_active) {
      if (settings.kioskDnd) {
        await kiosk.restoreDnd();
        await kiosk.enableDnd(allowCalls: settings.kioskAllowCalls);
      } else {
        await kiosk.restoreDnd();
      }
    }
    await refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Bisa jadi orang tua baru kembali dari layar izin Jangan Ganggu.
      unawaited(_onResume());
    } else if (state == AppLifecycleState.paused && _active) {
      _poll?.cancel();
      // Aplikasi ditinggalkan tanpa sematan: jangan biarkan HP tetap senyap.
      if (!status.pinned) unawaited(kiosk.restoreDnd());
    }
  }

  Future<void> _onResume() async {
    if (_active) {
      if (settings.kioskDnd) await kiosk.enableDnd(allowCalls: settings.kioskAllowCalls);
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
    }
    await refresh();
  }
}
