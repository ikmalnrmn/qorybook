import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keadaan penguncian perangkat (lihat KioskChannel.kt).
class KioskStatus {
  const KioskStatus({
    this.pinned = false,
    this.dndAccess = false,
    this.dndActive = false,
    this.deviceSecure = false,
    this.pinToUnpin,
    this.available = false,
  });

  /// Aplikasi sedang disematkan (tombol Home/Recent tidak berfungsi).
  final bool pinned;

  /// Izin "Akses Jangan Ganggu" sudah diberikan.
  final bool dndAccess;

  /// Jangan Ganggu sedang dinyalakan oleh Qorybook.
  final bool dndActive;

  /// HP punya kunci layar (PIN/pola/sandi/sidik jari).
  final bool deviceSecure;

  /// "Minta PIN sebelum melepas sematan"; null jika tidak bisa dibaca.
  final bool? pinToUnpin;

  /// false bila kanal native tidak tersedia (mis. di test).
  final bool available;

  factory KioskStatus.fromMap(Map<String, Object?> m) => KioskStatus(
    pinned: m['pinned'] == true,
    dndAccess: m['dndAccess'] == true,
    dndActive: m['dndActive'] == true,
    deviceSecure: m['deviceSecure'] == true,
    pinToUnpin: m['pinToUnpin'] as bool?,
    available: true,
  );
}

/// Pembungkus kanal "qorybook/kiosk".
class KioskService {
  const KioskService();

  static const _channel = MethodChannel('qorybook/kiosk');

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('kiosk.$method gagal: ${e.message}');
      return null;
    }
  }

  Future<KioskStatus> status() async {
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('status');
      return m == null ? const KioskStatus() : KioskStatus.fromMap(m);
    } on MissingPluginException {
      return const KioskStatus();
    } on PlatformException {
      return const KioskStatus();
    }
  }

  /// Android menampilkan dialog konfirmasi "Sematkan aplikasi?" bila belum disematkan.
  Future<void> startLockTask() => _call<bool>('startLockTask');

  Future<void> stopLockTask() => _call<bool>('stopLockTask');

  /// Mengembalikan false bila izin Jangan Ganggu belum diberikan.
  Future<bool> enableDnd({required bool allowCalls}) async =>
      await _call<bool>('enableDnd', {'allowCalls': allowCalls}) ?? false;

  Future<void> restoreDnd() => _call<bool>('restoreDnd');

  Future<void> openDndAccessSettings() => _call<bool>('openDndAccessSettings');

  Future<void> openSecuritySettings() => _call<bool>('openSecuritySettings');
}
