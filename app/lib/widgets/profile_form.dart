import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/labels.dart';
import '../theme.dart';

/// Isian nama, avatar, dan jenjang anak.
class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key, required this.initial, required this.onChanged});

  final ({String name, String avatar, Set<String> levels}) initial;
  final ValueChanged<({String name, String avatar, Set<String> levels})> onChanged;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final _name = TextEditingController(text: widget.initial.name);
  late String _avatar = widget.initial.avatar;
  late final Set<String> _levels = {...widget.initial.levels};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged((name: _name.text.trim(), avatar: _avatar, levels: {..._levels}));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: avatarColor(_avatar).withValues(alpha: 0.2), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(avatarEmoji(_avatar), style: const TextStyle(fontSize: 52)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Nama panggilan', style: text.titleSmall),
        const SizedBox(height: 6),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          maxLength: 20,
          onChanged: (_) => _emit(),
          decoration: InputDecoration(
            hintText: 'Misalnya: Aisyah',
            counterText: '',
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: QColors.line, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: QColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Pilih teman membaca', style: text.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in avatars)
              InkResponse(
                onTap: () {
                  setState(() => _avatar = a);
                  _emit();
                },
                radius: 30,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: avatarColor(a).withValues(alpha: a == _avatar ? 0.3 : 0.1),
                    border: Border.all(color: a == _avatar ? avatarColor(a) : Colors.transparent, width: 3),
                  ),
                  child: Text(avatarEmoji(a), style: const TextStyle(fontSize: 28)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Buku untuk jenjang', style: text.titleSmall),
        const SizedBox(height: 2),
        Text('Anak hanya melihat buku dari jenjang yang dipilih.', style: text.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final l in levelOrder)
              FilterChip(
                label: Text('${levelEmoji(l)} ${levelLabel(l)}'),
                selected: _levels.contains(l),
                onSelected: (v) {
                  setState(() => v ? _levels.add(l) : _levels.remove(l));
                  _emit();
                },
              ),
          ],
        ),
      ],
    );
  }
}
