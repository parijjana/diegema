import 'dart:async';

import 'package:flutter/material.dart';

import '../core/utils/duration_format.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import '../theme/app_theme.dart';
import 'player_transport.dart';

/// Bookmarks for the book now playing: add one at the current position (with
/// an optional note), see the book's list newest first, jump to an entry,
/// edit its note, delete it with undo.
///
/// Everything goes through the existing [AppDatabase] bookmark API, so the
/// rows keep syncing between linked devices exactly as before — this widget
/// owns no storage of its own.
///
/// Opened via [showBookmarks], which picks a bottom sheet on phone widths and
/// a centred dialog on wide ones, the same split [showUpNext] uses.
class BookmarksSheet extends StatefulWidget {
  final UnifiedAudiobook book;
  final AudioPlaybackService audioService;
  final AppDatabase db;

  const BookmarksSheet({
    super.key,
    required this.book,
    required this.audioService,
    required this.db,
  });

  @override
  State<BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends State<BookmarksSheet> {
  final _note = TextEditingController();
  List<Bookmark>? _bookmarks;

  /// Rows hidden by a delete that can still be undone. The database row is
  /// only removed once the SnackBar goes away (or this sheet closes), so an
  /// undo restores the original row, creation time and all.
  final Map<String, Bookmark> _pendingDeletes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    // A delete still waiting out its undo window is final once we leave.
    for (final id in _pendingDeletes.keys) {
      unawaited(widget.db.deleteBookmark(id));
    }
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await widget.db.getBookmarks(widget.book.id);
    // createdAt only has second resolution, and ids are time stamps, so the
    // id breaks ties and keeps "newest first" stable.
    rows.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
    if (!mounted) return;
    setState(() => _bookmarks = rows);
  }

  Future<void> _add() async {
    final audio = widget.audioService;
    await widget.db.addBookmark(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      audiobookId: widget.book.id,
      chapterIndex: audio.chapterIndexNotifier.value,
      positionSeconds: audio.positionNotifier.value.inSeconds,
      note: _note.text.trim(),
    );
    _note.clear();
    await _load();
  }

  void _jumpTo(Bookmark b) {
    final audio = widget.audioService;
    final position = Duration(seconds: b.positionSeconds);
    Navigator.of(context).pop();
    if (b.chapterIndex == audio.chapterIndexNotifier.value) {
      audio.seek(position);
    } else {
      audio.loadBook(widget.book,
          initialChapterIndex: b.chapterIndex, initialPosition: position);
    }
  }

