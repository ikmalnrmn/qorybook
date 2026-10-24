import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/kid_mode.dart';
import '../theme.dart';

/// Daftar periksa keamanan Mode Anak: izin Jangan Ganggu, kunci layar HP,
/// dan "minta PIN sebelum melepas sematan".
class KidModeChecklist extends StatelessWidget {
  const KidModeChecklist({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const _WebChecklist();
    final kid = context.watch<KidModeController>();
    final s = kid.status;
    return Column(
      children: [
        _CheckItem(
          state: s.dndAccess ? _State.ok : _State.todo,
          emoji: '🔕',
          title: 'Senyapkan notifikasi',
          message: s.dndAccess
              ? 'Izin Jangan Ganggu sudah diberikan. Notifikasi disenyapkan selama Mode Anak.'
              : 'Beri Qorybook "Akses Jangan Ganggu" agar notifikasi tidak muncul saat anak membaca.',
          action: s.dndAccess ? null : ('Beri izin', kid.kiosk.openDndAccessSettings),
        ),
        _CheckItem(
          state: s.deviceSecure ? _State.ok : _State.warn,
          emoji: '🔐',
          title: 'Kunci layar HP',
          message: s.deviceSecure
              ? 'HP sudah punya PIN/pola. Anak tidak bisa melepas sematan tanpa kunci HP.'
              : 'HP belum punya PIN, pola, atau sandi. Pasang dulu supaya anak tidak bisa keluar dari aplikasi.',
          action: s.deviceSecure ? null : ('Buka pengaturan', kid.kiosk.openSecuritySettings),
        ),
        _CheckItem(
          state: switch (s.pinToUnpin) {
            true => _State.ok,
            false => _State.warn,
            null => _State.info,
          },
          emoji: '📌',
          title: 'Sematkan aplikasi',
          message: switch (s.pinToUnpin) {
            true => 'Android akan meminta PIN HP bila sematan dilepas.',
            false => 'Nyalakan "Minta PIN sebelum melepas sematan" di Pengaturan > Keamanan > Sematkan aplikasi.',
            null =>
              'Saat Mode Anak dimulai, Android bertanya "Sematkan aplikasi?" — ketuk Sematkan. '
                  'Pastikan "Minta PIN sebelum melepas sematan" menyala di pengaturan keamanan.',
          },
          action: s.pinToUnpin == true ? null : ('Periksa pengaturan', kid.kiosk.openSecuritySettings),
        ),
      ],
    );
  }
}

/// Versi web tidak bisa mengunci layar sendiri; orang tua memakai fitur bawaan HP-nya.
class _WebChecklist extends StatelessWidget {
  const _WebChecklist();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _CheckItem(
          state: _State.info,
          emoji: '📱',
          title: 'Kunci anak di Qorybook',
          message:
              'Di iPhone/iPad, nyalakan Akses Terpandu di Pengaturan > Aksesibilitas > Akses Terpandu. '
              'Lalu klik tiga kali tombol samping (atau tombol Home) saat Qorybook terbuka.',
        ),
        _CheckItem(
          state: _State.info,
          emoji: '🔕',
          title: 'Senyapkan notifikasi',
          message: 'Nyalakan Fokus atau Jangan Ganggu dari Pusat Kontrol sebelum anak mulai membaca.',
        ),
      ],
    );
  }
}

enum _State { ok, todo, warn, info }

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.state, required this.emoji, required this.title, required this.message, this.action});

  final _State state;
  final String emoji;
  final String title;
  final String message;
  final (String, Future<void> Function())? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (badge, color) = switch (state) {
      _State.ok => ('✅', QColors.leaf),
      _State.todo => ('⬜', QColors.inkSoft),
      _State.warn => ('⚠️', const Color(0xFFE8A33D)),
      _State.info => ('ℹ️', QColors.sky),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: QColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: text.titleSmall)),
                    Text(badge, style: const TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message, style: text.bodySmall?.copyWith(height: 1.4)),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: action!.$2,
                    child: Text(action!.$1),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
