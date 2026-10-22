import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../screens/book_detail_screen.dart';
import '../services/labels.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'book_cover.dart';

void openBook(BuildContext context, Book book, {Object? heroTag}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BookDetailScreen(bookId: book.id, heroTag: heroTag),
    ),
  );
}

/// Kartu buku untuk grid dan baris horizontal.
class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book, this.width, this.showMeta = true});

  final Book book;
  final double? width;
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    final progress = context.select<AppState, double?>((s) {
      final p = s.progress[book.id];
      if (p == null || p.position == 0) return null;
      return p.finished ? 1 : p.fraction;
    });
    final text = Theme.of(context).textTheme;
    // Buku yang sama bisa tampil di beberapa baris; tag Hero harus unik per kartu.
    final heroTag = 'cover-${book.id}-${identityHashCode(this)}';
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openBook(context, book, heroTag: heroTag),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: heroTag,
              child: DecoratedBox(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: softShadow),
                child: BookCover(book: book),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              RoundedProgress(value: progress, color: progress >= 1 ? QColors.leaf : QColors.primary, height: 5),
            ],
            const SizedBox(height: 8),
            Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
            if (showMeta) ...[
              const SizedBox(height: 2),
              Text(
                book.levels.map(levelLabel).first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Judul bagian + tombol "Lihat semua".
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.emoji, this.onMore});

  final String title;
  final String? emoji;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          if (emoji != null) ...[Text(emoji!, style: const TextStyle(fontSize: 22)), const SizedBox(width: 8)],
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (onMore != null) TextButton(onPressed: onMore, child: const Text('Lihat semua')),
        ],
      ),
    );
  }
}

/// Baris buku yang bisa digeser ke samping.
class BookRow extends StatelessWidget {
  const BookRow({super.key, required this.books, this.cardWidth = 128});

  final List<Book> books;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final height = cardWidth * 4 / 3 + 72;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) => BookCard(book: books[i], width: cardWidth),
      ),
    );
  }
}

/// Grid buku yang menyesuaikan lebar layar (HP / tablet).
class BookGrid extends StatelessWidget {
  const BookGrid({super.key, required this.books, this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 32)});

  final List<Book> books;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 170,
          mainAxisSpacing: 18,
          crossAxisSpacing: 14,
          childAspectRatio: 0.52,
        ),
        itemCount: books.length,
        itemBuilder: (context, i) => BookCard(book: books[i]),
      ),
    );
  }
}

/// Tampilan kosong yang ramah.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.title, this.message, this.action});

  final String emoji;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: text.titleLarge),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: QColors.inkSoft),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
