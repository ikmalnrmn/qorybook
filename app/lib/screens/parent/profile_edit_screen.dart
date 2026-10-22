import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/profile.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/profile_form.dart';
import 'approved_books_screen.dart';

/// Tambah atau ubah profil anak, termasuk aturan waktu dan buku pilihan.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, this.profile});

  final ChildProfile? profile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  static const limitChoices = [0, 15, 30, 45, 60, 90, 120];

  late var _value = (
    name: widget.profile?.name ?? '',
    avatar: widget.profile?.avatar ?? avatars[context.read<AppState>().profiles.length % avatars.length],
    levels: widget.profile?.levels ?? <String>{'sd_awal'},
  );
  late int _limit = widget.profile?.dailyLimitMinutes ?? 0;
  late Bedtime? _bedtime = widget.profile?.bedtime;
  late bool _curated = widget.profile?.curatedOnly ?? false;
  int? _approvedCount;

  bool get _valid => _value.name.isNotEmpty && _value.levels.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadApproved();
  }

  Future<void> _loadApproved() async {
    final p = widget.profile;
    if (p == null) return;
    final ids = await context.read<AppState>().approvedFor(p.id);
    if (mounted) setState(() => _approvedCount = ids.length);
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final id = widget.profile?.id ?? await state.addProfile(_value.name, _value.avatar, _value.levels);
    await state.updateProfile(
      ChildProfile(
        id: id,
        name: _value.name,
        avatar: _value.avatar,
        levels: _value.levels,
        dailyLimitMinutes: _limit,
        bedtime: _bedtime,
        curatedOnly: _curated,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final p = widget.profile!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus profil ${p.name}?'),
        content: const Text('Progres baca, penanda, favorit, dan buku pilihan milik profil ini ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE5484D)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await context.read<AppState>().deleteProfile(p.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<int?> _pickTime(int minutes, String help) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: help,
      cancelText: 'Batal',
      confirmText: 'Pilih',
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Future<void> _openApproved() async {
    final p = widget.profile!;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ApprovedBooksScreen(profile: p.copyWith(levels: _value.levels)),
      ),
    );
    await _loadApproved();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canDelete = widget.profile != null && context.watch<AppState>().profiles.length > 1;
    final bedtime = _bedtime;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile == null ? 'Profil anak baru' : 'Ubah profil'),
        actions: [
          if (canDelete)
            IconButton(tooltip: 'Hapus profil', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              ProfileForm(initial: _value, onChanged: (v) => setState(() => _value = v)),
              const SizedBox(height: 28),
              Text('⏱️  Batas waktu harian', style: text.titleMedium),
              const SizedBox(height: 2),
              Text('Setelah habis, Qorybook menampilkan layar istirahat.', style: text.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in limitChoices)
                    ChoiceChip(
                      label: Text(m == 0 ? 'Tanpa batas' : '$m menit'),
                      selected: _limit == m,
                      onSelected: (_) => setState(() => _limit = m),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _Section(
                emoji: '🌙',
                title: 'Jam tidur',
                subtitle: bedtime == null ? 'Mati' : 'Aplikasi terkunci pukul ${bedtime.label}',
                value: bedtime != null,
                onChanged: (v) => setState(() => _bedtime = v ? Bedtime.defaultValue : null),
              ),
              if (bedtime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final m = await _pickTime(bedtime.start, 'Jam tidur mulai');
                            if (m != null) setState(() => _bedtime = Bedtime(m, bedtime.end));
                          },
                          child: Text('Mulai ${Bedtime.format(bedtime.start)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final m = await _pickTime(bedtime.end, 'Jam tidur selesai');
                            if (m != null) setState(() => _bedtime = Bedtime(bedtime.start, m));
                          },
                          child: Text('Selesai ${Bedtime.format(bedtime.end)}'),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              _Section(
                emoji: '✅',
                title: 'Hanya buku pilihan orang tua',
                subtitle: _curated
                    ? 'Anak hanya melihat buku yang Anda pilih'
                    : 'Anak bebas memilih buku sesuai jenjangnya',
                value: _curated,
                onChanged: (v) => setState(() => _curated = v),
              ),
              if (_curated) ...[
                const SizedBox(height: 8),
                if (widget.profile == null)
                  Text('Simpan profil dulu, lalu pilih bukunya.', style: text.bodySmall)
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                    onPressed: _openApproved,
                    icon: const Icon(Icons.library_add_check_rounded),
                    label: Text('Pilih buku (${_approvedCount ?? 0} dipilih)'),
                  ),
              ],
              const SizedBox(height: 32),
              FilledButton(onPressed: _valid ? _save : null, child: const Text('Simpan')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: QColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        secondary: Text(emoji, style: const TextStyle(fontSize: 24)),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
