import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../config.dart';
import '../models/book.dart';
import '../services/device.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/book_cover.dart';

/// Pemutar buku audio dan buku video dari BUDI.
class MediaPlayerScreen extends StatefulWidget {
  const MediaPlayerScreen({super.key, required this.book});

  final Book book;

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> with WidgetsBindingObserver {
  late final AppState _state;
  VideoPlayerController? _ctrl;
  Object? _error;
  DateTime? _sessionStart;
  Timer? _saveTimer;
  bool _finishedSaved = false;
  bool _controlsVisible = true;
  bool _locked = false;
  Timer? _hideTimer;

  Book get book => widget.book;
  bool get isVideo => book.format == BookFormat.video;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    WidgetsBinding.instance.addObserver(this);
    DeviceService.keepScreenOn(true);
    if (isVideo) SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _init();
  }

  Future<void> _init() async {
    setState(() => _error = null);
    try {
      final local = await _state.files.localFile(book);
      final ctrl = local != null
          ? VideoPlayerController.file(local)
          : VideoPlayerController.networkUrl(
              Uri.parse(book.media),
              httpHeaders: const {'User-Agent': AppConfig.userAgent},
            );
      await ctrl.initialize();
      final saved = _state.progress[book.id];
      if (saved != null && !saved.finished && saved.position > 0) {
        await ctrl.seekTo(Duration(milliseconds: saved.position));
      }
      ctrl.addListener(_onTick);
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() => _ctrl = ctrl);
      await ctrl.play();
      _sessionStart = DateTime.now();
      _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _save());
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _onTick() {
    final v = _ctrl?.value;
    if (v == null || !v.isInitialized) return;
    final done = v.duration > Duration.zero && v.position >= v.duration - const Duration(milliseconds: 500);
    if (done && !_finishedSaved) {
      _finishedSaved = true;
      _save(finished: true);
    }
    setState(() {});
  }

  void _save({bool finished = false}) {
    final v = _ctrl?.value;
    if (v == null || !v.isInitialized || v.duration == Duration.zero) return;
    _state.saveProgress(
      book.id,
      position: finished ? 0 : v.position.inMilliseconds,
      length: v.duration.inMilliseconds,
      finished: finished,
    );
  }

  void _endSession() {
    final start = _sessionStart;
    _sessionStart = null;
    if (start != null) unawaited(_state.recordSession(book.id, start));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _ctrl?.pause();
      _save();
      _endSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _hideTimer?.cancel();
    if (!_finishedSaved) _save();
    _endSession();
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    DeviceService.keepScreenOn(false);
    if (isVideo) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _togglePlay() {
    final c = _ctrl;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
      _sessionStart ??= DateTime.now();
    }
    _showControls();
  }

