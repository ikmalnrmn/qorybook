import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Tentang aplikasi, sumber buku, dan pengelolaan penyimpanan.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int? _used;

  @override
  void initState() {
    super.initState();
    _refreshUsage();
  }

  Future<void> _refreshUsage() async {
    final used = await context.read<AppState>().files.usedBytes();
    if (mounted) setState(() => _used = used);
  }

  String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final text = Theme.of(context).textTheme;
    final catalog = state.catalog;
    final limits = [200, 500, 1000, 2000].map((m) => m * 1024 * 1024).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tentang Qorybook')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [QColors.primary, QColors.primaryDark]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Text('📚', style: TextStyle(fontSize: 48)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qorybook', style: text.headlineSmall?.copyWith(color: Colors.white)),
                      Text(
                        'Buku bacaan anak gratis dari pemerintah Indonesia',
                        style: text.bodyMedium?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Sumber buku', style: text.titleMedium),
          const SizedBox(height: 8),
          _InfoTile(
            emoji: '🏛️',
            title: 'SIBI — Sistem Informasi Perbukuan Indonesia',
            subtitle: 'buku.kemendikdasmen.go.id · Pusat Perbukuan, Kemendikdasmen',
          ),
          _InfoTile(
            emoji: '📗',
            title: 'BUDI — Buku Digital Gerakan Literasi Nasional',
            subtitle: 'budi.kemendikdasmen.go.id · Badan Pengembangan dan Pembinaan Bahasa',
          ),
          const SizedBox(height: 8),
          Text(
            'Qorybook tidak menyimpan atau mengubah isi buku. Setiap buku diambil langsung dari server '
            'pemerintah saat dibuka, dan hak cipta tetap milik penulis, ilustrator, serta penerbitnya.',
            style: text.bodyMedium?.copyWith(color: QColors.inkSoft),
          ),
          if (catalog != null) ...[
            const SizedBox(height: 8),
            Text(
              '${catalog.books.length} buku PAUD–SD · katalog ${catalog.generatedAt?.toLocal().toString().substring(0, 16) ?? '-'}',
              style: text.bodySmall,
            ),
          ],
          const SizedBox(height: 24),
          Text('Penyimpanan', style: text.titleMedium),
          const SizedBox(height: 8),
          _InfoTile(
            emoji: '💾',
            title: 'Dipakai: ${_used == null ? '…' : _mb(_used!)}',
            subtitle: 'Buku yang pernah dibuka disimpan sementara supaya cepat dibuka lagi.',
          ),
          const SizedBox(height: 8),
          Text('Batas simpanan sementara', style: text.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final l in limits)
                ChoiceChip(
                  label: Text(_mb(l)),
                  selected: state.settings.cacheLimitBytes == l,
                  onSelected: (_) {
                    setState(() {
                      state.settings.cacheLimitBytes = l;
                      state.files.cacheLimitBytes = l;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await state.files.clearCache();
              await _refreshUsage();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Simpanan sementara dibersihkan. Buku offline tetap ada.')),
                );
              }
            },
            icon: const Icon(Icons.cleaning_services_rounded),
            label: const Text('Bersihkan simpanan sementara'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.emoji, required this.title, required this.subtitle});

  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: QColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
