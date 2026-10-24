import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../config.dart';
import '../data/settings_store.dart';
import '../models/supporter.dart';

/// Penghitungan pengguna yang anonim: ID acak per pemasangan, tanpa data anak dan tanpa
/// pengenal perangkat. Tidak mengirim apa pun bila alamat backend belum diisi saat build.
/// Semua kegagalan jaringan ditelan; aplikasi tidak boleh terganggu olehnya.
class Telemetry {
  Telemetry({required this.settings, http.Client? client, String? baseUrl, String? anonKey, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? AppConfig.telemetryUrl).replaceAll(RegExp(r'/+$'), ''),
      _anonKey = anonKey ?? AppConfig.telemetryKey,
      _now = now ?? DateTime.now;

  final SettingsStore settings;
  final http.Client _client;
  final String _baseUrl;
  final String _anonKey;
  final DateTime Function() _now;

  /// Backend sudah dikonfigurasi saat build.
  bool get configured => _baseUrl.isNotEmpty && _anonKey.isNotEmpty;

  /// Penghitungan anonim aktif (backend ada dan orang tua belum mematikannya).
  bool get enabled => configured && settings.telemetryEnabled;

  /// Dikirim paling banyak sekali sehari.
  Future<void> ping() async {
    if (!enabled) return;
    final today = _now().toIso8601String().substring(0, 10);
    if (settings.lastPingDay == today) return;
    final ok = await _rpc('ping', {
      'p_install_id': settings.installId,
      'p_version': AppConfig.appVersion,
      'p_platform': AppConfig.platform,
      'p_source': kIsWeb ? 'web' : AppConfig.installSource,
    });
    if (ok) settings.lastPingDay = today;
  }

  Future<void> event(String type, {Map<String, Object?> data = const {}}) async {
    if (!enabled) return;
    await _rpc('log_event', {'p_install_id': settings.installId, 'p_type': type, 'p_data': data});
  }

  /// Orang tua memperkenalkan diri. Dikirim hanya atas persetujuan eksplisit; kembali `true`
  /// bila tersimpan di perangkat dan (kalau menyetujui) terkirim.
  Future<bool> saveSupporter(Supporter s) async {
    settings.supporter = s;
    if (!configured) return true;
    if (!s.consent) return _rpc('forget_supporter', {'p_install_id': settings.installId});
    return _rpc('register_supporter', {
      'p_install_id': settings.installId,
      'p_nickname': s.nickname,
      'p_contact': s.contact,
      'p_consent': true,
    });
  }

  /// Hapus perkenalan dari perangkat dan dari server.
  Future<void> forgetSupporter() async {
    settings.supporter = null;
    if (configured) await _rpc('forget_supporter', {'p_install_id': settings.installId});
  }

  Future<bool> _rpc(String fn, Map<String, Object?> body) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/rest/v1/rpc/$fn'),
            headers: {
              'apikey': _anonKey,
              'Authorization': 'Bearer $_anonKey',
              'Content-Type': 'application/json',
              if (!kIsWeb) 'User-Agent': AppConfig.userAgent,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
