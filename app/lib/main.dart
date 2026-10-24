import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/book_files.dart';
import 'data/catalog_repository.dart';
import 'data/database.dart';
import 'data/settings_store.dart';
import 'platform_init.dart';
import 'screens/kid_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/parent/parent_home.dart';
import 'services/parent_auth.dart';
import 'services/telemetry.dart';
import 'state/app_state.dart';
import 'state/kid_mode.dart';
import 'state/screen_time.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  initPlatform();
  final db = await AppDatabase.open();
  final settings = await SettingsStore.open();
  final state = AppState(
    db: db,
    settings: settings,
    files: BookFiles(db, cacheLimitBytes: settings.cacheLimitBytes),
    catalogRepository: CatalogRepository(),
  );
  final kidMode = KidModeController(settings: settings);
  final auth = ParentAuth(settings);
  final screenTime = ScreenTimeController(app: state, kid: kidMode, db: db, settings: settings);
  final telemetry = Telemetry(settings: settings);
  runApp(QorybookApp(state: state, kidMode: kidMode, auth: auth, screenTime: screenTime, telemetry: telemetry));
  unawaited(telemetry.ping());

  await kidMode.init();
  // Aplikasi selalu dibuka dalam Mode Anak; Area Orang Tua hanya lewat PIN.
  if (settings.onboarded) await kidMode.enter();
  await state.init();
  await screenTime.init();
}

class QorybookApp extends StatelessWidget {
  const QorybookApp({
    super.key,
    required this.state,
    required this.kidMode,
    required this.auth,
    required this.screenTime,
    this.telemetry,
  });

  final AppState state;
  final KidModeController kidMode;
  final ParentAuth auth;
  final ScreenTimeController screenTime;

  /// Tanpa ini (mis. di tes), penghitungan pengguna tidak aktif.
  final Telemetry? telemetry;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: kidMode),
        Provider.value(value: auth),
        ChangeNotifierProvider.value(value: screenTime),
        Provider.value(
          value: telemetry ?? Telemetry(settings: state.settings, baseUrl: '', anonKey: ''),
        ),
      ],
      child: MaterialApp(
        title: 'Qorybook',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.catalog == null) {
      return Scaffold(
        body: Center(
          child: state.loadError == null
              ? const _Splash()
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Katalog gagal dimuat: ${state.loadError}', textAlign: TextAlign.center),
                ),
        ),
      );
    }
    if (!state.onboarded) return const OnboardingScreen();
    final kidActive = context.select<KidModeController, bool>((k) => k.active);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: kidActive ? const KidShell(key: ValueKey('kid')) : const ParentHome(key: ValueKey('parent')),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('📚', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 12),
        Text('Qorybook', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: QColors.primary)),
        const SizedBox(height: 20),
        const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
      ],
    );
  }
}
