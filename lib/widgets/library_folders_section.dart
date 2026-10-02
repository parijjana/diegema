import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../services/library_locations_scanner.dart';
import '../services/library_locations_store.dart';
import '../theme/app_theme.dart';

/// Settings rows for library locations: the folders Diegema reads books
/// from in place. Removing one only makes Diegema forget its books — the
/// files are never touched, and listening progress is kept, so adding the
/// folder back picks up where it left off.
class LibraryFoldersSection extends StatefulWidget {
  final AppDatabase db;
  final LibraryLocationsStore store;

  const LibraryFoldersSection({
    super.key,
    required this.db,
    this.store = const LibraryLocationsStore(),
  });

  @override
  State<LibraryFoldersSection> createState() => _LibraryFoldersSectionState();
}

class _LibraryFoldersSectionState extends State<LibraryFoldersSection> {
  List<String>? _locations;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final locations = await widget.store.read();
    if (mounted) setState(() => _locations = locations);
  }

  Future<void> _remove(String location) async {
    final name = p.basename(location);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "$name"?'),
        content: const Text('Its books leave your library. The files stay '
            'where they are, and your progress is kept if you add the '
            'folder again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    for (final id in await booksInLocation(widget.db, location)) {
      await widget.db.deleteAudiobook(id);
    }
    await widget.store.remove(location);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final locations = _locations;
    if (locations == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Diegema reads books from these folders where they are. Nothing '
          'in them is copied, moved or changed. Add one from Library → '
          'Import → Add a library folder.',
          style: AppType.caption.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Sp.x3),
        if (locations.isEmpty)
          Text('No library folders yet.',
              style: AppType.body.copyWith(color: c.textSecondary)),
        for (final location in locations)
          Container(
            constraints: const BoxConstraints(minHeight: Dim.tapMin),
            padding: const EdgeInsets.symmetric(vertical: Sp.x1),
            child: Row(
              children: [
                Icon(Icons.folder_rounded,
                    size: Dim.iconSm, color: c.accentText),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.basename(location),
                          style: AppType.label.copyWith(color: c.text)),
                      Text(location,
                          style: AppType.caption
                              .copyWith(color: c.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${p.basename(location)}',
                  icon: Icon(Icons.close_rounded, color: c.textSecondary),
                  onPressed: () => _remove(location),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
