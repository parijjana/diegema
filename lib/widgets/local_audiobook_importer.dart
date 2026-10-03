import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../services/local_audiobook_import.dart' as import_service;

class LocalAudiobookImporter {
  static Future<void> importFolder(
      BuildContext context, AppDatabase db, VoidCallback onSuccess) {
    return import_service.importFolder(context, db, onSuccess);
  }

  static Future<void> importFiles(
      BuildContext context, AppDatabase db, VoidCallback onSuccess) {
    return import_service.importFiles(context, db, onSuccess);
  }

  static void showOptionsModal(
      BuildContext context, AppDatabase db, VoidCallback onSuccess) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IMPORT LOCAL AUDIOBOOK',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: primary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.folder_open_rounded, color: primary),
              title: const Text('Add a library folder',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text(
                  'A book or a folder of books. Read where it is: nothing is '
                  'copied or changed.',
                  style: TextStyle(fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                importFolder(context, db, onSuccess);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.audio_file_rounded, color: primary),
              title: const Text('Import Audio Files',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text(
                  'Select individual audio files to group into an audiobook',
                  style: TextStyle(fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                importFiles(context, db, onSuccess);
              },
            ),
          ],
        ),
      ),
    );
  }
}
