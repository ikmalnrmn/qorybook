import 'dart:async';

import 'package:flutter/material.dart';
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

  Book get book => widget.book;
  bool get isVideo => book.format == BookFormat.video;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    WidgetsBinding.instance.addObserver(this);
    DeviceService.keepScreenOn(true);
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
    if (!_finishedSaved) _save();
    _endSession();
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    DeviceService.keepScreenOn(false);
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
  }

  void _skip(int seconds) {
    final c = _ctrl;
    if (c == null) return;
    final target = c.value.position + Duration(seconds: seconds);
    c.seekTo(target < Duration.zero ? Duration.zero : target);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
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
}
