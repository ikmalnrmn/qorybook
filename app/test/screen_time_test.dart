import 'package:flutter_test/flutter_test.dart';
import 'package:qorybook/data/book_files.dart';
import 'package:qorybook/data/settings_store.dart';
import 'package:qorybook/models/profile.dart';
import 'package:qorybook/state/app_state.dart';
import 'package:qorybook/state/kid_mode.dart';
import 'package:qorybook/state/screen_time.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late FakeDatabase db;
  late AppState app;
  late KidModeController kid;
  late ScreenTimeController st;

  Future<void> setUpWith({int limit = 0, Bedtime? bedtime, DateTime? start}) async {
    now = start ?? DateTime(2026, 10, 22, 15, 0);
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsStore.open();
    db = FakeDatabase();
    db.profileRows[0] = db.profileRows[0].copyWith(dailyLimitMinutes: limit, bedtime: () => bedtime);
    app = AppState(db: db, settings: settings, files: BookFiles(db), catalogRepository: FakeCatalogRepository());
    await app.init();
    kid = KidModeController(settings: settings, kiosk: FakeKiosk());
    await kid.init();
    await kid.enter();
    st = ScreenTimeController(
      app: app,
      kid: kid,
      db: db,
      settings: settings,
      clock: () => now,
      tickInterval: const Duration(hours: 1), // detak dipanggil manual di tes
    );
    await st.init();
  }

  tearDown(() {
    st.dispose();
    kid.dispose();
  });

  Future<void> advance(Duration d) async {
    now = now.add(d);
    await st.tick();
  }

  test('tanpa batas: selalu boleh, waktu tetap dicatat', () async {
    await setUpWith();
    await advance(const Duration(seconds: 45));
    expect(st.state, ScreenTimeState.ok);
    expect(st.remaining, isNull);
    expect(await db.screenTime(1, '2026-10-22'), 45);
  });

  test('batas harian: pengingat lalu terkunci', () async {
    await setUpWith(limit: 1);
    await advance(const Duration(seconds: 30));
    expect(st.state, ScreenTimeState.almostUp);
    expect(st.remaining, const Duration(seconds: 30));
    await advance(const Duration(seconds: 40));
    expect(st.state, ScreenTimeState.limitReached);
    expect(st.locked, isTrue);
    // Saat terkunci waktu tidak bertambah.
    await advance(const Duration(seconds: 30));
    expect(await db.screenTime(1, '2026-10-22'), 70);
  });

  test('HP tertidur lama tidak dihitung lebih dari 60 detik', () async {
    await setUpWith(limit: 60);
    await advance(const Duration(minutes: 30));
    expect(st.usedSeconds, 60);
  });

  test('jam tidur melewati tengah malam', () async {
    const bt = Bedtime(20 * 60, 6 * 60);
    expect(bt.contains(DateTime(2026, 1, 1, 21, 30)), isTrue);
    expect(bt.contains(DateTime(2026, 1, 1, 5, 59)), isTrue);
    expect(bt.contains(DateTime(2026, 1, 1, 6, 0)), isFalse);
    expect(bt.contains(DateTime(2026, 1, 1, 19, 59)), isFalse);

    await setUpWith(bedtime: bt, start: DateTime(2026, 10, 22, 19, 59, 30));
    expect(st.state, ScreenTimeState.ok);
    await advance(const Duration(seconds: 40));
    expect(st.state, ScreenTimeState.bedtime);
  });

  test('waktu tambahan dari orang tua lalu terkunci lagi', () async {
    await setUpWith(limit: 1);
    await advance(const Duration(seconds: 50));
    await advance(const Duration(seconds: 20));
    expect(st.state, ScreenTimeState.limitReached);

    await st.grantExtra(const Duration(minutes: 15));
    expect(st.state, ScreenTimeState.ok);
    await advance(const Duration(seconds: 50));
    expect(st.state, ScreenTimeState.ok);

    for (var i = 0; i < 16; i++) {
      await advance(const Duration(minutes: 1));
    }
    expect(st.state, ScreenTimeState.limitReached);
  });

  test('hari baru: hitungan mulai dari nol', () async {
    await setUpWith(limit: 1, start: DateTime(2026, 10, 22, 23, 58, 0));
    await advance(const Duration(seconds: 59));
    await advance(const Duration(seconds: 1));
    expect(st.state, ScreenTimeState.limitReached);
    await advance(const Duration(seconds: 61)); // 00:00:01 hari berikutnya
    expect(st.usedSeconds, 0);
    expect(st.state, isNot(ScreenTimeState.limitReached));
  });

  test('tidak dihitung di luar Mode Anak', () async {
    await setUpWith(limit: 30);
    await kid.exit();
    await advance(const Duration(seconds: 50));
    expect(st.usedSeconds, 0);
  });
}
