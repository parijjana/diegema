import 'package:flutter/material.dart';
import '../database/app_database.dart';

Future<void> importFolder(
    BuildContext context, AppDatabase db, VoidCallback onSuccess) async {
  _showUnavailable(context);
}

Future<void> importFiles(
    BuildContext context, AppDatabase db, VoidCallback onSuccess) async {
  _showUnavailable(context);
}

void _showUnavailable(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
          'Importing local files is not available in this web demo — see '
          'the desktop app for full library import.'),
    ),
  );
}
