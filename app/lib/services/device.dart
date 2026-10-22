import 'package:flutter/services.dart';

/// Fungsi perangkat kecil dari MainActivity.kt.
class DeviceService {
  static const _channel = MethodChannel('qorybook/device');

  /// Layar tetap menyala selama membaca.
  static Future<void> keepScreenOn(bool on) async {
    try {
      await _channel.invokeMethod('keepScreenOn', {'on': on});
    } on MissingPluginException {
      // tidak tersedia (mis. saat test)
    }
  }
}