  Future<void> _edit(Bookmark b) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _NoteDialog(initial: b.note),
    );
    if (note == null) return;
    await widget.db.updateBookmark(id: b.id, note: note);
    await _load();
  }

  void _delete(Bookmark b, ScaffoldMessengerState messenger) {
    setState(() => _pendingDeletes[b.id] = b);
    messenger.clearSnackBars();
    messenger
        .showSnackBar(SnackBar(
          content: const Text('Bookmark deleted'),
          // An action makes a SnackBar sticky by default; this is a brief
          // undo window, after which the delete is final.
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (mounted) setState(() => _pendingDeletes.remove(b.id));
            },
          ),
        ))
        .closed
        .then((_) {
      // Still pending means it was not undone: make it final.
      if (_pendingDeletes.remove(b.id) != null) {
        unawaited(widget.db.deleteBookmark(b.id));
        if (mounted) _load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = [
      for (final b in _bookmarks ?? const <Bookmark>[])
        if (!_pendingDeletes.containsKey(b.id)) b,
    ];

    // Its own messenger and Scaffold, so the undo SnackBar appears inside
    // the sheet instead of behind the modal barrier.
    return ScaffoldMessenger(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.x5, Sp.x5, Sp.x5, Sp.x2),
                child: Text('Bookmarks',
                    style:
                        AppType.serif(AppType.titleMd).copyWith(color: c.text)),
              ),
              _AddRow(
                controller: _note,
                audioService: widget.audioService,
                onAdd: _add,
              ),
              Divider(height: 1, color: c.border),
              Flexible(
                child: _bookmarks == null
                    ? const SizedBox(height: Sp.x16)
                    : rows.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(Sp.x5),
                            child: Text(
                              'No bookmarks yet. Add one to mark your place.',
                              style:
                                  AppType.body.copyWith(color: c.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding:
                                const EdgeInsets.symmetric(vertical: Sp.x2),
                            itemCount: rows.length,
                            itemBuilder: (context, i) => _BookmarkRow(
                              bookmark: rows[i],
                              chapterTitle: _chapterTitle(rows[i].chapterIndex),
                              onTap: () => _jumpTo(rows[i]),
                              onEdit: () => _edit(rows[i]),
                              onDelete: () => _delete(
                                  rows[i], ScaffoldMessenger.of(context)),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _chapterTitle(int index) {
    final chapters = widget.book.chapters;
    return index >= 0 && index < chapters.length
        ? chapters[index].title
        : 'Chapter ${index + 1}';
  }
}

/// Optional note plus the button that saves the current position.
class _AddRow extends StatelessWidget {
  final TextEditingController controller;
  final AudioPlaybackService audioService;
  final VoidCallback onAdd;
  const _AddRow({
    required this.controller,
    required this.audioService,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x5, Sp.x2, Sp.x5, Sp.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            style: AppType.body.copyWith(color: context.colors.text),
            decoration:
                const InputDecoration(hintText: 'Add a note (optional)'),
          ),
          const SizedBox(height: Sp.x3),
          ValueListenableBuilder<Duration>(
            valueListenable: audioService.positionNotifier,
            builder: (context, position, _) => FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(Dim.tapMin)),
              onPressed: onAdd,
              icon: const Icon(Icons.bookmark_add_rounded),
              label: Text('Bookmark ${formatTimecode(position)}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  final Bookmark bookmark;
  final String chapterTitle;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _BookmarkRow({
    required this.bookmark,
    required this.chapterTitle,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final time = formatTimecode(Duration(seconds: bookmark.positionSeconds));
    final note = bookmark.note.trim();

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Dim.tapMin),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.x5, Sp.x2, Sp.x2, Sp.x2),
                child: Semantics(
                  button: true,
                  label: 'Go to $chapterTitle at $time',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$chapterTitle · $time',
                          style: AppType.label.copyWith(color: c.text)),
                      if (note.isNotEmpty)
                        Text(note,
                            style:
                                AppType.body.copyWith(color: c.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Edit note',
          constraints:
              const BoxConstraints(minWidth: Dim.tapMin, minHeight: Dim.tapMin),
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded),
        ),
        IconButton(
          tooltip: 'Delete bookmark',
          constraints:
              const BoxConstraints(minWidth: Dim.tapMin, minHeight: Dim.tapMin),
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
        const SizedBox(width: Sp.x2),
      ],
    );
  }
}

class _NoteDialog extends StatefulWidget {
  final String initial;
  const _NoteDialog({required this.initial});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit note'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: null,
        decoration: const InputDecoration(hintText: 'Note'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// The Bookmarks control for Now Playing's action row. [face] draws it in the
/// shape chosen in Settings; without one it is a free-standing pill, like the
/// speed and sleep controls on wide layouts.
class BookmarksButton extends StatelessWidget {
  final UnifiedAudiobook book;
  final AudioPlaybackService audioService;
  final AppDatabase db;
  final ActionFaceBuilder? face;
  final BorderRadius radius;

  const BookmarksButton({
    super.key,
    required this.book,
    required this.audioService,
    required this.db,
    this.face,
    this.radius = R.md,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Bookmarks. Save or revisit a place in this book.',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => showBookmarks(context,
              book: book, audioService: audioService, db: db),
          borderRadius: radius,
          child: face != null
              ? face!(
                  context,
                  const ActionFace(
                    icon: Icons.bookmark_rounded,
                    caption: 'Bookmarks',
                    value: 'Save place',
                    short: 'Marks',
                  ),
                )
              : Container(
                  constraints: const BoxConstraints(minHeight: Dim.tapMin),
                  padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
                  decoration: BoxDecoration(
                    color: c.accentWash,
                    borderRadius: R.pill,
                    border: Border.all(color: c.accent),
                    boxShadow: c.shadowUi,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_rounded,
                          size: Dim.iconSm, color: c.accentText),
                      const SizedBox(width: Sp.x2),
                      Text('Bookmarks',
                          style: AppType.label.copyWith(color: c.accentText)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Opens [BookmarksSheet] as a bottom sheet on phone widths and a centred
/// dialog on wide ones.
Future<void> showBookmarks(
  BuildContext context, {
  required UnifiedAudiobook book,
  required AudioPlaybackService audioService,
  required AppDatabase db,
}) {
  final wide = MediaQuery.sizeOf(context).width >= Dim.wideBreakpoint;
  final sheet = BookmarksSheet(book: book, audioService: audioService, db: db);

  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: sheet,
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.80,
      ),
      child: sheet,
    ),
  );
}
