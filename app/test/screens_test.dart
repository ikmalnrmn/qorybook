import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qorybook/data/book_files.dart';
import 'package:qorybook/data/database.dart';
import 'package:qorybook/data/settings_store.dart';
import 'package:qorybook/main.dart';
import 'package:qorybook/models/book.dart';
import 'package:qorybook/models/profile.dart';
import 'package:qorybook/screens/book_detail_screen.dart';
import 'package:qorybook/screens/reader_screen.dart';
import 'package:qorybook/services/parent_auth.dart';
import 'package:qorybook/state/app_state.dart';
import 'package:qorybook/state/kid_mode.dart';
import 'package:qorybook/state/screen_time.dart';
import 'package:qorybook/widgets/book_cover.dart';
import 'package:qorybook/widgets/disclaimer.dart';
import 'package:qorybook/widgets/hold_button.dart';
import 'package:qorybook/widgets/pin_pad.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

/// Jalankan dengan QORY_SHOTS=1 dan --update-goldens untuk menyimpan tangkapan layar.
final _shots = Platform.environment['QORY_SHOTS'] == '1';

typedef Device = ({Size size, double dpr, String name});

const phone = (size: Size(1080, 2340), dpr: 2.75, name: 'hp');
const tablet = (size: Size(2560, 1600), dpr: 2.0, name: 'tablet');

const _pageCount = 12;

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async => ByteData.view(File(path).readAsBytesSync().buffer);
  await (FontLoader('Nunito')..addFont(bytes('assets/fonts/Nunito.ttf'))).load();
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (root != null && icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(bytes(icons.path))).load();
  }
}

Future<Uint8List> _fakePage(WidgetTester tester) async {
  final bytes = await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, 595, 842), Paint()..color = const Color(0xFFFFF3D6));
    c.drawCircle(const Offset(300, 330), 170, Paint()..color = const Color(0xFF4DA8FF));
    c.drawRect(const Rect.fromLTWH(80, 600, 435, 24), Paint()..color = const Color(0xFF2B2D42));
    c.drawRect(const Rect.fromLTWH(80, 650, 360, 24), Paint()..color = const Color(0xFF2B2D42));
    final img = await rec.endRecording().toImage(595, 842);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

Future<void> _mockPdfChannel(WidgetTester tester) async {
  final page = await _fakePage(tester);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('qorybook/pdf'), (call) async {
    return switch (call.method) {
      'open' => {
        'id': 1,
        'sizes': List.generate(_pageCount, (_) => [595, 842]),
      },
      'render' => page,
      _ => null,
    };
  });
}

typedef App = ({
  AppState state,
  KidModeController kid,
  FakeKiosk kiosk,
  SettingsStore settings,
  ScreenTimeController screenTime,
});

Future<App> _pumpApp(WidgetTester tester, Device device, FakeDatabase db, {bool onboarded = true}) async {
  tester.view.physicalSize = device.size;
  tester.view.devicePixelRatio = device.dpr;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final settings = await SettingsStore.open();
  final auth = ParentAuth(settings);
  final kiosk = FakeKiosk();
  final kid = KidModeController(settings: settings, kiosk: kiosk);
  final state = AppState(db: db, settings: settings, files: BookFiles(db), catalogRepository: FakeCatalogRepository());
  final screenTime = ScreenTimeController(app: state, kid: kid, db: db, settings: settings);
  await tester.runAsync(() async {
    if (onboarded) {
      settings.onboarded = true;
      await auth.setPin(_pin);
    }
    await kid.init();
    if (onboarded) await kid.enter();
    await state.init();
    await screenTime.init();
  });
  await tester.pumpWidget(QorybookApp(state: state, kidMode: kid, auth: auth, screenTime: screenTime));
  await tester.pump();
  return (state: state, kid: kid, kiosk: kiosk, settings: settings, screenTime: screenTime);
}

