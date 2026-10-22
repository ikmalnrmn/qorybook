import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/labels.dart';
import '../widgets/book_card.dart';

enum BookSort { popular, title, none }

/// Daftar buku dalam satu kategori, dengan urutan & filter jenis.
class BookListScreen extends StatefulWidget {
  const BookListScreen({super.key, required this.title, required this.books, this.initialSort = BookSort.popular});

  final String title;
  final List<Book> books;
  final BookSort initialSort;

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  late BookSort _sort = widget.initialSort;
  String? _kind;
  String? _level;

  List<Book> get _visible {
    final list = widget.books
        .where((b) => (_kind == null || b.kind == _kind) && (_level == null || b.levels.contains(_level)))
        .toList();
    switch (_sort) {
      case BookSort.popular:
        list.sort((a, b) => b.views.compareTo(a.views));
      case BookSort.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case BookSort.none:
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final kinds = {for (final b in widget.books) b.kind}.toList()..sort();
    final levels = levelOrder.where((l) => widget.books.any((b) => b.levels.contains(l))).toList();
    final books = _visible;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: Text(widget.title),
            actions: [
              PopupMenuButton<BookSort>(
                tooltip: 'Urutkan',
                icon: const Icon(Icons.sort_rounded),
                initialValue: _sort,
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: BookSort.popular, child: Text('Paling populer')),
                  PopupMenuItem(value: BookSort.title, child: Text('Judul A–Z')),
                ],
              ),
            ],
          ),
          if (kinds.length > 1 || levels.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (levels.length > 1)
                      for (final l in levels)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('${levelEmoji(l)} ${levelLabel(l)}'),
                            selected: _level == l,
                            onSelected: (v) => setState(() => _level = v ? l : null),
                          ),
                        ),
                    if (kinds.length > 1)
                      for (final k in kinds)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('${kindEmoji(k)} ${kindLabel(k)}'),
                            selected: _kind == k,
                            onSelected: (v) => setState(() => _kind = v ? k : null),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text('${books.length} buku', style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          if (books.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(emoji: '🫥', title: 'Belum ada buku di sini'),
            )
          else
            BookGrid(books: books),
        ],
      ),
    );
  }
}
