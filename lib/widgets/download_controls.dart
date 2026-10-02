import 'package:flutter/material.dart';

import '../services/download_manager.dart';
import '../theme/app_theme.dart';

/// What a download is doing, in a few words: the footer's button label and
/// the Downloads screen's status line.
String downloadLabel(DownloadManager manager, BookDownload d) {
  final percent = d.progress == null ? '' : ' ${(d.progress! * 100).round()}%';
  switch (d.phase) {
    case DownloadPhase.queued:
      if (manager.waitingForWifi(d.id)) return 'Waiting for Wi-Fi';
      final position = manager.queuePosition(d.id) ?? 1;
      return position == 1 ? 'Queued · next' : 'Queued · $position in line';
    case DownloadPhase.downloading:
      return 'Downloading…$percent';
    case DownloadPhase.paused:
      return 'Paused$percent';
    case DownloadPhase.extracting:
      return 'Adding to your library…';
    case DownloadPhase.failed:
      return 'Download failed';
    case DownloadPhase.done:
      return 'Downloaded';
  }
}

IconData downloadIcon(DownloadPhase phase) => switch (phase) {
      DownloadPhase.queued => Icons.schedule_rounded,
      DownloadPhase.downloading => Icons.downloading_rounded,
      DownloadPhase.paused => Icons.pause_circle_outline_rounded,
      DownloadPhase.extracting => Icons.library_add_rounded,
      DownloadPhase.failed => Icons.refresh_rounded,
      DownloadPhase.done => Icons.check_circle_rounded,
    };

/// A thin progress bar for a download that is moving: determinate while the
/// size is known, indeterminate while it is not (and while extracting).
/// Nothing for queued, failed or finished downloads.
class DownloadProgressBar extends StatelessWidget {
  final BookDownload download;

  const DownloadProgressBar({super.key, required this.download});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final phase = download.phase;
    if (phase != DownloadPhase.downloading &&
        phase != DownloadPhase.paused &&
        phase != DownloadPhase.extracting) {
      return const SizedBox.shrink();
    }
    final value = phase == DownloadPhase.extracting ? null : download.progress;
    return ClipRRect(
      borderRadius: R.pill,
      child: LinearProgressIndicator(
        // A paused download with no known size shows an empty track rather
        // than an animation that says it is still moving.
        value: phase == DownloadPhase.paused ? (value ?? 0) : value,
        minHeight: 3,
        backgroundColor: c.accent.withValues(alpha: 0.2),
        valueColor: AlwaysStoppedAnimation(c.accent),
      ),
    );
  }
}

/// Pause / Resume / Cancel / Retry for one download, as text buttons that
/// wrap onto a second line at large text sizes. [includeRetry] is off where
/// the caller's own primary button already retries.
class DownloadActions extends StatelessWidget {
  final DownloadManager manager;
  final BookDownload download;
  final bool includeRetry;

  const DownloadActions({
    super.key,
    required this.manager,
    required this.download,
    this.includeRetry = true,
  });

  @override
  Widget build(BuildContext context) {
    final id = download.id;
    final title = download.title;
    final buttons = <Widget>[
      if (download.phase == DownloadPhase.downloading)
        _action('Pause', 'Pause downloading $title', () => manager.pause(id)),
      if (download.phase == DownloadPhase.paused)
        _action(
            'Resume', 'Resume downloading $title', () => manager.resume(id)),
      if (download.phase == DownloadPhase.failed && includeRetry)
        _action('Retry', 'Retry downloading $title', () => manager.retry(id)),
      if (download.phase == DownloadPhase.failed)
        _action('Dismiss', 'Dismiss the failed download of $title',
            () => manager.dismiss(id)),
      if (download.phase == DownloadPhase.queued ||
          download.phase == DownloadPhase.downloading ||
          download.phase == DownloadPhase.paused)
        _action('Cancel', 'Cancel downloading $title', () => manager.cancel(id)),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Sp.x2,
      children: buttons,
    );
  }

  Widget _action(String label, String semantics, VoidCallback onPressed) =>
      Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        child: TextButton(
          style: TextButton.styleFrom(
              minimumSize: const Size(Dim.tapMin, Dim.tapMin)),
          onPressed: onPressed,
          child: Text(label),
        ),
      );
}
