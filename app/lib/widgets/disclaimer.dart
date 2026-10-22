import 'package:flutter/material.dart';

import '../theme.dart';

/// Pernyataan resmi tentang asal buku dan peran Qorybook. Satu sumber teks
/// untuk layar sambutan, halaman Tentang, dan README.
class Disclaimer {
  static const title = 'Buku resmi & gratis dari pemerintah';

  static const body =
      'Semua buku di Qorybook adalah buku resmi yang disediakan gratis oleh pemerintah Indonesia '
      'melalui Kementerian Pendidikan Dasar dan Menengah, yaitu SIBI (Pusat Perbukuan) dan '
      'BUDI (Badan Pengembangan dan Pembinaan Bahasa).';

  static const role =
      'Qorybook hanya menjadi perantara: memudahkan orang tua memilih dan mengawasi bacaan anak, '
      'serta memberi pengalaman membaca yang menyenangkan tanpa harus membuka situs aslinya. '
      'Qorybook tidak menjual buku dan tidak mengubah isinya.';

  static const rights =
      'Hak cipta setiap buku tetap milik penulis, ilustrator, dan penerbitnya. '
      'Qorybook adalah aplikasi independen dan tidak berafiliasi dengan Kemendikdasmen.';

  /// Versi singkat untuk halaman detail buku.
  static String short(String sourceName) =>
      'Buku resmi dan gratis dari $sourceName. Qorybook hanya perantara dan tidak menjual buku ini.';
}

/// Kartu disclaimer untuk orang tua.
class DisclaimerCard extends StatelessWidget {
  const DisclaimerCard({super.key, this.compact = false});

  /// Tanpa paragraf hak cipta (untuk layar sambutan).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final body = text.bodySmall?.copyWith(color: QColors.ink, height: 1.45);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: QColors.leaf.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏛️', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Disclaimer.title, style: text.titleSmall),
                const SizedBox(height: 6),
                Text(Disclaimer.body, style: body),
                const SizedBox(height: 6),
                Text(Disclaimer.role, style: body),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  Text(Disclaimer.rights, style: body?.copyWith(color: QColors.inkSoft)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
