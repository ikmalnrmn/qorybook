import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Tombol yang harus ditekan lama. Dipakai untuk masuk Area Orang Tua
/// supaya anak tidak sengaja membukanya.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.onHeld,
    required this.child,
    this.holdDuration = const Duration(milliseconds: 1500),
    this.hint = 'Khusus orang tua: tekan dan tahan tombol ini',
  });

  final VoidCallback onHeld;
  final Widget child;
  final Duration holdDuration;
  final String hint;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: widget.holdDuration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        _ctrl.value = 0;
        widget.onHeld();
      }
    });

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _start() => _ctrl.forward(from: 0);

  void _cancel() {
    if (_ctrl.isAnimating) _ctrl.animateBack(0, duration: const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.hint,
      // Listener (bukan GestureDetector) supaya tekanan panjang tidak dibatalkan arena gestur.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _start(),
        onPointerUp: (_) {
          if (_ctrl.isAnimating && _ctrl.value < 0.6) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(widget.hint), duration: const Duration(seconds: 2)));
          }
          _cancel();
        },
        onPointerCancel: (_) => _cancel(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => CircularProgressIndicator(
                  value: _ctrl.value,
                  strokeWidth: 4,
                  color: QColors.primary,
                  backgroundColor: Colors.transparent,
                ),
              ),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}
