import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/profile.dart';
import '../../services/labels.dart';
import '../../state/app_state.dart';
import '../../state/kid_mode.dart';
import '../../state/screen_time.dart';
import '../../theme.dart';
import '../../widgets/donation.dart';
import '../../widgets/kid_mode_checklist.dart';
import '../about_screen.dart';
import 'change_pin_screen.dart';
import 'profile_edit_screen.dart';

/// Area Orang Tua: pilih anak, kelola profil, atur Mode Anak.
class ParentHome extends StatelessWidget {
  const ParentHome({super.key});

  static const maxProfiles = 6;

  Future<void> _startKidMode(BuildContext context, ChildProfile p) async {
    final state = context.read<AppState>();
    final kid = context.read<KidModeController>();
    await state.switchProfile(p.id);
    await kid.enter();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final kid = context.watch<KidModeController>();
    final settings = state.settings;
    final text = Theme.of(context).textTheme;

    Future<void> toggle(void Function() change) async {
      change();
      await kid.applySettings();
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Row(
                    children: [
                      const Text('👨‍👩‍👧', style: TextStyle(fontSize: 34)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Area Orang Tua', style: text.headlineMedium),
                            Text('Mode Anak sedang dijeda', style: text.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const FamilyInviteTile(),
                  const SizedBox(height: 20),
                  Text('Siapa yang mau membaca?', style: text.titleLarge),
                  const SizedBox(height: 10),
                  for (final p in state.profiles)
                    _ProfileCard(
                      profile: p,
                      active: p.id == state.profileId,
                      onStart: () => _startKidMode(context, p),
                      onEdit: () =>
                          Navigator.of(context)
                              .push(MaterialPageRoute<void>(builder: (_) => ProfileEditScreen(profile: p))),
                    ),
                  if (state.profiles.length < maxProfiles)
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context)
                              .push(MaterialPageRoute<void>(builder: (_) => const ProfileEditScreen())),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Tambah profil anak'),
                    ),
                  const DonationBanner(),
                  const SizedBox(height: 28),
                  Text('Mode Anak', style: text.titleLarge),
                  const SizedBox(height: 6),
                  _SettingsCard(
                    children: [
                      SwitchListTile(
                        secondary: const Text('📌', style: TextStyle(fontSize: 26)),
                        title: const Text('Sematkan layar'),
                        subtitle: const Text('Anak tidak bisa membuka aplikasi lain atau kembali ke layar utama'),
                        value: settings.kioskPinScreen,
                        onChanged: (v) => toggle(() => settings.kioskPinScreen = v),
                      ),
                      SwitchListTile(
                        secondary: const Text('🔕', style: TextStyle(fontSize: 26)),
                        title: const Text('Senyapkan notifikasi'),
                        subtitle: Text(
                          kid.status.dndAccess || !kid.status.available
                              ? 'Jangan Ganggu menyala selama Mode Anak'
                              : 'Perlu izin Jangan Ganggu (lihat di bawah)',
                        ),
                        value: settings.kioskDnd,
                        onChanged: (v) => toggle(() => settings.kioskDnd = v),
                      ),
                      SwitchListTile(
                        secondary: const Text('📞', style: TextStyle(fontSize: 26)),
                        title: const Text('Izinkan telepon penting'),
                        subtitle: const Text('Telepon dari kontak berbintang tetap masuk'),
                        value: settings.kioskAllowCalls,
                        onChanged: settings.kioskDnd ? (v) => toggle(() => settings.kioskAllowCalls = v) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const KidModeChecklist(),
                  const SizedBox(height: 18),
                  Text('Lainnya', style: text.titleLarge),
                  const SizedBox(height: 6),
                  _SettingsCard(
                    children: [
                      ListTile(
                        leading: const Text('🔑', style: TextStyle(fontSize: 24)),
                        title: const Text('Ganti PIN orang tua'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            Navigator.of(context)
                                .push(MaterialPageRoute<void>(builder: (_) => const ChangePinScreen())),
                      ),
                      ListTile(
                        leading: const Text('💾', style: TextStyle(fontSize: 24)),
                        title: const Text('Tentang Qorybook & sumber buku'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
                      ),
                      ListTile(
                        leading: const Text('🚪', style: TextStyle(fontSize: 24)),
                        title: const Text('Tutup Qorybook'),
                        onTap: () => SystemNavigator.pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.active, required this.onStart, required this.onEdit});

  final ChildProfile profile;
  final bool active;
  final VoidCallback onStart;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = context.read<AppState>();
    final screenTime = context.read<ScreenTimeController>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: QColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: active ? profile.color : QColors.line, width: active ? 2.5 : 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: profile.color.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Text(profile.emoji, style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(levelOrder.where(profile.levels.contains).map(levelLabel).join(' · '), style: text.bodySmall),
                    const SizedBox(height: 4),
                    FutureBuilder(
                      future: () async {
                        final week = await state.weeklyStats(profile.id);
                        final today = await screenTime.usedToday(profile.id);
                        return (week: week, todayMinutes: (today / 60).round());
                      }(),
                      builder: (context, snap) {
                        final s = snap.data;
                        if (s == null) return const Text(' ');
                        final limit = profile.dailyLimitMinutes;
                        return Text(
                          [
                            limit > 0
                                ? '⏱️ ${s.todayMinutes}/$limit menit hari ini'
                                : '⏱️ ${s.todayMinutes} menit hari ini',
                            '🏆 ${s.week.finished} buku selesai',
                            if (profile.bedtime != null) '🌙 ${profile.bedtime!.label}',
                            if (profile.curatedOnly) '✅ Buku pilihan',
                          ].join('  ·  '),
                          style: text.labelMedium,
                        );
                      },
                    ),
                  ],
                ),
              ),
              IconButton(tooltip: 'Ubah profil', onPressed: onEdit, icon: const Icon(Icons.edit_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Mulai Mode Anak untuk ${profile.name}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Material (bukan Container berwarna) supaya efek ketuk ListTile terlihat.
    return Material(
      color: QColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
