import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/kid_mode.dart';
import '../state/screen_time.dart';
import '../theme.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'shelf_screen.dart';
import 'time_up_screen.dart';

/// Kerangka utama dengan navigasi bawah.
class KidShell extends StatefulWidget {
  const KidShell({super.key});

  static void goToTab(BuildContext context, int index) =>
      context.findAncestorStateOfType<_KidShellState>()?.select(index);

  @override
  State<KidShell> createState() => _KidShellState();
}

class _KidShellState extends State<KidShell> {
  int _index = 0;
  bool _wasLocked = false;

  void select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final needsPinning = context.select<KidModeController, bool>((k) => k.needsPinning);
    final locked = context.select<ScreenTimeController, bool>((s) => s.locked);
    final almostUp = context.select<ScreenTimeController, int?>(
      (s) => s.state == ScreenTimeState.almostUp ? (s.remaining!.inSeconds / 60).ceil() : null,
    );

    if (locked && !_wasLocked) {
      // Waktu habis saat buku/pemutar terbuka: tutup dulu (progres tersimpan saat ditutup).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }
    _wasLocked = locked;
    if (locked) {
      return const PopScope(canPop: false, child: Scaffold(body: TimeUpScreen()));
    }

    // Mode Anak: tombol Kembali tidak pernah menutup aplikasi.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) select(0);
      },
      child: Scaffold(
        body: Column(
          children: [
            if (needsPinning) const _PinBanner(),
            if (almostUp != null && !needsPinning) _TimeBanner(minutes: almostUp),
            Expanded(
              // Banner sudah memakai ruang status bar.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: needsPinning || almostUp != null,
                child: IndexedStack(
                  index: _index,
                  children: const [HomeScreen(), ExploreScreen(), SearchScreen(), ShelfScreen()],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: select,
          destinations: const [
            NavigationDestination(
              icon: Text('🏠', style: TextStyle(fontSize: 24)),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Text('🧭', style: TextStyle(fontSize: 24)),
              label: 'Jelajah',
            ),
            NavigationDestination(
              icon: Text('🔍', style: TextStyle(fontSize: 24)),
              label: 'Cari',
            ),
            NavigationDestination(
              icon: Text('📚', style: TextStyle(fontSize: 24)),
              label: 'Rak Bukuku',
            ),
          ],
        ),
      ),
    );
  }
}

/// Muncul bila layar belum disematkan (dialog ditolak atau sematan dilepas).
class _PinBanner extends StatelessWidget {
  const _PinBanner();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: const Color(0xFFFFF1D6),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              const Text('🔓', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Layar belum dikunci', style: text.titleSmall?.copyWith(color: QColors.ink)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => context.read<KidModeController>().pinAgain(),
                child: const Text('Kunci layar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pengingat lembut beberapa menit sebelum waktu membaca habis.
class _TimeBanner extends StatelessWidget {
  const _TimeBanner({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE6F4FF),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const Text('⏳', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Waktu membaca tinggal $minutes menit lagi',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: QColors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
