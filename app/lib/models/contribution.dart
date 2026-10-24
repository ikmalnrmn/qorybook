import '../config.dart';

/// Satu donasi Keluarga Literasi yang dicatat orang tua setelah berdonasi di Saweria.
class Contribution {
  const Contribution({required this.amount, required this.date, this.note = ''});

  /// Rupiah.
  final int amount;
  final DateTime date;
  final String note;

  /// Bagian yang disalurkan untuk pendidikan anak yatim dan dhuafa.
  int get charityShare => (amount * AppConfig.donationCharityPercent / 100).round();

  Map<String, Object?> toJson() => {'amount': amount, 'date': date.millisecondsSinceEpoch, 'note': note};

  factory Contribution.fromJson(Map<String, Object?> m) => Contribution(
    amount: (m['amount'] as num).toInt(),
    date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt()),
    note: m['note'] as String? ?? '',
  );
}

/// "Rp 50.000"
String rupiah(int amount) {
  final digits = amount.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}Rp ${out.toString()}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// "24 Okt 2026"
String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
