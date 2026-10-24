import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models/contribution.dart';
import '../../models/supporter.dart';
import '../../services/telemetry.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/donation.dart';

/// Keluarga Literasi: ajakan donasi lewat Saweria dan daftar kontribusi orang tua.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> with WidgetsBindingObserver {
  /// Orang tua baru saja dibawa ke Saweria; tawarkan pencatatan saat kembali.
  bool _awaitingReturn = false;

  int _supporterVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_awaitingReturn) return;
    _awaitingReturn = false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: const Text('Sudah berdonasi? Catat supaya masuk daftar kontribusimu.'),
        action: SnackBarAction(label: 'Catat', onPressed: _record),
      ),
    );
  }

  Future<void> _donate() async {
    if (await Donation.open(context)) _awaitingReturn = true;
  }

  Future<void> _record() async {
    final c = await showModalBottomSheet<Contribution>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _RecordSheet(),
    );
    if (c == null || !mounted) return;
    final telemetry = context.read<Telemetry>();
    await context.read<AppState>().addContribution(c);
    unawaited(telemetry.event('donation_recorded', data: {'amount': c.amount}));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Terima kasih! ${rupiah(c.charityShare)} darinya untuk pendidikan anak yatim & dhuafa 💛'),
      ),
    );
  }

  Future<void> _remove(Contribution c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus catatan ini?'),
        content: Text('${rupiah(c.amount)} · ${shortDate(c.date)}\nDonasimu di Saweria tidak terpengaruh.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true && mounted) await context.read<AppState>().removeContribution(c);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final list = context.watch<AppState>().contributions;
    final total = list.fold(0, (s, c) => s + c.amount);
    final charity = list.fold(0, (s, c) => s + c.charityShare);

    return Scaffold(
      appBar: AppBar(title: const Text('Keluarga Literasi')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              const _Hero(),
              const SizedBox(height: 20),
              Text('Ke mana donasimu pergi?', style: text.titleLarge),
              const SizedBox(height: 10),
              const _SplitCard(),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: _donate,
                icon: const Icon(Icons.favorite_rounded),
                label: const Text('Donasi lewat Saweria'),
              ),
              const SizedBox(height: 8),
              Text(
                'Pembayaran diproses oleh Saweria. Qorybook tidak menyimpan data pembayaranmu. '
                'Berapa pun nominalnya sangat berarti.',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (context.read<Telemetry>().configured) ...[
                const SizedBox(height: 20),
                _SupporterCard(key: ValueKey(_supporterVersion), onChanged: () => setState(() => _supporterVersion++)),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: Text('Kontribusimu', style: text.titleLarge)),
                  TextButton.icon(
                    onPressed: _record,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Catat donasi'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (list.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: QColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: QColors.line, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Text('🌱', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text('Belum ada kontribusi tercatat', style: text.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Setelah berdonasi di Saweria, ketuk "Catat donasi" supaya riwayatnya muncul di sini.',
                        style: text.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else ...[
                _SummaryCard(count: list.length, total: total, charity: charity),
                const SizedBox(height: 12),
                Material(
                  color: QColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final c in list)
                        ListTile(
                          leading: const Text('💛', style: TextStyle(fontSize: 24)),
                          title: Text(rupiah(c.amount)),
                          subtitle: Text(
                            [
                              shortDate(c.date),
                              if (c.note.isNotEmpty) c.note,
                              '${rupiah(c.charityShare)} untuk yatim & dhuafa',
                            ].join(' · '),
                          ),
                          trailing: IconButton(
                            tooltip: 'Hapus catatan',
                            onPressed: () => _remove(c),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Catatan kontribusi hanya tersimpan di HP ini sebagai pengingatmu sendiri.',
                style: text.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const white = TextStyle(color: Colors.white);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9F68), QColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💛📚', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(Donation.invite, style: text.headlineSmall?.merge(white)),
          const SizedBox(height: 8),
          Text(Donation.bannerBody, style: text.bodyMedium?.merge(white)),
        ],
      ),
    );
  }
}

/// Pembagian donasi: operasional aplikasi dan pendidikan anak yatim & dhuafa.
class _SplitCard extends StatelessWidget {
  const _SplitCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const charity = AppConfig.donationCharityPercent;
    Widget row(String emoji, String percent, String title, String body, Color color) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$percent  $title', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: QColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 100 - charity,
                    child: const ColoredBox(color: QColors.primary),
                  ),
                  Expanded(
                    flex: charity,
                    child: const ColoredBox(color: QColors.leaf),
                  ),
                ],
              ),
            ),
          ),
          row(
            '🛠️',
            '${100 - charity}%',
            'Operasional Qorybook',
            'Perawatan aplikasi, pembaruan katalog buku, dan fitur baru.',
            QColors.primary,
          ),
          row('🤲', '$charity%', 'Pendidikan anak yatim & dhuafa', Donation.charity, QColors.leaf),
        ],
      ),
    );
  }
}

