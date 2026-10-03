import 'dart:convert';

import 'hlc.dart';

/// What a record describes. Each (kind, key, device) has exactly one writer —
/// the device itself — so merging never has to pick a winner between
/// devices: the newer stamp from the same device simply replaces the older.
enum SyncKind {
  /// A book in the device's library. Key: portable book key. Payload: see
  /// [CataloguePayload]. A tombstone means the device removed the book.
  catalogue,

  /// Where the device is in a book. Key: portable book key.
  position,

  /// The furthest the device has got in a book. Key: portable book key.
  furthest,

  /// Finished (true) or reset (false) on the device. Key: portable book key.
  finished,

  /// A bookmark the device made. Key: bookmark id. Tombstone = deleted.
  bookmark,

  /// A device's name and platform. Key: device id.
  device,
}

class SyncRecord {
  final SyncKind kind;
  final String key;
  final String deviceId;
  final Hlc hlc;
  final Map<String, Object?> payload;
  final bool deleted;

  /// [deviceId] is always the stamp's device, so a record can't claim one
  /// writer and carry another's clock.
  SyncRecord({
    required this.kind,
    required this.key,
    required this.hlc,
    this.payload = const {},
    this.deleted = false,
  }) : deviceId = hlc.deviceId;

  /// (kind, key, device): the slot this record is the latest value of.
  String get slot => '${kind.name}|$key|$deviceId';

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'key': key,
        'hlc': hlc.encode(),
        if (payload.isNotEmpty) 'payload': payload,
        if (deleted) 'deleted': true,
      };

  static SyncRecord fromJson(Map<String, Object?> json) => SyncRecord(
        kind: SyncKind.values.byName(json['kind'] as String),
        key: json['key'] as String,
        hlc: Hlc.decode(json['hlc'] as String),
        payload: (json['payload'] as Map?)?.cast<String, Object?>() ?? const {},
        deleted: json['deleted'] == true,
      );

  String encode() => jsonEncode(toJson());

  @override
  String toString() => encode();
}
