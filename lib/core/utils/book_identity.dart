import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Canonical book-identity rules (rework_plan.md Phase 1, item 8).
///
/// Historically this app had FOUR different ID schemes for the same
/// conceptual book: the LibriVox API numeric id, the archive.org
/// identifier, `'local_${folderName.hashCode.abs()}'`, and raw local
/// import paths. Two of those were built on `Object.hashCode` /
/// `String.hashCode`, which Dart explicitly does **not** guarantee to be
/// stable across SDK releases — using it as a *persisted* primary key
/// means an SDK upgrade can silently orphan a user's entire library
/// (every row's id changes, nothing matches on the next scan).
///
/// The rule going forward:
/// - Anything sourced from LibriVox/archive.org uses the **archive.org
///   identifier** as its id (see [archiveIdentifierFor]). That identifier
///   is already how archive.org's own metadata/cover/audio endpoints are
///   addressed, so this removes a translation step as well as fixing the
///   stability bug.
/// - Genuinely local content (manually imported folders/files, or
///   downloads scanned back off disk) uses a **sha256 of a normalised
///   absolute path** (see [localIdForPath]). sha256 is deterministic
///   across Dart/platform versions (unlike `hashCode`), collision-safe
///   for this purpose, and requires no persisted-UUID bookkeeping at
///   import time.
class BookIdentity {
  BookIdentity._();

  static const String originLibrivox = 'librivox';
  static const String originLocal = 'local';

  /// Prefix used for every local-content id, so callers (and the v1->v2
  /// migration) can cheaply recognise a local id without re-hashing.
  static const String localIdPrefix = 'local_';

  /// Legacy id prefixes produced by the pre-migration `hashCode`-based
  /// schemes. Recognised by the v1->v2 migration so it can re-key them.
  static const List<String> legacyLocalIdPrefixes = [
    'local_',
    'imported_folder_',
    'imported_files_',
  ];

  /// Extracts the archive.org identifier from a LibriVox book's
  /// `url_iarchive` field (e.g.
  /// `https://archive.org/details/frankenstein_1205_librivox` ->
  /// `frankenstein_1205_librivox`). Falls back to the raw LibriVox API id
  /// when no archive.org URL is present (some very old catalog entries
  /// lack one) — that fallback is intentionally the *old* numeric id
  /// scheme, kept only so we never produce an empty id.
  static String archiveIdentifierFor({
    required String librivoxApiId,
    required String urlIarchive,
  }) {
    if (urlIarchive.isNotEmpty) {
      final parts = urlIarchive.split('/details/');
      if (parts.length > 1) {
        final identifier = parts[1].split('/').first.trim();
        if (identifier.isNotEmpty) return identifier;
      }
    }
    return librivoxApiId;
  }

  /// Deterministic id for genuinely local content, derived from a
  /// normalised absolute path — never from `hashCode`. Two imports of the
  /// same folder/file (e.g. after a re-scan) always produce the same id,
  /// so progress and metadata are not duplicated.
  static String localIdForPath(String absolutePath) {
    final normalised = p.normalize(absolutePath).replaceAll('\\', '/');
    final digest = sha256.convert(utf8.encode(normalised));
    return '$localIdPrefix${digest.toString()}';
  }

  /// Deterministic id for a local import backed by a *set* of paths
  /// (e.g. picking several loose files rather than a folder). Order is
  /// normalised first so the same set of files always hashes the same
  /// regardless of picker ordering.
  static String localIdForPaths(List<String> absolutePaths) {
    final normalised = absolutePaths
        .map((path) => p.normalize(path).replaceAll('\\', '/'))
        .toList()
      ..sort();
    final digest = sha256.convert(utf8.encode(normalised.join('\n')));
    return '$localIdPrefix${digest.toString()}';
  }

  static bool isLegacyLocalId(String id) {
    return legacyLocalIdPrefixes.any((prefix) => id.startsWith(prefix));
  }
}
