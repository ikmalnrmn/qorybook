import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/parent_auth.dart';
import '../../widgets/pin_pad.dart';

/// Ganti PIN orang tua (sudah di dalam Area Orang Tua, jadi PIN lama tidak ditanya lagi).
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  String? _first;
  String? _message;

  Future<bool> _onPin(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _message = null;
      });
      return true;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _message = 'PIN tidak sama. Ulangi dari awal.';
      });
      return false;
    }
    await context.read<ParentAuth>().setPin(pin);
    if (!mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN orang tua sudah diganti.')));
    Navigator.of(context).pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti PIN')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(_first == null ? 'Masukkan PIN baru' : 'Ulangi PIN baru', style: text.titleLarge),
              const SizedBox(height: 8),
              SizedBox(
                height: 20,
                child: Text(_message ?? '', style: text.bodySmall?.copyWith(color: const Color(0xFFE5484D))),
              ),
              const SizedBox(height: 16),
              PinPad(key: ValueKey(_first == null), onCompleted: _onPin),
            ],
          ),
        ),
      ),
    );
  }
}
