import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/labels.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/book_card.dart';
import '../widgets/book_cover.dart';
import 'media_player_screen.dart';
import 'reader_screen.dart';

class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.bookId, this.heroTag});

  final String bookId;

  /// Tag Hero dari kartu yang diketuk, supaya sampul beranimasi mulus.
  final Object? heroTag;

  void _open(BuildContext context, Book book, {int? page}) {
    final route = book.format == BookFormat.pdf
        ? MaterialPageRoute<void>(
            builder: (_) => ReaderScreen(book: book, initialPage: page),
          )
        : MaterialPageRoute<void>(builder: (_) => MediaPlayerScreen(book: book));
    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final book = state.bookById(bookId);
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(emoji: '🙈', title: 'Buku tidak tersedia'),
      );
    }
    final text = Theme.of(context).textTheme;
    final progress = state.progress[book.id];
    final fav = state.isFavorite(book.id);
    final related = state.related(book);
    final wide = MediaQuery.sizeOf(context).width > 600;
    final started = progress != null && progress.position > 0 && !progress.finished;

    final actionLabel = switch (book.format) {
      BookFormat.pdf =>
        started
            ? 'Lanjut Baca'
            : (progress?.finished ?? false)
            ? 'Baca Lagi'
            : 'Baca Sekarang',
      BookFormat.audio => started ? 'Lanjut Dengar' : 'Dengarkan',
      BookFormat.video => started ? 'Lanjut Tonton' : 'Tonton',
    };
    final actionIcon = switch (book.format) {
      BookFormat.pdf => Icons.menu_book_rounded,
      BookFormat.audio => Icons.headphones_rounded,
      BookFormat.video => Icons.play_circle_fill_rounded,
    };

    final cover = Hero(
      tag: heroTag ?? 'cover-${book.id}',
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: softShadow),
        child: BookCover(book: book, radius: 20, decodeWidth: 600),
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(book.title, style: text.headlineSmall),
        if (book.authors.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Penulis: ${book.authors}', style: text.bodyMedium?.copyWith(color: QColors.inkSoft)),
        ],
        if (book.illustrators.isNotEmpty)
          Text('Ilustrator: ${book.illustrators}', style: text.bodyMedium?.copyWith(color: QColors.inkSoft)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final l in book.levels) _Pill('${levelEmoji(l)} ${levelLabel(l)}', levelColor(l)),
            if (book.readingLevel != null)
              _Pill('Jenjang ${book.readingLevel} · ${book.readingLevelLabel}', QColors.grape),
            _Pill('${kindEmoji(book.kind)} ${kindLabel(book.kind)}', kindColor(book.kind)),
            for (final t in book.themes) _Pill('${themeEmoji(t)} ${themeShortLabel(t)}', themeColor(t)),
            if (book.pages != null) _Pill('📄 ${book.pages} halaman', QColors.inkSoft),
            if (book.language != 'Indonesia') _Pill('${languageEmoji(book.language)} ${book.language}', QColors.sky),
            if (book.views > 0) _Pill('👀 ${formatCount(book.views)} kali dibaca', QColors.primary),
          ],
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: fav ? 'Hapus dari favorit' : 'Tambah ke favorit',
            onPressed: () => state.toggleFavorite(book.id),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(
                fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(fav),
                color: fav ? const Color(0xFFFF4D6D) : QColors.ink,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 240, child: cover),
                      const SizedBox(width: 24),
                      Expanded(child: info),
                    ],
                  )
                else ...[
                  Center(child: SizedBox(width: 210, child: cover)),
                  const SizedBox(height: 20),
                  info,
                ],
                const SizedBox(height: 20),
                if (started) ...[
                  RoundedProgress(value: progress.fraction, height: 8),
                  const SizedBox(height: 6),
                  Text('${(progress.fraction * 100).round()}% selesai', style: text.bodySmall),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _open(context, book, page: started ? progress.position : 0),
                        icon: Icon(actionIcon, size: 26),
                        label: Text(actionLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _OfflineButton(book: book),
                  ],
                ),
                if (book.synopsis.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Cerita singkat', style: text.titleMedium),
                  const SizedBox(height: 6),
                  Text(book.synopsis, style: text.bodyLarge),
                ],
                const SizedBox(height: 24),
                _SourceCard(book: book),
              ],
            ),
          ),
          if (related.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader(title: 'Buku serupa', emoji: '🌈'),
            BookRow(books: related),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Color.lerp(color, Colors.black, 0.35)),
      ),
    );
  }
}

/// Tombol simpan offline dengan indikator unduhan.
class _OfflineButton extends StatefulWidget {
  const _OfflineButton({required this.book});

  final Book book;

  @override
  State<_OfflineButton> createState() => _OfflineButtonState();
}

class _OfflineButtonState extends State<_OfflineButton> {
  bool? _pinned;

  @override
  void initState() {
    super.initState();
    context.read<AppState>().files.isPinned(widget.book).then((v) {
      if (mounted) setState(() => _pinned = v);
    });
  }

  Future<void> _toggle() async {
    final files = context.read<AppState>().files;
    final messenger = ScaffoldMessenger.of(context);
    final target = !(_pinned ?? false);
    try {
      await files.setPinned(widget.book, target);
      if (!mounted) return;
      setState(() => _pinned = target);
      messenger.showSnackBar(
        SnackBar(content: Text(target ? 'Tersimpan! Buku bisa dibaca tanpa internet.' : 'Simpanan offline dihapus.')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Gagal mengunduh. Periksa koneksi internet.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = context.read<AppState>().files;
    return ValueListenableBuilder<double?>(
      valueListenable: files.progressOf(widget.book.id),
      builder: (context, progress, _) {
        final pinned = _pinned ?? false;
        return SizedBox(
          width: 56,
          height: 56,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: progress != null || _pinned == null ? null : _toggle,
            child: progress != null
                ? SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(value: progress > 0 ? progress : null, strokeWidth: 3),
                  )
                : Icon(
                    pinned ? Icons.download_done_rounded : Icons.download_rounded,
                    color: pinned ? QColors.leaf : QColors.ink,
                    size: 26,
                  ),
          ),
        );
      },
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: QColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: QColors.line, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏛️', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Buku gratis dari ${book.sourceName}', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  [
                    if (book.publisher.isNotEmpty) 'Penerbit: ${book.publisher}',
                    if (book.isbn.isNotEmpty) 'ISBN ${book.isbn}',
                    book.pageUrl,
                  ].join('\n'),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
