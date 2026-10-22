import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/parent_auth.dart';
import '../state/app_state.dart';
import '../state/kid_mode.dart';
import '../theme.dart';
import '../widgets/disclaimer.dart';
import '../widgets/kid_mode_checklist.dart';
import '../widgets/pin_pad.dart';
import '../widgets/profile_form.dart';

/// Pengaturan awal oleh orang tua: PIN, profil anak, dan izin Mode Anak.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _step = 0;
  String? _firstPin;
  String? _pinMessage;
  var _profile = (name: '', avatar: 'fox', levels: <String>{'paud', 'sd_awal'});

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    setState(() => _step++);
    _pages.animateToPage(_step, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void _back() {
    if (_step == 0) return;
    setState(() {
      _step--;
      _firstPin = null;
      _pinMessage = null;
    });
    _pages.animateToPage(_step, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  Future<bool> _onPin(String pin) async {
    if (_firstPin == null) {
      setState(() {
        _firstPin = pin;
        _pinMessage = null;
      });
      return true;
    }
    if (pin != _firstPin) {
      setState(() {
        _firstPin = null;
        _pinMessage = 'PIN tidak sama. Ulangi dari awal.';
      });
      return false;
    }
    await context.read<ParentAuth>().setPin(pin);
    _next();
    return true;
  }

  Future<void> _saveProfile() async {
    final state = context.read<AppState>();
    final existing = state.profiles.firstOrNull;
    if (existing != null) {
      await state.updateProfile(
        existing.copyWith(name: _profile.name, avatar: _profile.avatar, levels: _profile.levels),
      );
      await state.switchProfile(existing.id);
    } else {
      final id = await state.addProfile(_profile.name, _profile.avatar, _profile.levels);
      await state.switchProfile(id);
    }
    _next();
  }

  Future<void> _finish() async {
    final state = context.read<AppState>();
    final kid = context.read<KidModeController>();
    await state.finishOnboarding();
    await kid.enter();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _back(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Kembali',
                      onPressed: _step == 0 ? null : _back,
                      icon: Icon(Icons.arrow_back_rounded, color: _step == 0 ? Colors.transparent : QColors.ink),
                    ),
                    const Spacer(),
                    for (var i = 0; i < 4; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(left: 6),
                        width: i == _step ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i <= _step ? QColors.primary : QColors.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_welcome(), _pinStep(), _profileStep(), _kidModeStep()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepScaffold({
    required String emoji,
    required String title,
    required String subtitle,
    required Widget body,
    Widget? bottom,
  }) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 56)),
                    const SizedBox(height: 8),
                    Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: QColors.inkSoft),
                    ),
                    const SizedBox(height: 20),
                    body,
                  ],
                ),
              ),
            ),
          ),
        ),
        if (bottom != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SizedBox(width: double.infinity, child: bottom),
            ),
          ),
      ],
    );
  }

  Widget _welcome() {
    final text = Theme.of(context).textTheme;
    Widget point(String emoji, String title, String desc) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(desc, style: text.bodySmall?.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
    return _stepScaffold(
      emoji: '📚',
      title: 'Selamat datang di Qorybook',
      subtitle: 'Cara mudah dan menyenangkan membaca buku anak resmi dari pemerintah, dengan pengawasan orang tua.',
      body: Column(
        children: [
          point('🏛️', 'Buku resmi & gratis', 'Lebih dari 1.400 buku bacaan PAUD–SD dari SIBI dan BUDI.'),
          point('📌', 'Anak tetap di aplikasi', 'Layar disematkan; keluar hanya dengan PIN orang tua atau kunci HP.'),
          point('🔕', 'Tanpa gangguan', 'Notifikasi disenyapkan selama anak membaca.'),
          point('👧', 'Profil tiap anak', 'Jenjang buku, progres, dan rak buku masing-masing.'),
          const SizedBox(height: 6),
          const DisclaimerCard(),
        ],
      ),
      bottom: FilledButton(onPressed: _next, child: const Text('Atur sekarang')),
    );
  }

  Widget _pinStep() {
    final confirming = _firstPin != null;
    return _stepScaffold(
      emoji: '🔑',
      title: confirming ? 'Ulangi PIN' : 'Buat PIN orang tua',
      subtitle: confirming
          ? 'Masukkan PIN yang sama sekali lagi.'
          : 'PIN 4 angka ini dipakai untuk keluar dari Mode Anak dan membuka pengaturan. Jangan beri tahu anak.',
      body: Column(
        children: [
          SizedBox(
            height: 20,
            child: Text(
              _pinMessage ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFFE5484D)),
            ),
          ),
          const SizedBox(height: 8),
          PinPad(key: ValueKey(confirming), onCompleted: _onPin),
        ],
      ),
    );
  }

  Widget _profileStep() {
    final valid = _profile.name.isNotEmpty && _profile.levels.isNotEmpty;
    return _stepScaffold(
      emoji: '👧',
      title: 'Siapa yang akan membaca?',
      subtitle: 'Profil anak lain bisa ditambahkan nanti di Area Orang Tua.',
      body: ProfileForm(initial: _profile, onChanged: (v) => setState(() => _profile = v)),
      bottom: FilledButton(onPressed: valid ? _saveProfile : null, child: const Text('Lanjut')),
    );
  }

  Widget _kidModeStep() {
    return _stepScaffold(
      emoji: '🛡️',
      title: 'Siapkan Mode Anak',
      subtitle: 'Lengkapi langkah di bawah agar anak tidak bisa keluar dari aplikasi dan tidak terganggu notifikasi.',
      body: const KidModeChecklist(),
      bottom: FilledButton.icon(
        onPressed: _finish,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Mulai Mode Anak'),
      ),
    );
  }
}