/// Ajakan opsional untuk memperkenalkan diri supaya developer bisa mengucapkan terima kasih.
class _SupporterCard extends StatelessWidget {
  const _SupporterCard({super.key, required this.onChanged});

  final VoidCallback onChanged;

  Future<void> _edit(BuildContext context) async {
    final telemetry = context.read<Telemetry>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<Supporter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SupporterSheet(initial: telemetry.settings.supporter),
    );
    if (result == null) return;
    final ok = await telemetry.saveSupporter(result);
    onChanged();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Terima kasih sudah berkenalan 💛' : 'Tersimpan di HP ini. Pengiriman gagal, coba lagi nanti.',
        ),
      ),
    );
  }

  Future<void> _forget(BuildContext context) async {
    await context.read<Telemetry>().forgetSupporter();
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = context.read<Telemetry>().settings.supporter;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1D6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QColors.sun, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s == null ? 'Mau kami ucapkan terima kasih?' : 'Halo, ${s.nickname}! 💛', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
            s == null
                ? 'Perkenalkan dirimu supaya kami bisa menyapa. Ini opsional, hanya untuk orang tua, '
                      'dan tidak pernah berisi data anak.'
                : (s.consent ? 'Kami boleh menghubungimu untuk ucapan terima kasih.' : 'Hanya tersimpan di HP ini.'),
            style: text.bodySmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.tonal(onPressed: () => _edit(context), child: Text(s == null ? 'Perkenalkan diri' : 'Ubah')),
              if (s != null) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: () => _forget(context), child: const Text('Hapus')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SupporterSheet extends StatefulWidget {
  const _SupporterSheet({this.initial});

  final Supporter? initial;

  @override
  State<_SupporterSheet> createState() => _SupporterSheetState();
}

class _SupporterSheetState extends State<_SupporterSheet> {
  late final _nickname = TextEditingController(text: widget.initial?.nickname ?? '');
  late final _contact = TextEditingController(text: widget.initial?.contact ?? '');
  late bool _consent = widget.initial?.consent ?? false;

  @override
  void dispose() {
    _nickname.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final valid = _nickname.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Perkenalkan dirimu', style: text.titleLarge),
            const SizedBox(height: 4),
            Text('Isi seperlunya. Jangan masukkan nama atau data anak.', style: text.bodySmall),
            const SizedBox(height: 14),
            TextField(
              controller: _nickname,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama panggilan', hintText: 'mis. Bunda Rani'),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _contact,
              maxLength: 80,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email atau WhatsApp (opsional)'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: const Text('Boleh dihubungi untuk ucapan terima kasih'),
              subtitle: const Text('Tanpa persetujuan ini, tidak ada yang dikirim ke server.'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: !valid
                    ? null
                    : () => Navigator.pop(
                        context,
                        Supporter(nickname: _nickname.text.trim(), contact: _contact.text.trim(), consent: _consent),
                      ),
                child: const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count, required this.total, required this.charity});

  final int count;
  final int total;
  final int charity;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8F1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QColors.leaf.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(
        children: [
          const Text('🏅', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${rupiah(total)} dari $count kontribusi', style: text.titleMedium),
                const SizedBox(height: 2),
                Text('${rupiah(charity)} di antaranya untuk pendidikan anak yatim & dhuafa', style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lembar untuk mencatat donasi yang baru dilakukan.
class _RecordSheet extends StatefulWidget {
  const _RecordSheet();

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  static const _presets = [10000, 25000, 50000, 100000];

  final _amount = TextEditingController();
  final _note = TextEditingController();

  int get _value => int.tryParse(_amount.text.replaceAll('.', '')) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Catat donasi', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Masukkan nominal yang kamu donasikan di Saweria.', style: text.bodySmall),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(prefixText: 'Rp ', labelText: 'Nominal'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _presets)
                ChoiceChip(
                  label: Text(rupiah(p)),
                  selected: _value == p,
                  onSelected: (_) => setState(() => _amount.text = '$p'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)', hintText: 'mis. Donasi bulan Oktober'),
          ),
          if (_value > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '🤲 ${rupiah(Contribution(amount: _value, date: DateTime.now()).charityShare)} akan disalurkan '
                'untuk pendidikan anak yatim & dhuafa.',
                style: text.labelMedium?.copyWith(color: QColors.leaf),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _value <= 0
                  ? null
                  : () => Navigator.pop(
                      context,
                      Contribution(amount: _value, date: DateTime.now(), note: _note.text.trim()),
                    ),
              child: const Text('Simpan'),
            ),
          ),
        ],
      ),
    );
  }
}
