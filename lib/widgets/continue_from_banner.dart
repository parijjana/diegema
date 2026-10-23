import 'package:flutter/material.dart';

import '../core/utils/sync_format.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/audio_playback_service.dart';
import '../services/sync/sync_controller.dart';
import '../sync/sync_view.dart';
import '../theme/app_theme.dart';

/// Now Playing's "Continue from (device) · Ch 4, 0:12:34 · 5 min ago": shown
/// only when another linked device saved a newer, different position in the
/// book that is loaded here. It never moves the listener's place by itself:
/// only a tap on Continue seeks.
///
/// Absent entirely (no space, no error) when there is no sync scope, no
/// view yet, or nothing to offer.
class ContinueFromBanner extends StatefulWidget {
  final UnifiedAudiobook book;
  final AudioPlaybackService audioService;
  final AppDatabase db;

  /// Offers the user closed in this app run, by book key, device and save
  /// time. A newer save from the same device is a new offer.
  static final Set<String> _closed = {};

  @visibleForTesting
  static void debugResetClosed() => _closed.clear();

  const ContinueFromBanner({
    super.key,
    required this.book,
    required this.audioService,
    required this.db,
  });

  @override
  State<ContinueFromBanner> createState() => _ContinueFromBannerState();
}

class _ContinueFromBannerState extends State<ContinueFromBanner> {
  String? _key;
  DevicePosition? _local;
  int? _localAtMillis;
  SyncView? _loadedFor;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The view is rebuilt after every refresh and sync; look again.
    final view = SyncScope.viewOf(context);
    if (!identical(view, _loadedFor)) {
      _loadedFor = view;
      _loadLocal();
    }
  }

  @override
  void didUpdateWidget(ContinueFromBanner old) {
    super.didUpdateWidget(old);
    if (old.book.id != widget.book.id) {
      _key = null;
      _local = null;
      _localAtMillis = null;
      _loadLocal();
    }
  }

  /// This device's portable key for the book and its saved position, as
  /// `resumeOffer` wants them.
  Future<void> _loadLocal() async {
    final sync = SyncScope.maybeOf(context);
    if (sync == null) return;
    final generation = ++_generation;
    final bookId = widget.book.id;
    String? key;
    DevicePosition? local;
    int? at;
    try {
      key = (await sync.portableKeys())[bookId];
      final saved = await widget.db.getProgress(bookId);
      if (saved != null) {
        at = saved.updatedAt.millisecondsSinceEpoch;
        if (saved.positionSeconds != AppDatabase.finishedPositionSeconds) {
          local =
              DevicePosition('', saved.chapterIndex, saved.positionSeconds, at);
        }
      }
    } catch (_) {
      return;
    }
    if (!mounted || generation != _generation || bookId != widget.book.id) {
      return;
    }
    setState(() {
      _key = key;
      _local = local;
      _localAtMillis = at;
    });
  }

  static String _closedId(String key, DevicePosition p) =>
      '$key|${p.deviceId}|${p.atMillis}';

  Future<void> _continue(DevicePosition offer, String key) async {
    final chapters = widget.book.chapters.length;
    if (chapters == 0) return;
    ContinueFromBanner._closed.add(_closedId(key, offer));
    setState(() {});
    await widget.audioService.loadBook(
      widget.book,
      initialChapterIndex: offer.chapter.clamp(0, chapters - 1),
      initialPosition: Duration(seconds: offer.seconds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = SyncScope.viewOf(context);
    final key = _key;
    if (view == null || key == null) return const SizedBox.shrink();
    final offer =
        view.resumeOffer(key, local: _local, localAtMillis: _localAtMillis);
    if (offer == null ||
        ContinueFromBanner._closed.contains(_closedId(key, offer))) {
      return const SizedBox.shrink();
    }

    final c = context.colors;
    final label = 'Continue from ${view.deviceName(offer.deviceId)} · '
        '${formatSyncPosition(offer.chapter, offer.seconds)} · '
        '${relativeTime(offer.atMillis, DateTime.now().millisecondsSinceEpoch)}';
    final continueButton = TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(Dim.tapMin, Dim.tapMin),
        foregroundColor: c.accentText,
      ),
      onPressed: () => _continue(offer, key),
      child: const Text('Continue'),
    );
    final close = IconButton(
      tooltip: 'Dismiss',
      constraints:
          const BoxConstraints(minWidth: Dim.tapMin, minHeight: Dim.tapMin),
      icon: const Icon(Icons.close_rounded),
      onPressed: () =>
          setState(() => ContinueFromBanner._closed.add(_closedId(key, offer))),
    );
    final text = Text(label,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: AppType.body.copyWith(color: c.text));
    // Large text: the buttons drop below the line instead of squeezing it.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x2, Sp.x4, 0),
      child: Semantics(
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: R.md,
            border: Border.all(color: c.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Sp.x3, Sp.x1, Sp.x1, Sp.x1),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: Sp.x2),
                        child: text,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [continueButton, close],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: text),
                      continueButton,
                      close,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
