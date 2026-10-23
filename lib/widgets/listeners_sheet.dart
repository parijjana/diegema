import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import '../services/sync/sync_controller.dart';
import '../sync/sync_view.dart';
import '../theme/app_theme.dart';
import 'other_devices_section.dart';

/// Now Playing's "Listeners" entry: opens a sheet with every linked
/// device's place in the loaded book. Present only when sync is set up and
/// some other device has something on the book; otherwise it takes no space
/// and raises no error. Nothing seeks until a button in the sheet is tapped.
class ListenersButton extends StatefulWidget {
  final UnifiedAudiobook book;
  final AudioPlaybackService audioService;
  final AppDatabase db;

  const ListenersButton({
    super.key,
    required this.book,
    required this.audioService,
    required this.db,
  });

  @override
  State<ListenersButton> createState() => _ListenersButtonState();
}

class _ListenersButtonState extends State<ListenersButton> {
  String? _key;
  SyncView? _loadedFor;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view = SyncScope.viewOf(context);
    if (!identical(view, _loadedFor)) {
      _loadedFor = view;
      _loadKey();
    }
  }

  @override
  void didUpdateWidget(ListenersButton old) {
    super.didUpdateWidget(old);
    if (old.book.id != widget.book.id) {
      _key = null;
      _loadKey();
    }
  }

  Future<void> _loadKey() async {
    final sync = SyncScope.maybeOf(context);
    if (sync == null) return;
    final generation = ++_generation;
    final bookId = widget.book.id;
    String? key;
    try {
      key = (await sync.portableKeys())[bookId];
    } catch (_) {
      return;
    }
    if (!mounted || generation != _generation || bookId != widget.book.id) {
      return;
    }
    setState(() => _key = key);
  }

  void _open(String key) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ListenersSheet(
        book: widget.book,
        audioService: widget.audioService,
        db: widget.db,
        bookKey: key,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = SyncScope.viewOf(context);
    final key = _key;
    if (view == null ||
        key == null ||
        !OtherDevicesSection.hasContent(view, key)) {
      return const SizedBox.shrink();
    }
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x1, Sp.x4, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Semantics(
          label: 'Listeners',
          button: true,
          excludeSemantics: true,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size(Dim.tapMin, Dim.tapMin),
              foregroundColor: c.accentText,
            ),
            onPressed: () => _open(key),
            icon: const Icon(Icons.people_alt_outlined),
            label: const Text('Listeners'),
          ),
        ),
      ),
    );
  }
}

/// The sheet body: titled, scrollable, with [OtherDevicesSection] inside.
class ListenersSheet extends StatefulWidget {
  final UnifiedAudiobook book;
  final AudioPlaybackService audioService;
  final AppDatabase db;
  final String bookKey;

  const ListenersSheet({
    super.key,
    required this.book,
    required this.audioService,
    required this.db,
    required this.bookKey,
  });

  @override
  State<ListenersSheet> createState() => _ListenersSheetState();
}

class _ListenersSheetState extends State<ListenersSheet> {
  DevicePosition? _local;

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    DevicePosition? local;
    try {
      final saved = await widget.db.getProgress(widget.book.id);
      if (saved != null) {
        // A finished book is past every position.
        final finished =
            saved.positionSeconds == AppDatabase.finishedPositionSeconds;
        local = DevicePosition(
          '',
          finished ? widget.book.chapters.length : saved.chapterIndex,
          finished ? 0 : saved.positionSeconds,
          0,
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _local = local);
  }

  /// Only ever called from a tap on a button in the section.
  void _jumpTo(DevicePosition p) {
    final chapters = widget.book.chapters.length;
    if (chapters == 0) return;
    widget.audioService.loadBook(
      widget.book,
      initialChapterIndex: p.chapter.clamp(0, chapters - 1),
      initialPosition: Duration(seconds: p.seconds),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final view = SyncScope.viewOf(context);
    final c = context.colors;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          Sp.x4, 0, Sp.x4, Sp.x4 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Listeners',
                style: AppType.titleSm.copyWith(color: c.text)),
          ),
          const SizedBox(height: Sp.x3),
          if (view != null)
            OtherDevicesSection(
              view: view,
              bookKey: widget.bookKey,
              local: _local,
              onJump: _jumpTo,
              showHeader: false,
            ),
        ],
      ),
    );
  }
}
