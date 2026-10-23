import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'sync_group.dart';
import 'sync_record.dart';

/// Why a sync file was refused.
enum SyncFileProblem {
  /// Not a Diegema sync file, or a newer format than this app reads.
  notSyncFile,

  /// Written by a device of another sync group.
  otherGroup,

  /// The signature doesn't match: changed or damaged since it was written.
  damaged,
}

class SyncFileError implements Exception {
  final SyncFileProblem problem;
  const SyncFileError(this.problem);
  @override
  String toString() => 'SyncFileError(${problem.name})';
}

/// What a sync file holds once its signature checks out.
class SyncFileContents {
  /// The device that wrote it.
  final String deviceId;
  final int createdAtMillis;
  final List<SyncRecord> records;

  const SyncFileContents(this.deviceId, this.createdAtMillis, this.records);
}

/// A sync file (SYNC_DESIGN S12): every record a device holds, carried by
/// hand (AirDrop, USB drive, shared folder) to a device that can't reach it
/// over the network, e.g. Mac to Mac. Like a network sync it is signed, not
/// encrypted (authentication only, §2): HMAC-SHA256 under a key derived from
/// the group key, so only a member of the group can write one the others
/// accept. Importing merges like a sync, so an old or repeated file changes
/// nothing that is newer.
///
/// Layout: JSON `{format, group, body, mac}`. `body` is the records as a
/// JSON string, signed exactly as stored; `group` is the group's mDNS tag,
/// so a file from another group is told apart from a damaged one.
class SyncFile {
  static const format = 'diegema-sync-file/1';
  static const extension = 'diegemasync';

  /// Larger than any real library's records by far; refuses a stray huge
  /// file before parsing it.
  static const maxBytes = 16 * 1024 * 1024;

  static Future<List<int>> encode({
    required List<int> groupKey,
    required String deviceId,
    required int createdAtMillis,
    required List<SyncRecord> records,
  }) async {
    final body = jsonEncode({
      'from': deviceId,
      'created': createdAtMillis,
      'records': [for (final r in records) r.toJson()],
    });
    return utf8.encode(
      jsonEncode({
        'format': format,
        'group': await groupTagOf(groupKey),
        'body': body,
        'mac': base64.encode(await _mac(groupKey, body)),
      }),
    );
  }

  /// Checks the file against [groupKey] and returns its records. Throws
  /// [SyncFileError].
  static Future<SyncFileContents> decode(
    List<int> bytes, {
    required List<int> groupKey,
  }) async {
    if (bytes.length > maxBytes) {
      throw const SyncFileError(SyncFileProblem.notSyncFile);
    }
    final Map<String, Object?> outer;
    try {
      outer = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    } catch (_) {
      throw const SyncFileError(SyncFileProblem.notSyncFile);
    }
    final body = outer['body'];
    final mac = outer['mac'];
    if (outer['format'] != format || body is! String || mac is! String) {
      throw const SyncFileError(SyncFileProblem.notSyncFile);
    }
    if (outer['group'] != await groupTagOf(groupKey)) {
      throw const SyncFileError(SyncFileProblem.otherGroup);
    }
    final List<int> given;
    try {
      given = base64.decode(mac);
    } catch (_) {
      throw const SyncFileError(SyncFileProblem.damaged);
    }
    if (!_equal(given, await _mac(groupKey, body))) {
      throw const SyncFileError(SyncFileProblem.damaged);
    }
    try {
      final inner = jsonDecode(body) as Map<String, Object?>;
      return SyncFileContents(
        inner['from'] as String,
        inner['created'] as int,
        [
          for (final r in inner['records'] as List)
            SyncRecord.fromJson(r as Map<String, Object?>),
        ],
      );
    } catch (_) {
      // Signed by a member but unreadable here: a format this build
      // doesn't know.
      throw const SyncFileError(SyncFileProblem.notSyncFile);
    }
  }

  /// `diegema-<device name>-<yyyy-mm-dd>.diegemasync`.
  static String fileName(String deviceName, DateTime when) {
    final safe = deviceName
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .toLowerCase();
    final d =
        '${when.year}-${when.month.toString().padLeft(2, '0')}-'
        '${when.day.toString().padLeft(2, '0')}';
    return 'diegema-${safe.isEmpty ? 'device' : safe}-$d.$extension';
  }

  static Future<List<int>> _mac(List<int> groupKey, String body) async {
    final hmac = Hmac.sha256();
    final fileKey = await hmac.calculateMac(
      utf8.encode(format),
      secretKey: SecretKey(groupKey),
    );
    return (await hmac.calculateMac(
      utf8.encode(body),
      secretKey: SecretKey(fileKey.bytes),
    )).bytes;
  }

  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
