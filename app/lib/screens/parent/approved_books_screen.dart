import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../models/profile.dart';
import '../../services/labels.dart';
import '../../services/search.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/book_cover.dart';

/// Orang tua memilih buku yang boleh dibaca anak (untuk profil "hanya buku pilihan").
class ApprovedBooksScreen extends StatefulWidget {
  const ApprovedBooksScreen({super.key, required this.profile});

  final ChildProfile profile;

  @override
  State<ApprovedBooksScreen> createState() => _ApprovedBooksScreenState();
}

class _ApprovedBooksScreenState extends State<ApprovedBooksScreen> {
  late final AppState _state = context.read<AppState>();
  late final List<Book> _books = (_state.catalog?.books ?? const <Book>[])
      .where((b) => b.levels.any(widget.profile.levels.contains))
      .toList();
  late final _search = BookSearch(_books);
  Set<String> _approved = {};
  String _query = '';
  bool _onlySelected = false;
  String? _kind;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _state.approvedFor(widget.profile.id).then((ids) {
      if (mounted) {
        setState(() {
          _approved = ids;
          _loading = false;
        });
      }
    });
  }

  List<Book> get _visible {
    var list = _query.trim().isEmpty ? _books : _search.search(_query, limit: 500);
    if (_onlySelected) list = list.where((b) => _approved.contains(b.id)).toList();
    if (_kind != null) list = list.where((b) => b.kind == _kind).toList();
    return list;
  }

  Future<void> _toggle(Book b) async {
    final value = !_approved.contains(b.id);
    setState(() => value ? _approved.add(b.id) : _approved.remove(b.id));
    await _state.setApproved(widget.profile.id, [b.id], value);
  }

  Future<void> _setAll(List<Book> books, bool value) async {
    setState(() {
      for (final b in books) {
        value ? _approved.add(b.id) : _approved.remove(b.id);
      }
    });
    await _state.setApproved(widget.profile.id, books.map((b) => b.id), value);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(
        title: Text('Buku untuk ${widget.profile.name}'),
        actions: [
          PopupMenuButton<bool>(
            tooltip: 'Pilih banyak',
            onSelected: (v) => _setAll(visible, v),
            itemBuilder: (_) => [
              PopupMenuItem(value: true, child: Text('Pilih semua yang tampil (${visible.length})')),
              const PopupMenuItem(value: false, child: Text('Batalkan semua yang tampil')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Cari judul, penulis, atau tema',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: Text('✅ Dipilih (${_approved.length})'),
                  selected: _onlySelected,
                  onSelected: (v) => setState(() => _onlySelected = v),
                ),
                const SizedBox(width: 8),
                for (final k in const ['buku', 'komik', 'audio', 'video']) ...[
                  FilterChip(
                    label: Text('${kindEmoji(k)} ${kindLabel(k)}'),
                    selected: _kind == k,
                    onSelected: (v) => setState(() => _kind = v ? k : null),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? Center(child: Text('Tidak ada buku', style: text.bodyLarge))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 140,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.56,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final b = visible[i];
                      final selected = _approved.contains(b.id);
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _toggle(b),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 150),
                                  opacity: selected ? 1 : 0.55,
                                  child: BookCover(book: b, radius: 14, decodeWidth: 280),
                                ),
                                Positioned(
                                  left: 6,
                                  top: 6,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected ? QColors.leaf : Colors.white.withValues(alpha: 0.9),
                                      border: Border.all(color: selected ? QColors.leaf : QColors.line, width: 2),
                                    ),
                                    child: selected
                                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.labelMedium),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