/// Bongkar pohon widget dan hentikan timer Mode Anak.
Future<void> _teardown(WidgetTester tester, App app) async {
  await tester.pumpWidget(const SizedBox());
  app.screenTime.dispose();
  app.kid.dispose();
  await tester.pump(const Duration(seconds: 5));
}

const _pin = '1234';

/// Ketik PIN di PinPad lalu beri waktu nyata untuk hashing di isolate.
Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.descendant(of: find.byType(PinPad), matching: find.text(d)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 600));
  if (_shots) {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }
}

/// Database dengan sedikit riwayat supaya bagian "Lanjutkan" dan "Sering dibaca" tampil.
FakeDatabase _seededDb(List<Book> books) {
  final db = FakeDatabase();
  final pdfs = books.where((b) => b.format == BookFormat.pdf).toList();
  for (final b in pdfs.take(3)) {
    db.progressRows[b.id] = ReadingProgress(
      bookId: b.id,
      position: 5,
      length: 20,
      finished: false,
      updatedAt: DateTime.now(),
    );
    db.sessions[b.id] = 600;
  }
  db.favoriteIds.addAll(pdfs.skip(3).take(4).map((b) => b.id));
  return db;
}

void main() {
  setUpAll(() async {
    BookCover.networkImages = false;
    await _loadFonts();
  });

  final catalogBooks = FakeCatalogRepository().loadLocal();

  for (final device in [phone, tablet]) {
    testWidgets('semua tab utama tampil tanpa error (${device.name})', (tester) async {
      final books = (await tester.runAsync(() => catalogBooks))!.books;
      final app = await _pumpApp(tester, device, _seededDb(books));
      expect(find.text('Mau baca apa hari ini?'), findsOneWidget);
      await _shot(tester, '${device.name}_1_beranda');

      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -900));
      await _shot(tester, '${device.name}_2_beranda_bawah');

      await tester.tap(find.text('Jelajah'));
      await _shot(tester, '${device.name}_3_jelajah');

      await tester.tap(find.text('Cari'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'laut');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('buku ditemukan'), findsOneWidget);
      await _shot(tester, '${device.name}_4_cari');

      await tester.tap(find.text('Rak Bukuku'));
      await _shot(tester, '${device.name}_5_rak');
      await _teardown(tester, app);
    });

    testWidgets('detail buku dan pembaca (${device.name})', (tester) async {
      final books = (await tester.runAsync(() => catalogBooks))!.books;
      final db = _seededDb(books);
      final book = books.firstWhere((b) => b.format == BookFormat.pdf && b.synopsis.length > 120);
      db.downloadRows[book.id] = DownloadEntry(
        bookId: book.id,
        path: File('assets/catalog.json').absolute.path,
        bytes: 1,
        lastOpened: DateTime.now(),
        pinned: false,
      );
      await _mockPdfChannel(tester);
      final app = await _pumpApp(tester, device, db);
      final state = app.state;
      final nav = tester.state<NavigatorState>(find.byType(Navigator));

      nav.push(MaterialPageRoute<void>(builder: (_) => BookDetailScreen(bookId: book.id)));
      await tester.pumpAndSettle();
      expect(find.text(book.title), findsWidgets);
      await _shot(tester, '${device.name}_6_detail');
      await tester.scrollUntilVisible(
        find.text(Disclaimer.short(book.sourceName)),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(Disclaimer.short(book.sourceName)), findsOneWidget);
      await tester.scrollUntilVisible(find.text(book.title).first, -300, scrollable: find.byType(Scrollable).last);

      nav.push(MaterialPageRoute<void>(builder: (_) => ReaderScreen(book: book, initialPage: 0)));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('dari $_pageCount'), findsOneWidget);
      await _shot(tester, '${device.name}_7_pembaca');

      // Ketuk tepi kanan sampai melewati halaman terakhir.
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      for (var i = 0; i < _pageCount + 1; i++) {
        await tester.tapAt(Offset(size.width * 0.92, size.height / 2));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 450));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      }
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('selesai membaca'), findsOneWidget);
      expect(state.progress[book.id]?.finished, isTrue);
      await _shot(tester, '${device.name}_8_selesai');

      await _teardown(tester, app);
    });

    testWidgets('pengaturan awal: PIN, profil, lalu Mode Anak (${device.name})', (tester) async {
      final app = await _pumpApp(tester, device, FakeDatabase(), onboarded: false);
      expect(find.text('Selamat datang di Qorybook'), findsOneWidget);
      expect(find.text(Disclaimer.title), findsOneWidget);
      expect(find.text(Disclaimer.role), findsOneWidget);
      await _shot(tester, '${device.name}_9_onboarding_1');

      await tester.tap(find.text('Atur sekarang'));
      await tester.pumpAndSettle();
      expect(find.text('Buat PIN orang tua'), findsOneWidget);
      await _shot(tester, '${device.name}_9_onboarding_2_pin');

      await _enterPin(tester, _pin);
      expect(find.text('Ulangi PIN'), findsOneWidget);
      await _enterPin(tester, '9999');
      expect(find.text('PIN tidak sama. Ulangi dari awal.'), findsOneWidget);
      await _enterPin(tester, _pin);
      await _enterPin(tester, _pin);
      await tester.pumpAndSettle();
      expect(find.text('Siapa yang akan membaca?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Aisyah');
      await tester.tap(find.text('🐼'));
      await tester.pump();
      await _shot(tester, '${device.name}_9_onboarding_3_profil');
      await tester.ensureVisible(find.text('Lanjut'));
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Siapkan Mode Anak'), findsOneWidget);
      await _shot(tester, '${device.name}_9_onboarding_4_mode_anak');

      await tester.tap(find.text('Mulai Mode Anak'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(app.settings.onboarded, isTrue);
      expect(app.kid.active, isTrue);
      expect(app.kiosk.calls, containsAll(['pin', 'dnd:on']));
      expect(find.textContaining('Aisyah!'), findsOneWidget);
      expect(app.state.activeProfile?.avatar, 'panda');
      await _teardown(tester, app);
    });

    testWidgets('gerbang orang tua lalu Area Orang Tua (${device.name})', (tester) async {
      final app = await _pumpApp(tester, device, FakeDatabase());
      expect(app.kid.active, isTrue);

      // Ketukan singkat hanya memberi petunjuk.
      await tester.tap(find.byType(HoldButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Khusus orang tua: tekan dan tahan tombol ini'), findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldButton)));
      await tester.pump(); // frame pertama memulai animasi tahan
      await tester.pump(const Duration(milliseconds: 1700));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Khusus Orang Tua'), findsOneWidget);
      await _shot(tester, '${device.name}_10_gerbang');

      await _enterPin(tester, '0000');
      expect(find.text('PIN salah, coba lagi.'), findsOneWidget);
      expect(app.kid.active, isTrue);

      await _enterPin(tester, _pin);
      await tester.pumpAndSettle();
      expect(app.kid.active, isFalse);
      expect(app.kiosk.calls, containsAll(['unpin', 'dnd:off']));
      expect(find.text('Area Orang Tua'), findsOneWidget);
      await _shot(tester, '${device.name}_11_area_orang_tua');

      // Matikan Jangan Ganggu dari pengaturan.
      await tester.ensureVisible(find.text('Senyapkan notifikasi').first);
      await tester.tap(find.text('Senyapkan notifikasi').first);
      await tester.pump();
      expect(app.settings.kioskDnd, isFalse);

      // Tambah profil PAUD saja lalu mulai Mode Anak untuknya.
      // Daftar dibangun malas; gulir kembali ke atas sampai tombolnya ada.
      await tester.scrollUntilVisible(find.text('Tambah profil anak'), -300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Tambah profil anak'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bima');
      await tester.tap(find.textContaining('SD Kelas 1–3'));
      await tester.tap(find.textContaining('PAUD / TK'));
      await tester.pump();
      await _shot(tester, '${device.name}_12_profil_baru');
      await tester.scrollUntilVisible(find.text('Simpan'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(app.state.profiles.map((p) => p.name), contains('Bima'));

      await tester.scrollUntilVisible(
        find.text('Mulai Mode Anak untuk Bima'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Mulai Mode Anak untuk Bima'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(app.kid.active, isTrue);
      expect(app.state.activeProfile?.name, 'Bima');
      expect(app.state.books, isNotEmpty);
      expect(app.state.books.every((b) => b.levels.contains('paud')), isTrue);
      await _teardown(tester, app);
    });

    testWidgets('batas waktu habis: layar istirahat lalu orang tua menambah waktu (${device.name})', (tester) async {
      final db = FakeDatabase();
      db.profileRows[0] = db.profileRows[0].copyWith(name: 'Aisyah', dailyLimitMinutes: 15);
      db.screenSeconds['1|${ScreenTimeController.dayKey(DateTime.now())}'] = 15 * 60;
      final app = await _pumpApp(tester, device, db);
      await tester.pump(const Duration(milliseconds: 600));
      expect(app.screenTime.state, ScreenTimeState.limitReached);
      expect(find.text('Waktu membaca hari ini habis'), findsOneWidget);
      expect(find.text('Mau baca apa hari ini?'), findsNothing);
      await _shot(tester, '${device.name}_13_waktu_habis');

      final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
      await gesture.up();
      await tester.pumpAndSettle();
      await _enterPin(tester, _pin);
      await tester.pumpAndSettle();
      expect(find.text('Beri waktu tambahan'), findsOneWidget);
      await tester.tap(find.text('+ 15 menit'));
      await tester.pumpAndSettle();
      expect(app.screenTime.state, ScreenTimeState.ok);
      expect(find.text('Mau baca apa hari ini?'), findsOneWidget);
      expect(app.kid.active, isTrue);
      await _teardown(tester, app);
    });

    testWidgets('jam tidur menampilkan layar malam (${device.name})', (tester) async {
      final db = FakeDatabase();
      final now = DateTime.now();
      final m = now.hour * 60 + now.minute;
      // Jam tidur dimulai satu menit lalu, selesai dua jam lagi.
      db.profileRows[0] = db.profileRows[0].copyWith(
        name: 'Bima',
        bedtime: () => Bedtime((m - 1 + 1440) % 1440, (m + 120) % 1440),
      );
      final app = await _pumpApp(tester, device, db);
      await tester.pump(const Duration(milliseconds: 600));
      expect(app.screenTime.state, ScreenTimeState.bedtime);
      expect(find.text('Sudah waktunya tidur'), findsOneWidget);
      await _shot(tester, '${device.name}_14_jam_tidur');
      await _teardown(tester, app);
    });

    testWidgets('buku pilihan orang tua (${device.name})', (tester) async {
      final books = (await tester.runAsync(() => catalogBooks))!.books;
      final db = FakeDatabase();
      db.profileRows[0] = db.profileRows[0].copyWith(curatedOnly: true);
      final app = await _pumpApp(tester, device, db);
      expect(app.state.books, isEmpty);
      expect(find.text('Rak bukumu masih kosong'), findsOneWidget);

      final picks = books.where((b) => b.levels.contains('paud')).take(3).map((b) => b.id).toList();
      await tester.runAsync(() => app.state.setApproved(1, picks, true));
      await tester.pump();
      expect(app.state.books.map((b) => b.id).toSet(), picks.toSet());
      expect(find.text('Rak bukumu masih kosong'), findsNothing);

      // Buka pemilih buku dari Area Orang Tua.
      await tester.runAsync(app.kid.exit);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_rounded).first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Pilih buku ('),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Pilih buku (3 dipilih)'), findsOneWidget);
      await _shot(tester, '${device.name}_15_aturan_profil');
      await tester.tap(find.textContaining('Pilih buku ('));
      await tester.pumpAndSettle();
      expect(find.text('✅ Dipilih (3)'), findsOneWidget);
      await _shot(tester, '${device.name}_16_pilih_buku');
      await _teardown(tester, app);
    });
  }
}
