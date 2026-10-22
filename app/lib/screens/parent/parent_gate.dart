import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/parent_auth.dart';
import '../../widgets/pin_pad.dart';

/// Gerbang Area Orang Tua: PIN, atau sidik jari / kunci layar HP.
class ParentGate extends StatefulWidget {
  const ParentGate({super.key});

  /// true bila orang tua berhasil membuka.
  static Future<bool> show(BuildContext context) async {
    final ok = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ParentGate()));
    return ok ?? false;
  }

  @override
  State<ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<ParentGate> {
  late final ParentAuth _auth = context.read<ParentAuth>();
  String? _message;
  bool _deviceAuth = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _auth.canUseDeviceAuth().then((v) {
      if (mounted) setState(() => _deviceAuth = v);
    });
    _tickLockout();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tickLockout() {
    _ticker?.cancel();
    if (_auth.lockoutRemaining == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_auth.lockoutRemaining == null) {
        t.cancel();
        setState(() => _message = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<bool> _check(String pin) async {
    final result = await _auth.verify(pin);
    if (!mounted) return false;
    switch (result) {
      case PinCheck.ok:
        Navigator.of(context).pop(true);
        return true;
      case PinCheck.wrong:
        setState(() => _message = 'PIN salah, coba lagi.');
        return false;
      case PinCheck.lockedOut:
        setState(() => _message = null);
        _tickLockout();
        return false;
    }
  }

  Future<void> _useDevice() async {
    final ok = await _auth.authenticateWithDevice();
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final locked = _auth.lockoutRemaining;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Tutup',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                Text('Khusus Orang Tua', style: text.headlineSmall),
                const SizedBox(height: 4),
                Text('Masukkan PIN orang tua', style: text.bodyMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 22,
                  child: Text(
                    locked != null
                        ? 'Terlalu sering salah. Coba lagi dalam ${locked.inSeconds + 1} detik.'
                        : _message ?? '',
                    style: text.bodySmall?.copyWith(color: const Color(0xFFE5484D)),
                  ),
                ),
                const SizedBox(height: 16),
                PinPad(
                  enabled: locked == null,
                  onCompleted: _check,
                  extraKey: _deviceAuth
                      ? IconButton(
                          tooltip: 'Pakai sidik jari atau kunci HP',
                          iconSize: 34,
                          onPressed: _useDevice,
                          icon: const Icon(Icons.fingerprint_rounded),
                        )
                      : null,
                ),
                if (_deviceAuth) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _useDevice,
                    icon: const Icon(Icons.phonelink_lock_rounded),
                    label: const Text('Pakai sidik jari / kunci HP'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
