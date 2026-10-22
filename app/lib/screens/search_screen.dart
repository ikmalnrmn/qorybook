import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/labels.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/book_card.dart';
import 'book_list_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  List<Book> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () => _run(value));
  }

  void _run(String value) {
    final state = context.read<AppState>();
    setState(() {
      _query = value.trim();
      _results = state.search(_query);
    });
  }

  void _submit(String value) {
    _run(value);
    context.read<AppState>().settings.addRecentSearch(value);
  }

  void _useSuggestion(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    _submit(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('Cari Buku', style: text.headlineMedium),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onChanged: _onChanged,
                onSubmitted: _submit,
                textInputAction: TextInputAction.search,
                style: text.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Judul, penulis, atau tema…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 26),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            _run('');
                          },
                        ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: QColors.line, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: QColors.primary, width: 2),
                  ),
                ),
              ),
            ),
          ),
          if (_query.isEmpty) ..._suggestions(context, state) else ..._resultSlivers(context),
        ],
      ),
    );
  }

  List<Widget> _resultSlivers(BuildContext context) {
    if (_results.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            emoji: '🔎',
            title: 'Belum ketemu "$_query"',
            message: 'Coba kata lain, misalnya nama hewan atau tokoh cerita.',
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('${_results.length} buku ditemukan', style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
      BookGrid(books: _results),
    ];
  }

  List<Widget> _suggestions(BuildContext context, AppState state) {
    final recent = state.settings.recentSearches;
    final themes = state.catalog?.themes.take(10).toList() ?? const [];
    final text = Theme.of(context).textTheme;
    return [
      if (recent.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                Expanded(child: Text('Pencarian terakhir', style: text.titleMedium)),
                TextButton(
                  onPressed: () async {
                    await state.settings.clearRecentSearches();
                    setState(() {});
                  },
                  child: const Text('Hapus'),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in recent)
                  ActionChip(
                    avatar: const Icon(Icons.history_rounded, size: 18),
                    label: Text(q),
                    onPressed: () => _useSuggestion(q),
                  ),
              ],
            ),
          ),
        ),
      ],
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('Coba cari', style: text.titleMedium),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in state.searchSuggestions) ActionChip(label: Text(q), onPressed: () => _useSuggestion(q)),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('Atau pilih tema', style: text.titleMedium),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in themes)
                ActionChip(
                  avatar: Text(themeEmoji(t.id)),
                  label: Text(themeShortLabel(t.label)),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookListScreen(
                        title: t.label,
                        books: state.filter(theme: t.id),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}
