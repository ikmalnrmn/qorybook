import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import '../data/settings_store.dart';

enum PinCheck { ok, wrong, lockedOut }

/// PIN orang tua dan buka kunci dengan sidik jari / kunci layar HP.
class ParentAuth {
  ParentAuth(this._settings, {LocalAuthentication? localAuth}) : _localAuth = localAuth ?? LocalAuthentication();

  final SettingsStore _settings;
  final LocalAuthentication _localAuth;

  static const pinLength = 4;
  static const _iterations = 20000;
  static const _freeAttempts = 5;

  bool get hasPin => _settings.pinHash != null;

  static String hashPin(String pin, String salt) {
    var digest = utf8.encode('$salt:$pin');
    for (var i = 0; i < _iterations; i++) {
      digest = Uint8List.fromList(sha256.convert(digest).bytes);
    }
    return base64Encode(digest);
  }

  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await _settings.setPin(hashPin(pin, salt), salt);
    _settings.failedAttempts = 0;
    _settings.lockedUntil = null;
  }

  /// Sisa waktu terkunci setelah terlalu sering salah, atau null.
  Duration? get lockoutRemaining {
    final until = _settings.lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  Future<PinCheck> verify(String pin) async {
    if (lockoutRemaining != null) return PinCheck.lockedOut;
    final hash = _settings.pinHash;
    final salt = _settings.pinSalt;
    if (hash == null || salt == null) return PinCheck.wrong;
    final ok = await compute(_hashArgs, [pin, salt]) == hash;
    if (ok) {
      _settings.failedAttempts = 0;
      _settings.lockedUntil = null;
      return PinCheck.ok;
    }
    final failed = _settings.failedAttempts + 1;
    _settings.failedAttempts = failed;
    if (failed >= _freeAttempts) {
      // 30 detik, lalu bertambah setiap kali salah lagi (maks. 10 menit).
      final seconds = min(600, 30 * (1 << (failed - _freeAttempts)));
      _settings.lockedUntil = DateTime.now().add(Duration(seconds: seconds));
      return PinCheck.lockedOut;
    }
    return PinCheck.wrong;
  }

  /// HP mendukung sidik jari/wajah atau punya kunci layar.
  Future<bool> canUseDeviceAuth() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Sidik jari, wajah, atau PIN/pola HP.
  Future<bool> authenticateWithDevice() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Buka Area Orang Tua Qorybook',
        authMessages: const [AndroidAuthMessages(signInTitle: 'Khusus orang tua', cancelButton: 'Batal')],
      );
    } catch (e) {
      debugPrint('Autentikasi perangkat gagal: $e');
      return false;
    }
  }
}

String _hashArgs(List<String> a) => ParentAuth.hashPin(a[0], a[1]);
