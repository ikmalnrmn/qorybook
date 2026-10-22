import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/labels.dart';
import '../state/app_state.dart';
import '../widgets/book_card.dart';
import '../widgets/category_tile.dart';
import 'book_list_screen.dart';

/// Semua kategori: jenjang, jenis buku, tema, bahasa.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final catalog = state.catalog;
    final wide = MediaQuery.sizeOf(context).width > 600;
    if (catalog == null) return const SizedBox.shrink();

    int countWhere(bool Function(Book) test) => state.books.where(test).length;

    void open(String title, List<Book> books) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookListScreen(title: title, books: books),
      ),
    );

    final kinds = ['buku', 'komik', 'audio', 'video'].where((k) => countWhere((b) => b.kind == k) > 0).toList();
    final themes = catalog.themes.where((t) => countWhere((b) => b.themes.contains(t.id)) > 0).toList();
    final languages = catalog.languages.where((l) => countWhere((b) => b.language == l.id) > 0).toList();

    Widget grid(List<Widget> children, {double ratio = 1.9, int phone = 2, int tablet = 4}) => SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      sliver: SliverGrid.count(
        crossAxisCount: wide ? tablet : phone,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: ratio,
        children: children,
      ),
    );

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('Jelajah', style: Theme.of(context).textTheme.headlineMedium),
            ),
          ),
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Jenjang', emoji: '🎯'),
          ),
          grid(ratio: wide ? 2.6 : 1.15, phone: 3, tablet: 3, [
            for (final l in levelOrder.where(state.allowedLevels.contains))
              CategoryTile(
                emoji: levelEmoji(l),
                label: levelLabel(l),
                subtitle: '${countWhere((b) => b.levels.contains(l))} buku',
                color: levelColor(l),
                onTap: () => open(levelLabel(l), state.filter(level: l)),
              ),
          ]),
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Jenis Buku', emoji: '📦'),
          ),
          grid([
            for (final k in kinds)
              CategoryTile(
                emoji: kindEmoji(k),
                label: kindLabel(k),
                subtitle: '${countWhere((b) => b.kind == k)} judul',
                color: kindColor(k),
                onTap: () => open(kindLabel(k), state.filter(kind: k)),
              ),
          ]),
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Tema', emoji: '🗺️'),
          ),
          grid(ratio: 2.3, [
            for (final t in themes)
              CategoryTile(
                emoji: themeEmoji(t.id),
                label: themeShortLabel(t.label),
                color: themeColor(t.id),
                compact: true,
                onTap: () => open(t.label, state.filter(theme: t.id)),
              ),
          ]),
          if (languages.length > 1) ...[
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Bahasa', emoji: '🗣️'),
            ),
            grid(ratio: 1.7, phone: 3, tablet: 4, [
              for (final l in languages)
                CategoryTile(
                  emoji: languageEmoji(l.id),
                  label: l.label,
                  color: themeColor('bahasa-${l.id}'),
                  compact: true,
                  onTap: () => open('Bahasa ${l.label}', state.filter(language: l.id)),
                ),
            ]),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
