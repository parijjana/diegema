import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../services/storage_usage.dart';
import '../theme/app_theme.dart';
import 'library_book_detail_overlay.dart' show formatBytes;

/// Settings > Storage: how much space downloads, saved covers and the
/// search cache take, and one button that clears the caches. Downloads and
/// library folders are never cleared from here.
class StorageSection extends StatefulWidget {
  final AppDatabase db;

  /// Test seams; default to the real measurement and clearing.
  final Future<StorageUsage> Function()? measure;
  final Future<int> Function()? clear;

  const StorageSection({super.key, required this.db, this.measure, this.clear});

  @override
  State<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends State<StorageSection> {
  StorageUsage? _usage;
  String? _result;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  Future<void> _measure() async {
    final usage = await (widget.measure ?? () => measureStorage(widget.db))();
    if (mounted) setState(() => _usage = usage);
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    final freed = await (widget.clear ?? () => clearCaches(widget.db))();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result =
          freed == 0 ? 'Nothing to clear.' : 'Cleared ${formatBytes(freed)}.';
    });
    await _measure();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final usage = _usage;
    String size(int? bytes) => usage == null ? '...' : formatBytes(bytes ?? 0);
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.x2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label, style: AppType.body.copyWith(color: c.text)),
              ),
              const SizedBox(width: Sp.x3),
              Text(value, style: AppType.body.copyWith(color: c.textSecondary)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('Downloads', size(usage?.downloads)),
        row('Covers', size(usage?.covers)),
        row('Search cache', size(usage?.searchCache)),
        const SizedBox(height: Sp.x2),
        Text(
          'Clearing removes saved searches and covers no book uses. Your '
          'downloads, library folders and listening progress are never '
          'touched.',
          style: AppType.caption.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Sp.x3),
        OutlinedButton(
          style:
              OutlinedButton.styleFrom(minimumSize: const Size(0, Dim.tapMin)),
          onPressed: _busy ? null : _clear,
          child: const Text('Clear caches'),
        ),
        if (_result != null) ...[
          const SizedBox(height: Sp.x2),
          Semantics(
            liveRegion: true,
            child: Text(_result!,
                style: AppType.caption.copyWith(color: c.textSecondary)),
          ),
        ],
      ],
    );
  }
}
