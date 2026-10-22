import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/labels.dart';
import '../state/app_state.dart';
import '../state/kid_mode.dart';
import '../theme.dart';
import '../widgets/book_card.dart';
import '../widgets/book_cover.dart';
import '../widgets/category_tile.dart';
import '../widgets/hold_button.dart';
import 'book_list_screen.dart';
import 'kid_shell.dart';
import 'parent/parent_gate.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openParentArea(BuildContext context) async {
    final kid = context.read<KidModeController>();
    final nav = Navigator.of(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (await ParentGate.show(context)) {
      nav.popUntil((r) => r.isFirst);
      await kid.exit();
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.activeProfile;
    final text = Theme.of(context).textTheme;
    final continueReading = state.continueReading;
    final frequent = state.frequentAtHome;
    final popular = state.popular;
    final themes = state.catalog?.themes.where((t) => t.count >= 3).take(8).toList() ?? const [];

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => state.refreshCatalog(force: true),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    if (profile != null) ...[
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: profile.color.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: Text(profile.emoji, style: const TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile == null ? '${_greeting()}! 👋' : '${_greeting()}, ${profile.name}! 👋',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyLarge?.copyWith(color: QColors.inkSoft),
                          ),
                          Text('Mau baca apa hari ini?', style: text.headlineMedium),
                        ],
                      ),
                    ),
                    HoldButton(
                      onHeld: () => _openParentArea(context),
                      child: const Icon(Icons.lock_rounded, color: QColors.inkSoft, size: 24),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: _SearchPill(onTap: () => KidShell.goToTab(context, 2)),
              ),
            ),
            if (state.curatedButEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  emoji: '📦',
                  title: 'Rak bukumu masih kosong',
                  message: 'Minta ayah atau ibu memilihkan buku untukmu di Area Orang Tua.',
                ),
              ),
            if (continueReading.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: SectionHeader(title: 'Lanjutkan Membaca', emoji: '🔖'),
              ),
              SliverToBoxAdapter(child: _ContinueRow(books: continueReading)),
            ],
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Pilih Jenjang', emoji: '🎯'),
            ),
            SliverToBoxAdapter(child: _LevelRow(levels: levelOrder.where(state.allowedLevels.contains).toList())),
            if (popular.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Populer di Indonesia',
                  emoji: '🔥',
                  onMore: () => _openList(context, 'Populer di Indonesia', popular, sort: BookSort.popular),
                ),
              ),
              SliverToBoxAdapter(child: BookRow(books: popular.take(15).toList())),
            ],
            if (frequent.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Sering Dibaca di Rumah',
                  emoji: '🏡',
                  onMore: () => _openList(context, 'Sering Dibaca di Rumah', frequent, sort: BookSort.none),
                ),
              ),
              SliverToBoxAdapter(child: BookRow(books: frequent.take(15).toList())),
            ],
            if (themes.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(title: 'Jelajahi Tema', emoji: '🗺️', onMore: () => KidShell.goToTab(context, 1)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.3,
                  children: [
                    for (final t in themes)
                      CategoryTile(
                        emoji: themeEmoji(t.id),
                        label: themeShortLabel(t.label),
                        color: themeColor(t.id),
                        compact: true,
                        onTap: () => _openList(context, t.label, state.filter(theme: t.id)),
                      ),
                  ],
                ),
              ),
            ],
            for (final kind in const ['komik', 'audio', 'video']) ..._kindSection(context, state, kind),
            if (state.newest.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Baru Ditambahkan',
                  emoji: '✨',
                  onMore: () => _openList(context, 'Baru Ditambahkan', state.newest, sort: BookSort.none),
                ),
              ),
              SliverToBoxAdapter(child: BookRow(books: state.newest.take(15).toList())),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  List<Widget> _kindSection(BuildContext context, AppState state, String kind) {
    final books = state.filter(kind: kind)..sort((a, b) => b.views.compareTo(a.views));
    if (books.length < 3) return const [];
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: kindLabel(kind),
          emoji: kindEmoji(kind),
          onMore: () => _openList(context, kindLabel(kind), books),
        ),
      ),
      SliverToBoxAdapter(child: BookRow(books: books.take(15).toList())),
    ];
  }

  void _openList(BuildContext context, String title, List<Book> books, {BookSort sort = BookSort.popular}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookListScreen(title: title, books: books, initialSort: sort),
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: QColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: QColors.line, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: QColors.inkSoft, size: 26),
              const SizedBox(width: 10),
              Text(
                'Cari judul, tokoh, atau tema…',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: QColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.levels});

  final List<String> levels;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: levels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final id = levels[i];
          return SizedBox(
            width: 160,
            child: CategoryTile(
              emoji: levelEmoji(id),
              label: levelLabel(id),
              subtitle: levelHint(id),
              color: levelColor(id),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BookListScreen(
                    title: levelLabel(id),
                    books: state.filter(level: id),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ContinueRow extends StatelessWidget {
  const _ContinueRow({required this.books});

  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final b = books[i];
          final p = state.progress[b.id];
          return Material(
            color: QColors.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => openBook(context, b),
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    SizedBox(width: 84, child: BookCover(book: b, radius: 12, decodeWidth: 200)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                          const SizedBox(height: 8),
                          RoundedProgress(value: p?.fraction ?? 0),
                          const SizedBox(height: 6),
                          Text(
                            b.format == BookFormat.pdf && p != null
                                ? 'Halaman ${p.position + 1} dari ${p.length}'
                                : '${((p?.fraction ?? 0) * 100).round()}% selesai',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
