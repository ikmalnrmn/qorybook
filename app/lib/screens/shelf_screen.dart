import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../models/book.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/book_card.dart';
import '../widgets/book_cover.dart';
import 'reader_screen.dart';

/// Rak pribadi: favorit, sedang dibaca, selesai, penanda halaman.
class ShelfScreen extends StatelessWidget {
  const ShelfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return DefaultTabController(
      length: 4,
      child: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('Rak Bukuku', style: Theme.of(context).textTheme.headlineMedium),
              ),
            ),
            SliverToBoxAdapter(
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                labelStyle: Theme.of(context).textTheme.titleSmall,
                indicatorColor: QColors.primary,
                labelColor: QColors.ink,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: '❤️ Favorit (${state.favorites.length})'),
                  Tab(text: '📖 Sedang Dibaca (${state.continueReading.length})'),
                  Tab(text: '🏆 Selesai (${state.finishedBooks.length})'),
                  const Tab(text: '🔖 Penanda'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _ShelfGrid(
                books: state.favorites,
                empty: const EmptyState(
                  emoji: '❤️',
                  title: 'Belum ada favorit',
                  message: 'Ketuk tombol hati di halaman buku untuk menyimpannya di sini.',
                ),
              ),
              _ShelfGrid(
                books: state.continueReading,
                empty: const EmptyState(emoji: '📖', title: 'Belum ada buku yang sedang dibaca'),
              ),
              _ShelfGrid(
                books: state.finishedBooks,
                empty: const EmptyState(
                  emoji: '🏆',
                  title: 'Belum ada buku yang selesai',
                  message: 'Selesaikan satu buku dan dapatkan bintang!',
                ),
              ),
              const _BookmarksTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfGrid extends StatelessWidget {
  const _ShelfGrid({required this.books, required this.empty});

  final List<Book> books;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return empty;
    return CustomScrollView(
      slivers: [BookGrid(books: books, padding: const EdgeInsets.fromLTRB(20, 16, 20, 32))],
    );
  }
}

class _BookmarksTab extends StatelessWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return FutureBuilder<List<Bookmark>>(
      key: ValueKey(state.bookmarksVersion),
      future: state.db.bookmarks(state.profileId),
      builder: (context, snap) {
        final marks = (snap.data ?? const <Bookmark>[]).where((m) => state.bookById(m.bookId) != null).toList();
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (marks.isEmpty) {
          return const EmptyState(
            emoji: '🔖',
            title: 'Belum ada penanda',
            message: 'Saat membaca, ketuk ikon penanda untuk menandai halaman favoritmu.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          itemCount: marks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final m = marks[i];
            final book = state.bookById(m.bookId)!;
            return Material(
              color: QColors.surface,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(book: book, initialPage: m.page),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      SizedBox(width: 56, child: BookCover(book: book, radius: 10, decodeWidth: 160)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Halaman ${m.page + 1}${m.note.isEmpty ? '' : ' · ${m.note}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.bookmark_rounded, color: Color(m.color), size: 30),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