  /// Tombol muncul saat layar disentuh dan hilang sendiri setelah 3 detik
  /// (selama video berjalan atau saat terkunci).
  void _showControls() {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_locked || (_ctrl?.value.isPlaying ?? false)) setState(() => _controlsVisible = false);
    });
  }

  void _onScreenTap() {
    if (_controlsVisible && !_locked) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _lock() {
    _hideTimer?.cancel();
    setState(() {
      _locked = true;
      _controlsVisible = false;
    });
  }

  void _unlock() {
    HapticFeedback.mediumImpact();
    setState(() => _locked = false);
    _showControls();
  }

  void _skip(int seconds) {
    final c = _ctrl;
    if (c == null) return;
    final target = c.value.position + Duration(seconds: seconds);
    c.seekTo(target < Duration.zero ? Duration.zero : target);
    if (isVideo) _showControls();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (isVideo) return _buildVideo(context);
    final text = Theme.of(context).textTheme;
    final c = _ctrl;
    final dark = isVideo;
    final fg = dark ? Colors.white : QColors.ink;

    Widget media;
    if (_error != null) {
      media = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😿', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 8),
          Text('Belum bisa diputar. Periksa koneksi internet.', style: text.bodyLarge?.copyWith(color: fg)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _init, child: const Text('Coba Lagi')),
        ],
      );
    } else if (c == null) {
      media = const CircularProgressIndicator();
    } else if (isVideo) {
      media = AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
        child: GestureDetector(onTap: _togglePlay, child: VideoPlayer(c)),
      );
    } else {
      media = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: AnimatedScale(
          scale: c.value.isPlaying ? 1 : 0.92,
          duration: const Duration(milliseconds: 300),
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: softShadow),
            child: BookCover(book: book, radius: 24, decodeWidth: 600),
          ),
        ),
      );
    }

    final v = c?.value;
    final ready = v != null && v.isInitialized;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF15151F) : QColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: fg,
        title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(padding: const EdgeInsets.all(20), child: media),
              ),
            ),
            if (ready)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(trackHeight: 6),
                      child: Slider(
                        min: 0,
                        max: v.duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                        value: v.position.inMilliseconds.clamp(0, v.duration.inMilliseconds).toDouble(),
                        onChanged: (x) => c!.seekTo(Duration(milliseconds: x.round())),
                      ),
                    ),
                    Row(
                      children: [
                        Text(_fmt(v.position), style: text.labelMedium?.copyWith(color: fg)),
                        const Spacer(),
                        Text(_fmt(v.duration), style: text.labelMedium?.copyWith(color: fg)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Mundur 10 detik',
                          iconSize: 40,
                          color: fg,
                          onPressed: () => _skip(-10),
                          icon: const Icon(Icons.replay_10_rounded),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: FilledButton(
                            style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                            onPressed: _togglePlay,
                            child: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 52),
                          ),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          tooltip: 'Maju 10 detik',
                          iconSize: 40,
                          color: fg,
                          onPressed: () => _skip(10),
                          icon: const Icon(Icons.forward_10_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Video memenuhi layar; tombol muncul saat disentuh; mode kunci mengabaikan sentuhan.
  Widget _buildVideo(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = _ctrl;
    final v = c?.value;
    final ready = v != null && v.isInitialized && v.size.width > 0;
    const fg = Colors.white;

    Widget picture;
    if (_error != null) {
      picture = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😿', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text('Belum bisa diputar. Periksa koneksi internet.', style: text.bodyLarge?.copyWith(color: fg)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _init, child: const Text('Coba Lagi')),
        ],
      );
    } else if (!ready) {
      picture = const CircularProgressIndicator();
    } else {
      picture = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(width: v.size.width, height: v.size.height, child: VideoPlayer(c!)),
        ),
      );
    }

    final showBar = _controlsVisible && !_locked;

    return PopScope(
      canPop: !_locked,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: ready ? _onScreenTap : null,
              child: Center(child: picture),
            ),
            if (ready && c != null) ...[
              IgnorePointer(
                ignoring: !showBar,
                child: AnimatedOpacity(
                  opacity: showBar ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: _VideoControls(
                    title: book.title,
                    position: v.position,
                    duration: v.duration,
                    playing: v.isPlaying,
                    fmt: _fmt,
                    onBack: () => Navigator.of(context).maybePop(),
                    onLock: _lock,
                    onToggle: _togglePlay,
                    onSkip: _skip,
                    onSeek: (ms) {
                      c.seekTo(Duration(milliseconds: ms));
                      _showControls();
                    },
                  ),
                ),
              ),
              if (_locked)
                IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: SafeArea(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: GestureDetector(
                            onLongPress: _unlock,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock_rounded, color: fg),
                                  const SizedBox(width: 10),
                                  Text('Terkunci · tahan untuk membuka', style: text.labelLarge?.copyWith(color: fg)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ] else
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    color: fg,
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.title,
    required this.position,
    required this.duration,
    required this.playing,
    required this.fmt,
    required this.onBack,
    required this.onLock,
    required this.onToggle,
    required this.onSkip,
    required this.onSeek,
  });

  final String title;
  final Duration position;
  final Duration duration;
  final bool playing;
  final String Function(Duration) fmt;
  final VoidCallback onBack;
  final VoidCallback onLock;
  final VoidCallback onToggle;
  final void Function(int seconds) onSkip;
  final void Function(int ms) onSeek;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const fg = Colors.white;
    final maxMs = duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    return SafeArea(
      child: Stack(
        children: [
          // Sapuan gelap tipis di atas dan bawah supaya tombol terbaca di atas gambar apa pun.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black54],
                  stops: [0, 0.25, 0.65, 1],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Row(
              children: [
                IconButton(color: fg, tooltip: 'Kembali', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
                Expanded(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium?.copyWith(color: fg)),
                ),
                IconButton(color: fg, tooltip: 'Kunci layar', onPressed: onLock, icon: const Icon(Icons.lock_open_rounded)),
              ],
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Mundur 10 detik',
                  iconSize: 40,
                  color: fg,
                  onPressed: () => onSkip(-10),
                  icon: const Icon(Icons.replay_10_rounded),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 68,
                  height: 68,
                  child: FilledButton(
                    style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                    onPressed: onToggle,
                    child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 44),
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  tooltip: 'Maju 10 detik',
                  iconSize: 40,
                  color: fg,
                  onPressed: () => onSkip(10),
                  icon: const Icon(Icons.forward_10_rounded),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Text(fmt(position), style: text.labelMedium?.copyWith(color: fg)),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: maxMs,
                      value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                      onChanged: (x) => onSeek(x.round()),
                    ),
                  ),
                  Text(fmt(duration), style: text.labelMedium?.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
