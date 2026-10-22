import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../models/book.dart';
import '../services/device.dart';
import '../services/pdf_renderer.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/book_card.dart';
import '../widgets/book_cover.dart';
import 'book_detail_screen.dart';

const bookmarkColors = [Color(0xFFFF7A45), Color(0xFFFFC93C), Color(0xFF4CC38A), Color(0xFF4DA8FF), Color(0xFFFF6B8B)];

/// Pembaca PDF: geser halaman, ketuk tepi untuk berpindah, ketuk dua kali
/// untuk memperbesar, penanda halaman, dan tampilan dua halaman di tablet.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book, this.initialPage});

  final Book book;
  final int? initialPage;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with WidgetsBindingObserver {
  late final AppState _state;
  NativePdfDocument? _doc;
  Object? _error;
  PageController? _pager;
  bool? _twoUpMode;
  int _page = 0; // halaman pertama dari bentangan yang sedang tampil
  bool _showUi = true;
  bool _onFinishPage = false;
  late bool _warm;
  late bool _twoPage;
  List<Bookmark> _bookmarks = [];
  DateTime? _sessionStart;
  Timer? _saveTimer;
  Timer? _hideTimer;

  Book get book => widget.book;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _warm = _state.settings.warmLight;
    _twoPage = _state.settings.twoPage;
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    DeviceService.keepScreenOn(true);
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final file = await _state.files.ensureLocal(book);
      final doc = await NativePdfDocument.open(file.path);
      if (!mounted) {
        await doc.close();
        return;
      }
      final saved = _state.progress[book.id];
      final start = widget.initialPage ?? ((saved != null && !saved.finished) ? saved.position : 0);
      _bookmarks = await _state.db.bookmarks(_state.profileId, bookId: book.id);
      setState(() {
        _doc = doc;
        _page = start.clamp(0, doc.pageCount - 1);
      });
      _sessionStart = DateTime.now();
      _scheduleHide();
      unawaited(_state.saveProgress(book.id, position: _page, length: doc.pageCount));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _endSession();
    } else if (state == AppLifecycleState.resumed && _doc != null) {
      _sessionStart ??= DateTime.now();
    }
  }

  void _endSession() {
    final start = _sessionStart;
    _sessionStart = null;
    if (start != null) unawaited(_state.recordSession(book.id, start));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _hideTimer?.cancel();
    final doc = _doc;
    if (doc != null && !_onFinishPage) {
      unawaited(_state.saveProgress(book.id, position: _page, length: doc.pageCount));
    }
    _endSession();
    _pager?.dispose();
    doc?.close();
    DeviceService.keepScreenOn(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ---- bentangan halaman ---------------------------------------------------

  List<List<int>> _spreads(bool twoUp) {
    final n = _doc!.pageCount;
    if (!twoUp || n < 3) {
      return [
        for (var i = 0; i < n; i++) [i],
      ];
    }
    final out = <List<int>>[
      [0],
    ];
    for (var i = 1; i < n; i += 2) {
      out.add([i, if (i + 1 < n) i + 1]);
    }
    return out;
  }

  int _spreadIndexOf(List<List<int>> spreads, int page) {
    final i = spreads.indexWhere((s) => s.contains(page));
    return i < 0 ? 0 : i;
  }

  void _onPageChanged(List<List<int>> spreads, int index) {
    if (index >= spreads.length) {
      _onFinishPage = true;
      unawaited(_state.saveProgress(book.id, position: _doc!.pageCount - 1, length: _doc!.pageCount, finished: true));
      setState(() => _showUi = false);
      return;
    }
    setState(() {
      _onFinishPage = false;
      _page = spreads[index].first;
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      _state.saveProgress(book.id, position: _page, length: _doc!.pageCount);
    });
  }

  void _goTo(int spreadIndex) {
    final pager = _pager;
    if (pager == null || !pager.hasClients) return;
    pager.animateToPage(spreadIndex, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  void _step(int delta) {
    final pager = _pager;
    if (pager == null || !pager.hasClients) return;
    final current = pager.page?.round() ?? 0;
    _goTo(current + delta);
  }

  void _toggleUi() {
    setState(() => _showUi = !_showUi);
    if (_showUi) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showUi = false);
    });
  }

  // ---- penanda -------------------------------------------------------------

  Bookmark? get _currentBookmark {
    for (final b in _bookmarks) {
      if (b.page == _page) return b;
    }
    return null;
  }

  Future<void> _reloadBookmarks() async {
    final list = await _state.db.bookmarks(_state.profileId, bookId: book.id);
    if (mounted) setState(() => _bookmarks = list);
    _state.bookmarksChanged();
  }

  Future<void> _toggleBookmark() async {
    HapticFeedback.lightImpact();
    if (_currentBookmark != null) {
      await _state.db.removeBookmark(_state.profileId, book.id, _page);
    } else {
      await _state.db.addBookmark(_state.profileId, book.id, _page, bookmarkColors.first.toARGB32());
    }
    await _reloadBookmarks();
    _scheduleHide();
  }

  Future<void> _editBookmark() async {
    _hideTimer?.cancel();
    final existing = _currentBookmark;
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    var color = existing?.color ?? bookmarkColors.first.toARGB32();
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tandai halaman ${_page + 1}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final c in bookmarkColors)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkResponse(
                        onTap: () => setSheet(() => color = c.toARGB32()),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == c.toARGB32() ? QColors.ink : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                maxLength: 80,
                decoration: const InputDecoration(hintText: 'Catatan (boleh kosong)'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan Penanda')),
              ),
            ],
          ),
        ),
      ),
    );
    if (save == true) {
      await _state.db.addBookmark(_state.profileId, book.id, _page, color, note: noteCtrl.text.trim());
      await _reloadBookmarks();
    }
    noteCtrl.dispose();
  }

  void _showBookmarks(List<List<int>> spreads) {
    _hideTimer?.cancel();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _bookmarks.isEmpty
          ? const SizedBox(
              height: 220,
              child: EmptyState(emoji: '🔖', title: 'Belum ada penanda', message: 'Ketuk ikon penanda di atas.'),
            )
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final b in _bookmarks)
                  ListTile(
                    leading: Icon(Icons.bookmark_rounded, color: Color(b.color), size: 32),
                    title: Text('Halaman ${b.page + 1}'),
                    subtitle: b.note.isEmpty ? null : Text(b.note),
                    trailing: IconButton(
                      tooltip: 'Hapus penanda',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        await _state.db.removeBookmark(_state.profileId, book.id, b.page);
                        await _reloadBookmarks();
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _goTo(_spreadIndexOf(spreads, b.page));
                    },
                  ),
              ],
            ),
    );
  }

  void _openZoom(int page) {
    final doc = _doc;
    if (doc == null) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, _, _) => _ZoomPage(doc: doc, page: page, warm: _warm),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  // ---- tampilan ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(backgroundColor: const Color(0xFF2B2D42), body: doc == null ? _buildLoading() : _buildReader(doc));
  }

  Widget _buildLoading() {
    final text = Theme.of(context).textTheme;
    if (_error != null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('😿', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                Text('Buku belum bisa dibuka', style: text.titleLarge?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'Periksa koneksi internet lalu coba lagi.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kembali', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 150, child: BookCover(book: book, decodeWidth: 400)),
          const SizedBox(height: 24),
          ValueListenableBuilder<double?>(
            valueListenable: _state.files.progressOf(book.id),
            builder: (context, p, _) => SizedBox(
              width: 200,
              child: Column(
                children: [
                  RoundedProgress(value: (p ?? 0) > 0 ? p! : 0, color: QColors.sun, height: 10),
                  const SizedBox(height: 10),
                  Text(
                    p == null ? 'Membuka buku…' : 'Mengambil buku… ${(p * 100).round()}%',
                    style: text.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReader(NativePdfDocument doc) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final first = doc.pageSizes.first;
        final twoUp = _twoPage && size.width > size.height * 1.1 && first.height > first.width;
        final spreads = _spreads(twoUp);
        if (_twoUpMode != twoUp) {
          final old = _pager;
          _pager = PageController(initialPage: _spreadIndexOf(spreads, _page));
          _twoUpMode = twoUp;
          if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
        }
        final pager = _pager!;
        final spreadIndex = _spreadIndexOf(spreads, _page);
        final bookmarked = _currentBookmark;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final x = d.localPosition.dx / size.width;
                  if (_onFinishPage) return;
                  if (x < 0.22) {
                    _step(-1);
                  } else if (x > 0.78) {
                    _step(1);
                  } else {
                    _toggleUi();
                  }
                },
                onDoubleTapDown: (d) {
                  if (_onFinishPage) return;
                  final pages = spreads[spreadIndex];
                  final page = pages.length == 2 && d.localPosition.dx > size.width / 2 ? pages[1] : pages[0];
                  _openZoom(page);
                },
                onDoubleTap: () {},
                child: PageView.builder(
                  controller: pager,
                  itemCount: spreads.length + 1,
                  onPageChanged: (i) => _onPageChanged(spreads, i),
                  itemBuilder: (context, i) => _PageTurn(
                    controller: pager,
                    index: i,
                    width: size.width,
                    child: i == spreads.length
                        ? _FinishPage(book: book, onRestart: () => _goTo(0))
                        : _SpreadView(doc: doc, pages: spreads[i], warm: _warm),
                  ),
                ),
              ),
            ),
            // Bilah atas
            _Bar(
              visible: _showUi,
              top: true,
              child: Row(
                children: [
                  _RoundIcon(icon: Icons.arrow_back_rounded, tooltip: 'Kembali', onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                  GestureDetector(
                    onLongPress: _editBookmark,
                    child: _RoundIcon(
                      icon: bookmarked != null ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                      color: bookmarked != null ? Color(bookmarked.color) : Colors.white,
                      tooltip: 'Tandai halaman (tekan lama untuk warna & catatan)',
                      onTap: _toggleBookmark,
                    ),
                  ),
                  _RoundIcon(
                    icon: Icons.bookmarks_outlined,
                    tooltip: 'Daftar penanda',
                    onTap: () => _showBookmarks(spreads),
                  ),
                  _RoundIcon(icon: Icons.tune_rounded, tooltip: 'Pengaturan baca', onTap: _showSettings),
                ],
              ),
            ),
            // Bilah bawah
            _Bar(
              visible: _showUi && !_onFinishPage,
              top: false,
              child: Row(
                children: [
                  _RoundIcon(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Halaman sebelumnya',
                    onTap: spreadIndex > 0 ? () => _step(-1) : null,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: QColors.sun,
                            thumbColor: QColors.sun,
                            inactiveTrackColor: Colors.white24,
                            trackHeight: 6,
                          ),
                          child: Slider(
                            min: 0,
                            max: (spreads.length - 1).toDouble().clamp(1.0, double.infinity),
                            value: spreadIndex.toDouble(),
                            onChangeStart: (_) => _hideTimer?.cancel(),
                            onChanged: (v) => pager.jumpToPage(v.round()),
                            onChangeEnd: (_) => _scheduleHide(),
                          ),
                        ),
                        Text(
                          spreads[spreadIndex].length == 2
                              ? 'Halaman ${spreads[spreadIndex][0] + 1}–${spreads[spreadIndex][1] + 1} dari ${doc.pageCount}'
                              : 'Halaman ${_page + 1} dari ${doc.pageCount}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  _RoundIcon(icon: Icons.chevron_right_rounded, tooltip: 'Halaman berikutnya', onTap: () => _step(1)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSettings() {
    _hideTimer?.cancel();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                secondary: const Text('🌙', style: TextStyle(fontSize: 26)),
                title: const Text('Cahaya hangat'),
                subtitle: const Text('Lebih nyaman untuk mata saat malam'),
                value: _warm,
                onChanged: (v) {
                  setState(() => _warm = v);
                  setSheet(() {});
                  _state.settings.warmLight = v;
                },
              ),
              SwitchListTile(
                secondary: const Text('📖', style: TextStyle(fontSize: 26)),
                title: const Text('Dua halaman saat mendatar'),
                subtitle: const Text('Seperti membuka buku sungguhan'),
                value: _twoPage,
                onChanged: (v) {
                  setState(() => _twoPage = v);
                  setSheet(() {});
                  _state.settings.twoPage = v;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Efek membalik: halaman lama tetap di tempat sambil mengecil dan memudar,
/// halaman baru menutupinya dari samping.
class _PageTurn extends StatelessWidget {
  const _PageTurn({required this.controller, required this.index, required this.width, required this.child});

  final PageController controller;
  final int index;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        var delta = 0.0;
        if (controller.hasClients && controller.position.haveDimensions) {
          delta = (controller.page ?? index.toDouble()) - index;
        }
        if (delta <= 0 || delta >= 1) return child!;
        return Transform.translate(
          offset: Offset(delta * width, 0),
          child: Transform.scale(
            scale: 1 - 0.1 * delta,
            child: Opacity(opacity: (1 - delta * 0.7).clamp(0.0, 1.0), child: child),
          ),
        );
      },
    );
  }
}

class _SpreadView extends StatelessWidget {
  const _SpreadView({required this.doc, required this.pages, required this.warm});

  final NativePdfDocument doc;
  final List<int> pages;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: LayoutBuilder(
        builder: (context, c) {
          final slotWidth = c.maxWidth / pages.length;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final p in pages)
                _PdfPage(
                  doc: doc,
                  index: p,
                  box: Size(slotWidth, c.maxHeight),
                  dpr: dpr,
                  warm: warm,
                  alignment: pages.length == 2
                      ? (p == pages.first ? Alignment.centerRight : Alignment.centerLeft)
                      : Alignment.center,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PdfPage extends StatefulWidget {
  const _PdfPage({
    required this.doc,
    required this.index,
    required this.box,
    required this.dpr,
    required this.warm,
    this.alignment = Alignment.center,
    this.quality = 1.25,
  });

  final NativePdfDocument doc;
  final int index;
  final Size box;
  final double dpr;
  final bool warm;
  final Alignment alignment;
  final double quality;

  @override
  State<_PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends State<_PdfPage> {
  Uint8List? _bytes;
  bool _failed = false;
  String? _key;

  Size get _display {
    final page = widget.doc.pageSizes[widget.index];
    final scale = [widget.box.width / page.width, widget.box.height / page.height].reduce((a, b) => a < b ? a : b);
    return Size(page.width * scale, page.height * scale);
  }

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(covariant _PdfPage old) {
    super.didUpdateWidget(old);
    _render();
  }

  void _render() {
    final width = (_display.width * widget.dpr * widget.quality).round();
    final key = '${widget.index}@$width';
    if (key == _key) return;
    _key = key;
    widget.doc
        .render(widget.index, width)
        .then(
          (bytes) {
            if (mounted && _key == key) setState(() => _bytes = bytes);
          },
          onError: (_) {
            if (mounted) setState(() => _failed = true);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final display = _display;
    Widget content;
    if (_bytes != null) {
      content = Image.memory(_bytes!, gaplessPlayback: true, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
      if (widget.warm) {
        content = ColorFiltered(
          colorFilter: const ColorFilter.mode(Color(0xFFFFE2B8), BlendMode.multiply),
          child: content,
        );
      }
    } else if (_failed) {
      content = const Center(child: Text('Halaman ini gagal ditampilkan 😕'));
    } else {
      content = const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)));
    }
    return SizedBox(
      width: widget.box.width,
      height: widget.box.height,
      child: Align(
        alignment: widget.alignment,
        child: Container(
          width: display.width,
          height: display.height,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Satu halaman diperbesar, bisa dicubit dan digeser.
class _ZoomPage extends StatelessWidget {
  const _ZoomPage({required this.doc, required this.page, required this.warm});

  final NativePdfDocument doc;
  final int page;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: const Color(0xF0101018),
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: _PdfPage(
                  doc: doc,
                  index: page,
                  box: size,
                  dpr: MediaQuery.devicePixelRatioOf(context),
                  warm: warm,
                  quality: 2.2,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _RoundIcon(icon: Icons.close_rounded, tooltip: 'Tutup', onTap: () => Navigator.pop(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishPage extends StatefulWidget {
  const _FinishPage({required this.book, required this.onRestart});

  final Book book;
  final VoidCallback onRestart;

  @override
  State<_FinishPage> createState() => _FinishPageState();
}

class _FinishPageState extends State<_FinishPage> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final related = context.read<AppState>().related(widget.book, limit: 6);
    return Container(
      color: QColors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(parent: _anim, curve: Curves.elasticOut),
                  child: const Text('🏆', style: TextStyle(fontSize: 96)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _anim,
                          curve: Interval(0.3 + i * 0.2, 1, curve: Curves.elasticOut),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('⭐', style: TextStyle(fontSize: 40)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Hebat! Kamu selesai membaca', textAlign: TextAlign.center, style: text.titleLarge),
                const SizedBox(height: 4),
                Text(
                  widget.book.title,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(color: QColors.primary),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onRestart,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Baca dari awal'),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Selesai'),
                    ),
                  ],
                ),
                if (related.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text('Baca buku lainnya', style: text.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final b in related)
                        SizedBox(
                          width: 96,
                          child: GestureDetector(
                            onTap: () => Navigator.of(
                              context,
                            ).pushReplacement(MaterialPageRoute<void>(builder: (_) => BookDetailScreen(bookId: b.id))),
                            child: BookCover(book: b, radius: 12, decodeWidth: 240),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.visible, required this.top, required this.child});

  final bool visible;
  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          offset: visible ? Offset.zero : Offset(0, top ? -1 : 1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: visible ? 1 : 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                  end: top ? Alignment.bottomCenter : Alignment.topCenter,
                  colors: const [Color(0xDD1B1C2B), Color(0x001B1C2B)],
                ),
              ),
              child: SafeArea(
                top: top,
                bottom: !top,
                child: Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 12), child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.tooltip, this.onTap, this.color = Colors.white});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: 30,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        minimumSize: const Size(52, 52),
      ),
      icon: Icon(icon, color: onTap == null ? Colors.white38 : color),
    );
  }
}
