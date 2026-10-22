import 'package:flutter/material.dart';

/// Label, ikon, dan warna untuk kategori agar mudah dikenali anak.

const levelOrder = ['paud', 'sd_awal', 'sd_tinggi'];

String levelLabel(String id) => switch (id) {
  'paud' => 'PAUD / TK',
  'sd_awal' => 'SD Kelas 1–3',
  'sd_tinggi' => 'SD Kelas 4–6',
  _ => id,
};

String levelHint(String id) => switch (id) {
  'paud' => 'Usia 4–6 tahun',
  'sd_awal' => 'Usia 6–9 tahun',
  'sd_tinggi' => 'Usia 9–12 tahun',
  _ => '',
};

String levelEmoji(String id) => switch (id) {
  'paud' => '🧸',
  'sd_awal' => '✏️',
  'sd_tinggi' => '🎒',
  _ => '📚',
};

Color levelColor(String id) => switch (id) {
  'paud' => const Color(0xFFFF9F43),
  'sd_awal' => const Color(0xFF4DA8FF),
  'sd_tinggi' => const Color(0xFF8E6CEF),
  _ => const Color(0xFF4CC38A),
};

String kindLabel(String id) => switch (id) {
  'buku' => 'Buku Bergambar',
  'komik' => 'Komik',
  'audio' => 'Buku Audio',
  'video' => 'Buku Video',
  _ => id,
};

String kindEmoji(String id) => switch (id) {
  'buku' => '📖',
  'komik' => '💬',
  'audio' => '🎧',
  'video' => '🎬',
  _ => '📚',
};

Color kindColor(String id) => switch (id) {
  'buku' => const Color(0xFF4CC38A),
  'komik' => const Color(0xFFFF6B8B),
  'audio' => const Color(0xFF4DA8FF),
  'video' => const Color(0xFFFFB020),
  _ => const Color(0xFF8E6CEF),
};

const _themeEmoji = {
  'Hewan dan Tumbuhan': '🐘',
  'Alam dan Lingkungan': '🌳',
  'Petualangan': '🧭',
  'Anak Indonesia': '🧒',
  'Tokoh Indonesia': '🦸',
  'Cerita Rakyat': '🏯',
  'Bahasa': '🔤',
  'Keberagaman': '🤝',
  'Seni dan Budaya': '🎭',
  'Kebencanaan': '⛑️',
  'Kesehatan': '🩺',
  'Arsitektur': '🏠',
  'Kuliner': '🍲',
  'Ekonomi Kreatif': '💡',
  'Tata Surya': '🪐',
  'Pencegahan Kekerasan terhadap Anak': '🛡️',
  'Perangkulan Anak Berkebutuhan Khusus': '💞',
  'Kedudukan Anak dalam Komunitas/Masyarakat': '👨‍👩‍👧',
  'Pendekatan Sains dalam Kehidupan': '🔬',
  'Pengenalan Literasi Finansial': '🪙',
  'Kearifan Lokal melalui Permainan Tradisional dan Bahasa Daerah': '🪁',
  'Pengenalan Literasi Kewargaan': '🏛️',
  'Sanitasi': '🚿',
  'Fiksi Sains': '🚀',
  'Perubahan Iklim dan Isu Lingkungan': '🌍',
  'Olahraga': '⚽',
};

const _themeShort = {
  'Pencegahan Kekerasan terhadap Anak': 'Aman & Terlindungi',
  'Perangkulan Anak Berkebutuhan Khusus': 'Teman Istimewa',
  'Kedudukan Anak dalam Komunitas/Masyarakat': 'Aku & Masyarakat',
  'Pendekatan Sains dalam Kehidupan': 'Sains Sehari-hari',
  'Pengenalan Literasi Finansial': 'Belajar Uang',
  'Kearifan Lokal melalui Permainan Tradisional dan Bahasa Daerah': 'Permainan Tradisional',
  'Pengenalan Literasi Kewargaan': 'Warga Cilik',
  'Perubahan Iklim dan Isu Lingkungan': 'Iklim & Bumi',
};

const _palette = [
  Color(0xFF4CC38A),
  Color(0xFF4DA8FF),
  Color(0xFFFF9F43),
  Color(0xFFFF6B8B),
  Color(0xFF8E6CEF),
  Color(0xFF2EC4B6),
  Color(0xFFFFB020),
  Color(0xFF5C7CFA),
];

String themeEmoji(String theme) => _themeEmoji[theme] ?? '📚';

String themeShortLabel(String theme) => _themeShort[theme] ?? theme;

Color themeColor(String theme) {
  final i = theme.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
  return _palette[i % _palette.length];
}

String languageEmoji(String lang) => switch (lang) {
  'Indonesia' => '🇮🇩',
  'Inggris' => '🇬🇧',
  _ => '🗣️',
};

String formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.0', '')}jt';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}rb';
  return '$n';
}

String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  if (m < 1) return '$seconds detik';
  if (m < 60) return '$m menit';
  final h = m ~/ 60;
  final rest = m % 60;
  return rest == 0 ? '$h jam' : '$h jam $rest menit';
}
