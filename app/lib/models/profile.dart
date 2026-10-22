import 'package:flutter/material.dart';

/// Jam tidur dalam menit sejak tengah malam; boleh melewati tengah malam (mis. 20.00–06.00).
class Bedtime {
  const Bedtime(this.start, this.end);

  final int start;
  final int end;

  static const defaultValue = Bedtime(20 * 60, 6 * 60);

  bool contains(DateTime t) {
    final m = t.hour * 60 + t.minute;
    return start <= end ? (m >= start && m < end) : (m >= start || m < end);
  }

  static String format(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}.${(minutes % 60).toString().padLeft(2, '0')}';

  String get label => '${format(start)}–${format(end)}';

  @override
  bool operator ==(Object other) => other is Bedtime && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Profil anak. Progres, penanda, dan favorit tersimpan per profil.
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.levels,
    this.dailyLimitMinutes = 0,
    this.bedtime,
    this.curatedOnly = false,
  });

  final int id;
  final String name;
  final String avatar;
  final Set<String> levels;

  /// 0 = tanpa batas.
  final int dailyLimitMinutes;

  /// null = tanpa jam tidur.
  final Bedtime? bedtime;

  /// Anak hanya melihat buku yang dipilih orang tua.
  final bool curatedOnly;

  ChildProfile copyWith({
    String? name,
    String? avatar,
    Set<String>? levels,
    int? dailyLimitMinutes,
    Bedtime? Function()? bedtime,
    bool? curatedOnly,
  }) => ChildProfile(
    id: id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    levels: levels ?? this.levels,
    dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
    bedtime: bedtime != null ? bedtime() : this.bedtime,
    curatedOnly: curatedOnly ?? this.curatedOnly,
  );

  String get emoji => avatarEmoji(avatar);
  Color get color => avatarColor(avatar);

  factory ChildProfile.fromRow(Map<String, Object?> r) {
    final start = r['bedtime_start'] as int?;
    final end = r['bedtime_end'] as int?;
    return ChildProfile(
      id: r['id'] as int,
      name: r['name'] as String,
      avatar: r['avatar'] as String,
      levels: (r['levels'] as String).split(',').where((e) => e.isNotEmpty).toSet(),
      dailyLimitMinutes: r['daily_limit_minutes'] as int? ?? 0,
      bedtime: start != null && end != null ? Bedtime(start, end) : null,
      curatedOnly: (r['curated_only'] as int? ?? 0) == 1,
    );
  }
}

const avatars = [
  'fox',
  'panda',
  'tiger',
  'rabbit',
  'frog',
  'lion',
  'koala',
  'penguin',
  'unicorn',
  'owl',
  'turtle',
  'octopus',
];

String avatarEmoji(String id) => switch (id) {
  'fox' => '🦊',
  'panda' => '🐼',
  'tiger' => '🐯',
  'rabbit' => '🐰',
  'frog' => '🐸',
  'lion' => '🦁',
  'koala' => '🐨',
  'penguin' => '🐧',
  'unicorn' => '🦄',
  'owl' => '🦉',
  'turtle' => '🐢',
  'octopus' => '🐙',
  _ => '🙂',
};

Color avatarColor(String id) => switch (id) {
  'fox' => const Color(0xFFFF9F43),
  'panda' => const Color(0xFF8D99AE),
  'tiger' => const Color(0xFFFFB020),
  'rabbit' => const Color(0xFFFF8FB1),
  'frog' => const Color(0xFF4CC38A),
  'lion' => const Color(0xFFE8A33D),
  'koala' => const Color(0xFF9AA5B1),
  'penguin' => const Color(0xFF4DA8FF),
  'unicorn' => const Color(0xFFB794F4),
  'owl' => const Color(0xFFA47148),
  'turtle' => const Color(0xFF2EC4B6),
  'octopus' => const Color(0xFFFF6B8B),
  _ => const Color(0xFFFF7A45),
};
