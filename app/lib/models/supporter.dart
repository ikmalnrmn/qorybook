/// Perkenalan opsional orang tua supaya developer bisa mengucapkan terima kasih.
/// Tidak pernah berisi data anak.
class Supporter {
  const Supporter({required this.nickname, this.contact = '', this.consent = false});

  final String nickname;

  /// Email atau nomor WhatsApp, boleh kosong.
  final String contact;

  /// Orang tua mengizinkan dihubungi untuk ucapan terima kasih.
  final bool consent;

  Map<String, Object?> toJson() => {'nickname': nickname, 'contact': contact, 'consent': consent};

  factory Supporter.fromJson(Map<String, Object?> json) => Supporter(
    nickname: json['nickname'] as String? ?? '',
    contact: json['contact'] as String? ?? '',
    consent: json['consent'] as bool? ?? false,
  );
}
