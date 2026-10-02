import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../database/app_database.dart';
import '../domain/models/audiobook.dart';
import '../services/download_manager.dart';
import '../services/redownload.dart';
import '../theme/app_theme.dart';
import '../widgets/book_detail_pane.dart' show formatZipSize;
import '../widgets/download_controls.dart';

/// Settings > Downloads: the Wi-Fi only switch, every download still in
/// the queue (or failed) with its controls, and the books already
/// downloaded with the space they take.
class DownloadsScreen extends StatefulWidget {
  final AppDatabase db;
  final DownloadManager manager;

  const DownloadsScreen({super.key, required this.db, required this.manager});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late Future<List<(UnifiedAudiobook, int?)>> _finished;
  int _doneSeen = 0;

  @override
  void initState() {
    super.initState();
    _finished = _loadFinished();
    widget.manager.addListener(_onQueueChanged);
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onQueueChanged);
    super.dispose();
  }

  /// A download that just finished joins the list below.
  void _onQueueChanged() {
    final done =
        widget.manager.all.where((d) => d.phase == DownloadPhase.done).length;
    if (done != _doneSeen) {
      _doneSeen = done;
      setState(() => _finished = _loadFinished());
    } else {
      setState(() {});
    }
  }

  Future<List<(UnifiedAudiobook, int?)>> _loadFinished() async {
    final books = (await widget.db.getAllAudiobooks())
        .where(canRedownload)
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return [for (final b in books) (b, await downloadedBytes(b))];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final manager = widget.manager;
    // Finished ones show in the list below instead.
    final queue = manager.all.where((d) => d.phase != DownloadPhase.done);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Downloads')),
      body: LayoutBuilder(builder: (context, constraints) {
        final gutter = constraints.maxWidth >= Dim.wideBreakpoint
            ? Sp.gutterDesktop
            : Sp.gutterPhone;
        return ListView(
          padding: EdgeInsets.fromLTRB(gutter, Sp.x4, gutter, Sp.x8),
          children: [
            const DownloadsWifiToggle(),
            const SizedBox(height: Sp.x6),
            _heading(context, 'In progress'),
            if (queue.isEmpty)
              _note(context, 'Nothing is downloading.')
            else
              for (final d in queue) _QueueRow(manager: manager, download: d),
            const SizedBox(height: Sp.x6),
            _heading(context, 'Downloaded'),
            FutureBuilder<List<(UnifiedAudiobook, int?)>>(
              future: _finished,
              builder: (context, snap) {
                final rows = snap.data;
                if (rows == null) return const SizedBox.shrink();
                if (rows.isEmpty) {
                  return _note(
                      context, 'Books you download from Discover appear here.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (book, bytes) in rows)
                      _FinishedRow(book: book, bytes: bytes),
                  ],
                );
              },
            ),
          ],
        );
      }),
    );
  }

  Widget _heading(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.x3),
        child: Semantics(
          header: true,
          child: Text(text,
              style: AppType.titleSm
                  .copyWith(color: context.colors.textSecondary)),
        ),
      );

  Widget _note(BuildContext context, String text) => Text(text,
      style: AppType.body.copyWith(color: context.colors.textSecondary));
}

/// The Wi-Fi only switch, here and in the Settings panel's Downloads
/// section. Off by default.
class DownloadsWifiToggle extends StatelessWidget {
  const DownloadsWifiToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = SettingsScope.of(context);
    return MergeSemantics(
      child: InkWell(
        borderRadius: R.sm,
        onTap: () => settings.setDownloadsWifiOnly(!settings.downloadsWifiOnly),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Dim.tapMin),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Download on Wi-Fi only',
                        style: AppType.label.copyWith(color: c.text)),
                    const SizedBox(height: Sp.x1),
                    Text(
                        // Android and iOS mean "unmetered": a Wi-Fi network
                        // marked metered (a phone hotspot) does not count.
                        'Downloads wait for Wi-Fi instead of using mobile '
                        'data. A Wi-Fi network set as metered counts as '
                        'mobile data.',
                        style:
                            AppType.caption.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: Sp.x3),
              Switch(
                value: settings.downloadsWifiOnly,
                onChanged: settings.setDownloadsWifiOnly,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final DownloadManager manager;
  final BookDownload download;

  const _QueueRow({required this.manager, required this.download});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final failed = download.phase == DownloadPhase.failed;
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.listGap),
      padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x3, Sp.x4, Sp.x1),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: R.md,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(download.title, style: AppType.label.copyWith(color: c.text)),
          const SizedBox(height: Sp.x1),
          Text(
            failed && download.error != null
                ? download.error!
                : downloadLabel(manager, download),
            style: AppType.caption
                .copyWith(color: failed ? c.danger : c.textSecondary),
          ),
          const SizedBox(height: Sp.x2),
          DownloadProgressBar(download: download),
          Align(
            alignment: Alignment.centerRight,
            child: DownloadActions(manager: manager, download: download),
          ),
        ],
      ),
    );
  }
}

class _FinishedRow extends StatelessWidget {
  final UnifiedAudiobook book;
  final int? bytes;

  const _FinishedRow({required this.book, required this.bytes});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = formatZipSize(bytes) ?? 'Files missing';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Dim.tapMin),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.x2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: AppType.body.copyWith(color: c.text)),
                  Text(size,
                      style: AppType.caption.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
          ),
          if (canRevealDownloads && bytes != null)
            IconButton(
              tooltip: 'Show in folder',
              icon: const Icon(Icons.folder_open_rounded),
              onPressed: () => revealDownloadedBook(book),
            ),
        ],
      ),
    );
  }
}
