import 'package:flutter/material.dart';

import '../services/hidden_books_store.dart';

/// Hides [id] on this device and shows the "Hidden · Undo" snackbar. Takes
/// the messenger (not a context) so it can run after the caller's route is
/// popped. Nothing but the hidden set changes: files, progress, bookmarks
/// and playback are untouched.
Future<void> hideBookWithUndo(
    ScaffoldMessengerState messenger, HiddenBooksStore store, String id) async {
  await store.hide(id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: const Text('Hidden'),
      action: SnackBarAction(label: 'Undo', onPressed: () => store.unhide(id)),
    ));
}
