// Entrypoint demo untuk tangkapan layar promosi: mengisi data dummy sekali,
// lalu menjalankan aplikasi seperti biasa.
//   flutter build apk --debug -t tool/demo_main.dart
// PIN orang tua demo: 1234.
import 'package:flutter/widgets.dart';
import 'package:qorybook/data/catalog_repository.dart';
import 'package:qorybook/data/database.dart';
import 'package:qorybook/data/settings_store.dart';
import 'package:qorybook/main.dart' as app;
import 'package:qorybook/models/book.dart';
import 'package:qorybook/models/profile.dart';
import 'package:qorybook/services/parent_auth.dart';
import 'package:qorybook/state/screen_time.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('demo_seeded') != true) {
    await _seed();
    await prefs.setBool('demo_seeded', true);
  }
  await app.main();
}

Future<void> _seed() async {
  final db = await AppDatabase.open();
  final settings = await SettingsStore.open();
  await ParentAuth(settings).setPin('1234');
  settings.onboarded = true;

  final first = (await db.profiles()).first;
  await db.updateProfile(
    first.copyWith(
      name: 'Aisyah',
      avatar: 'rabbit',
      levels: {'sd_awal', 'sd_tinggi'},
      dailyLimitMinutes: 60,
      bedtime: () => Bedtime.defaultValue,
    ),
  );
  await db.addProfile('Bima', 'lion', {'paud'});

  final books = (await CatalogRepository().loadLocal()).books.where((b) => b.format == BookFormat.pdf).toList();
  final sd = books.where((b) => b.levels.contains('sd_awal')).toList();
  final paud = books.where((b) => b.levels.contains('paud')).toList();
  final now = DateTime.now();

  // Aisyah: tiga buku sedang dibaca, dua selesai, empat favorit.
  final reading = [(sd[0], 5, 20), (sd[1], 11, 24), (sd[3], 2, 16)];
  for (final (book, page, total) in reading) {
    await db.saveProgress(first.id, book.id, position: page, length: total);
  }
  for (final book in [sd[4], sd[6]]) {
    await db.saveProgress(first.id, book.id, position: 15, length: 16, finished: true);
  }
  for (final book in sd.skip(7).take(4)) {
    await db.setFavorite(first.id, book.id, true);
  }
  for (var d = 0; d < 6; d++) {
    final book = sd[d % 5];
    await db.addSession(first.id, book.id, now.subtract(Duration(days: d, hours: 2)), 600 + d * 240);
  }
  await db.addScreenTime(first.id, ScreenTimeController.dayKey(now), 25 * 60);

  // Bima (PAUD): satu buku sedang dibaca.
  final bima = (await db.profiles()).last;
  await db.saveProgress(bima.id, paud[0].id, position: 3, length: 12);
  await db.addSession(bima.id, paud[0].id, now.subtract(const Duration(hours: 3)), 420);
}
