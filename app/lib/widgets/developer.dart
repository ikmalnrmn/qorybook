import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/kid_mode.dart';
import '../theme.dart';

/// Identitas dan kontak developer. Satu sumber teks untuk Area Orang Tua, halaman Tentang, dan promosi.
class Developer {
  static const name = 'Tim Qorybook';
  static const role = 'Pengembang aplikasi Android dan web';

  static const intro =
      'Qorybook dikembangkan secara mandiri oleh Tim Qorybook. Kami dengan senang hati menerima pesan untuk:';

  static const services = [
    ('🤝', 'Kerja sama', 'Sekolah, komunitas literasi, atau lembaga yang ingin bermitra'),
    ('💬', 'Kritik dan saran', 'Masukan supaya Qorybook makin nyaman dipakai'),
    ('📱', 'Pembuatan aplikasi', 'Request aplikasi sesuai kebutuhan Anda'),
  ];

  static const email = 'ikmalnrmn22@gmail.com';
  static const whatsapp = '0856-0491-3244';
  static const whatsappUrl = 'https://wa.me/6285604913244?text=Halo%20Tim%20Qorybook%2C%20';
  static const emailUrl = 'mailto:$email?subject=Qorybook';

  /// Buka WhatsApp/email. Bila tidak ada aplikasi yang bisa membukanya, kontak disalin.
  static Future<void> contact(BuildContext context, String url, String copy) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<KidModeController>().kiosk.openUrl(url);
    if (ok) return;
    await Clipboard.setData(ClipboardData(text: copy));
    messenger.showSnackBar(SnackBar(content: Text('Tidak bisa membuka aplikasinya. $copy sudah disalin.')));
  }
}

/// Kartu developer: identitas, layanan, dan tombol kontak.
class DeveloperCard extends StatelessWidget {
  const DeveloperCard({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: QColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QColors.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: QColors.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Text('🧑‍💻', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Developer.name, style: text.titleMedium),
                    Text(Developer.role, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(Developer.intro, style: text.bodyMedium),
          const SizedBox(height: 8),
          for (final (emoji, title, body) in Developer.services)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleSmall),
                        Text(body, style: text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _ContactButton(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            value: Developer.whatsapp,
            color: QColors.leaf,
            onTap: () => Developer.contact(context, Developer.whatsappUrl, Developer.whatsapp),
          ),
          const SizedBox(height: 10),
          _ContactButton(
            icon: Icons.mail_rounded,
            label: 'Email',
            value: Developer.email,
            color: QColors.sky,
            onTap: () => Developer.contact(context, Developer.emailUrl, Developer.email),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.labelMedium),
                    Text(value, style: text.titleSmall),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, size: 20, color: QColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
