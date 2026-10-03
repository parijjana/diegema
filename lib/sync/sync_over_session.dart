import 'dart:convert';

import 'secure/secure_session.dart';
import 'sync_exchange.dart';

/// How many records moved each way in one exchange.
class ExchangeCounts {
  final int sent;
  final int received;
  const ExchangeCounts(this.sent, this.received);
  @override
  String toString() => 'sent=$sent received=$received';
}

const _type = 'sync/1';

Future<void> _send(SecureSession s, SyncMessage m) =>
    s.send(utf8.encode(jsonEncode({'t': _type, ...m.toJson()})));

Future<SyncMessage> _receive(SecureSession s) async {
  final json = jsonDecode(utf8.decode(await s.receive()));
  if (json is! Map<String, Object?> || json['t'] != _type) {
    throw const FormatException('not a sync/1 message');
  }
  return SyncMessage.fromJson(json);
}

/// The [SyncPeer] three-message exchange over an established session, as
/// the device that connected. A fourth, empty message from the responder
/// says it has applied everything, so a finished call means both sides
/// hold the same records.
Future<ExchangeCounts> syncAsInitiator(SecureSession s, SyncPeer peer) async {
  await _send(s, await peer.hello());
  final answer = await _receive(s);
  final last = await peer.complete(answer);
  await _send(s, last);
  await _receive(s);
  return ExchangeCounts(last.records.length, answer.records.length);
}

/// The same exchange as the device that accepted the connection.
Future<ExchangeCounts> syncAsResponder(SecureSession s, SyncPeer peer) async {
  final hello = await _receive(s);
  final answer = await peer.answer(hello);
  await _send(s, answer);
  final last = await _receive(s);
  await peer.finish(last);
  await _send(s, const SyncMessage());
  return ExchangeCounts(answer.records.length, last.records.length);
}
