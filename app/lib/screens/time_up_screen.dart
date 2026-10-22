import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/labels.dart';
import '../state/app_state.dart';
import '../state/kid_mode.dart';
import '../state/screen_time.dart';
import '../theme.dart';
import '../widgets/hold_button.dart';
import 'parent/parent_gate.dart';

/// Tampil menggantikan Mode Anak saat batas harian habis atau jam tidur.
class TimeUpScreen extends StatelessWidget {
  const TimeUpScreen({super.key});

  Future<void> _parent(BuildContext context) async {
    final screenTime = context.read<ScreenTimeController>();
    final kid = context.read<KidModeController>();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (!await ParentGate.show(context) || !context.mounted) return;
    final choice = await showModalBottomSheet<Duration?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Beri waktu tambahan', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final m in const [15, 30, 60])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, Duration(minutes: m)),
                    child: Text('+ $m menit'),
                  ),
                ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, Duration.zero),
                icon: const Icon(Icons.admin_panel_settings_rounded),
                label: const Text('Buka Area Orang Tua'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) return;
    if (choice == Duration.zero) {
      await kid.exit();
    } else {
      await screenTime.grantExtra(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<ScreenTimeController>();
    final name = context.select<AppState, String?>((s) => s.activeProfile?.name);
    final text = Theme.of(context).textTheme;
    final bedtime = st.state == ScreenTimeState.bedtime;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bedtime
              ? const [Color(0xFF2B2D62), Color(0xFF4A3F8C)]
              : const [Color(0xFFFFE8D2), QColors.background],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(bedtime ? '🌙' : '⏰', style: const TextStyle(fontSize: 96)),
                    const SizedBox(height: 16),
                    Text(
                      bedtime ? 'Sudah waktunya tidur' : 'Waktu membaca hari ini habis',
                      textAlign: TextAlign.center,
                      style: text.headlineMedium?.copyWith(color: bedtime ? Colors.white : QColors.ink),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bedtime
                          ? 'Selamat tidur${name == null ? '' : ', $name'}! Besok kita baca lagi ya. ✨'
                          : 'Hebat${name == null ? '' : ', $name'}! Kamu sudah membaca ${formatDuration(st.usedSeconds)} hari ini. '
                                'Istirahatkan matamu dan lanjut lagi besok.',
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(color: bedtime ? Colors.white70 : QColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 8,
              child: HoldButton(
                hint: 'Orang tua: tekan dan tahan untuk menambah waktu',
                onHeld: () => _parent(context),
                child: Icon(Icons.lock_rounded, color: bedtime ? Colors.white70 : QColors.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
