import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/parent_auth.dart';
import '../theme.dart';

/// Papan angka PIN dengan titik-titik. [onCompleted] mengembalikan false
/// bila PIN ditolak, lalu titik bergetar dan dikosongkan.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onCompleted, this.enabled = true, this.extraKey, this.dark = false});

  final Future<bool> Function(String pin) onCompleted;
  final bool enabled;

  /// Tombol di kiri bawah (mis. sidik jari).
  final Widget? extraKey;
  final bool dark;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _press(String digit) async {
    if (_busy || !widget.enabled || _pin.length >= ParentAuth.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += digit);
    if (_pin.length < ParentAuth.pinLength) return;
    setState(() => _busy = true);
    final ok = await widget.onCompleted(_pin);
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      await _shake.forward(from: 0);
    }
    if (mounted) {
      setState(() {
        _pin = '';
        _busy = false;
      });
    }
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.dark ? Colors.white : QColors.ink;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(sin(_shake.value * pi * 6) * 14 * (1 - _shake.value), 0),
            child: child,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < ParentAuth.pinLength; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? QColors.primary : Colors.transparent,
                    border: Border.all(color: i < _pin.length ? QColors.primary : fg.withValues(alpha: 0.35), width: 2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(mainAxisSize: MainAxisSize.min, children: [for (final d in row) _key(d, fg)]),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 92, height: 80, child: Center(child: widget.extraKey)),
            _key('0', fg),
            SizedBox(
              width: 92,
              height: 80,
              child: IconButton(
                tooltip: 'Hapus',
                onPressed: _pin.isEmpty ? null : _backspace,
                icon: Icon(Icons.backspace_outlined, color: fg, size: 28),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _key(String d, Color fg) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: 76,
        height: 64,
        child: Material(
          color: widget.dark ? Colors.white.withValues(alpha: 0.1) : QColors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.enabled ? () => _press(d) : null,
            child: Center(
              child: Text(
                d,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: widget.enabled ? fg : fg.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
