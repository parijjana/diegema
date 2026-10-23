import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/utils/book_identity.dart';
import '../../database/app_database_io.dart';
import '../../domain/models/audiobook.dart';

/// How much of the first audio file goes into a content key.
const int contentKeyPrefixBytes = 64 * 1024;

/// The key a LibriVox book has on every device: its archive.org identifier.
/// Null for local books, whose key needs their files (see [contentKeyFor]).
String? librivoxKeyFor(UnifiedAudiobook book) =>
    book.origin == BookIdentity.originLibrivox &&
            !book.id.startsWith(BookIdentity.localIdPrefix)
        ? 'lv:${book.id}'
        : null;

/// The key a local book has on every device that holds the same files:
/// sha256 over the sorted file sizes and the first 64 KB of the first
/// file. The same M4B or folder of MP3s matches wherever it sits; a
/// re-encoded copy does not. Null if a file can't be read.
Future<String?> contentKeyFor(List<String> paths) async {
  final files = <String>[];
  for (final path in paths) {
    if (!files.contains(path)) files.add(path);
  }
  if (files.isEmpty) return null;
  try {
    final sizes = [for (final f in files) await File(f).length()]..sort();
    final raf = await File(files.first).open();
    final Uint8List head;
    try {
      head = await raf.read(contentKeyPrefixBytes);
    } finally {
      await raf.close();
    }
    final digest = sha256.convert([
      ...'diegema-ck1:${sizes.join(',')}:'.codeUnits,
      ...head,
    ]);
    return 'ck:$digest';
  } on FileSystemException {
    return null;
  }
}

Future<String?> portableKeyFor(UnifiedAudiobook book) async =>
    librivoxKeyFor(book) ??
    await contentKeyFor([
      for (final ch in book.chapters)
        if (!ch.isStream) ch.audioPathOrUrl,
    ]);

/// Works out the key of every book that has none yet. A book whose files
/// can't be read now is tried again next time. Returns how many were set.
Future<int> fillPortableKeys(AppDatabase db) async {
  final known = await db.portableKeys();
  var filled = 0;
  for (final book in await db.getAllAudiobooks()) {
    if (known.containsKey(book.id)) continue;
    final key = await portableKeyFor(book);
    if (key == null) continue;
    await db.setPortableKey(book.id, key);
    filled++;
  }
  return filled;
}
