import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/contribution.dart';
import '../screens/parent/family_screen.dart';
import '../services/telemetry.dart';
import '../state/app_state.dart';
import '../state/kid_mode.dart';
import '../theme.dart';

/// Teks ajakan Keluarga Literasi. Satu sumber untuk banner, kartu atas, dan halamannya.
class Donation {
  static const invite = 'Dukung aplikasi ini dengan menjadi Keluarga Literasi';

  static const bannerTitle = 'Qorybook gratis, berkat Keluarga Literasi';

  static const bannerBody =
      'Qorybook tidak berbayar dan tanpa iklan. Donasi dari orang tua membantu kami merawat aplikasi, '
      'menjaga katalog buku tetap diperbarui, dan menambah fitur baru untuk anak-anak.';

  static const charity =
      '${AppConfig.donationCharityPercent}% dari setiap donasi kami salurkan untuk pendidikan anak yatim dan dhuafa.';

  static const charityShort = '${AppConfig.donationCharityPercent}% donasi untuk pendidikan anak yatim & dhuafa';

  /// Buka Saweria. Area Orang Tua sudah melepas sematan layar, jadi browser bisa terbuka.
  static Future<bool> open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (AppConfig.donationUrl.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Tautan donasi Saweria segera hadir. Terima kasih! 💛')));
      return false;
    }
    final kiosk = context.read<KidModeController>().kiosk;
    unawaited(context.read<Telemetry>().event('donate_tap'));
    final ok = await kiosk.openUrl(AppConfig.donationUrl);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Tidak ada browser untuk membuka Saweria.')));
    }
    return ok;
  }

  static Future<void> openFamily(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FamilyScreen()));
}

/// Kartu ajakan di paling atas Area Orang Tua. Selalu tampil; bila orang tua sudah
/// mencatat donasi, berubah menjadi ringkasan kontribusinya.
class FamilyInviteTile extends StatelessWidget {
  const FamilyInviteTile({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final list = context.watch<AppState>().contributions;
    final member = list.isNotEmpty;
    return Material(
      color: const Color(0xFFFFF1D6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: QColors.sun, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Donation.openFamily(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              const Text('💛', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member ? 'Terima kasih, Keluarga Literasi!' : Donation.invite, style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      member
                          ? '${list.length} kontribusi · ${rupiah(list.fold(0, (s, c) => s + c.amount))}'
                          : Donation.charityShort,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: QColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner ajakan donasi di Area Orang Tua, bisa disembunyikan selamanya.
/// Tidak tampil lagi setelah orang tua mencatat donasi pertamanya.
class DonationBanner extends StatelessWidget {
  const DonationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.donationBannerHidden || state.contributions.isNotEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    const white = TextStyle(color: Colors.white);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9F68), QColors.primary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📚', style: TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(child: Text(Donation.bannerTitle, style: text.titleMedium?.merge(white))),
            ],
          ),
          const SizedBox(height: 10),
          Text(Donation.bannerBody, style: text.bodyMedium?.merge(white)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('🤲', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Text(Donation.charity, style: text.labelMedium?.merge(white))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: QColors.primaryDark),
              onPressed: () => Donation.openFamily(context),
              icon: const Icon(Icons.favorite_rounded),
              label: const Text('Jadi Keluarga Literasi'),
            ),
          ),
          Center(
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: state.hideDonationBanner,
              child: const Text('Jangan tampilkan lagi'),
            ),
          ),
        ],
      ),
    );
  }
}
