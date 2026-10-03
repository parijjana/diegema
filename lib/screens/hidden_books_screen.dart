import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/hidden_books_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_book_cover.dart';

/// Settings -> Hidden books: the books hidden from the Library on this
/// device, each with an "Unhide" button. Hiding is per device and never
/// synced; unhiding only removes the id from the local set.
class HiddenBooksScreen extends StatefulWidget {
  final AppDatabase db;
  final HiddenBooksStore store;

  const HiddenBooksScreen({
    super.key,
    required this.db,
    this.store = const HiddenBooksStore(),
  });

  @override
  State<HiddenBooksScreen> createState() => _HiddenBooksScreenState();
}

class _HiddenBooksScreenState extends State<HiddenBooksScreen> {
  List<String> _ids = [];
  Map<String, UnifiedAudiobook> _books = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = (await widget.store.read()).toList()..sort();
    var books = <String, UnifiedAudiobook>{};
    try {
      books = {for (final b in await widget.db.getAllAudiobooks()) b.id: b};
    } catch (_) {}
    if (!mounted) return;
    // Titles first (a-z), ids no longer in the database last.
    ids.sort((a, b) {
      final ba = books[a], bb = books[b];
      if (ba == null || bb == null) {
        if (ba == null && bb == null) return a.compareTo(b);
        return ba == null ? 1 : -1;
      }
      return ba.title.toLowerCase().compareTo(bb.title.toLowerCase());
    });
    setState(() {
      _ids = ids;
      _books = books;
      _loading = false;
    });
  }

  Future<void> _unhide(String id) async {
    await widget.store.unhide(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Hidden books')),
      body: LayoutBuilder(builder: (context, constraints) {
        final gutter = constraints.maxWidth >= Dim.wideBreakpoint
            ? Sp.gutterDesktop
            : Sp.gutterPhone;
        if (_loading) return const SizedBox.shrink();
        if (_ids.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Text('No hidden books',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: c.textSecondary)),
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, Sp.x4, gutter, Sp.x8),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.x3),
              child: Text(
                'Hidden only on this device. Their files, progress and '
                'bookmarks are untouched.',
                style: AppType.body.copyWith(color: c.textSecondary),
              ),
            ),
            for (final id in _ids)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.listGap),
                child: _HiddenRow(
                  id: id,
                  book: _books[id],
                  onUnhide: () => _unhide(id),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _HiddenRow extends StatelessWidget {
  final String id;
  final UnifiedAudiobook? book;
  final VoidCallback onUnhide;

  const _HiddenRow(
      {required this.id, required this.book, required this.onUnhide});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final b = book;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: R.md,
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.all(Sp.x3),
      child: Row(
        children: [
          if (b != null) ...[
            AppBookCover(
              bookId: b.id,
              title: b.title,
              coverUrl: b.coverArtUrlOrPath,
              width: 48,
              height: 48,
            ),
            const SizedBox(width: Sp.x3),
          ],
          Expanded(
            child: b == null
                // No longer in the database: show the raw id, dimmed. Unhide
                // still works, it just removes the id from the set.
                ? Text(id,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(color: c.textMuted))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(b.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodyLg.copyWith(
                              color: c.text, fontWeight: FontWeight.w600)),
                      const SizedBox(height: Sp.x1),
                      Text(b.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(color: c.textSecondary)),
                    ],
                  ),
          ),
          const SizedBox(width: Sp.x2),
          TextButton(
            style: TextButton.styleFrom(
                minimumSize: const Size(Dim.tapMin, Dim.tapMin)),
            onPressed: onUnhide,
            child: const Text('Unhide'),
          ),
        ],
      ),
    );
  }
}
