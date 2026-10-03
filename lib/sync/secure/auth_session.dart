import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'frame_channel.dart';

/// The authenticated session two linked devices run before a sync
/// (SYNC_DESIGN §2). Authentication only, by owner decision 2026-10-03:
/// what travels (which books, where you are in them) is not worth hiding
/// from the same Wi-Fi, but a stranger must not be able to forge, replay or
/// pull it. Nothing is encrypted, so the apps stay "no non-exempt
/// encryption" for export compliance.
///
/// Both sides hold the group key (it reaches a new device inside the link
/// QR, never over the network). Challenge-response, initiator I and
/// responder R:
///
///   M1  I→R  {p, n: nonce_I}
///   M2  R→I  {n: nonce_R, a: HMAC(k_R, "R" ‖ transcript)}
///   M3  I→R  {a: HMAC(k_I, "I" ‖ transcript)}
///   k_I, k_R = HKDF-SHA256(group key, info: protocol ‖ nonce_I ‖ nonce_R)
///
/// Fresh nonces from both sides stop replays of an old session; separate
/// keys per direction stop reflection. Every later frame is
/// `payload ‖ HMAC(k_sender, counter ‖ payload)`, so an altered, replayed,
/// reordered or dropped frame fails to verify.
enum HandshakeFailure {
  /// Malformed or unexpected message, or a different protocol version.
  protocol,

  /// The other side doesn't hold this group key, or the traffic was altered.
  wrongKey,

  /// The other side closed the connection mid-handshake.
  closed,
}

class HandshakeException implements Exception {
  final HandshakeFailure failure;
  final String? detail;
  const HandshakeException(this.failure, [this.detail]);
  @override
  String toString() =>
      'HandshakeException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// An established session received a frame that doesn't verify; the
/// session is closed and should be dropped (the next sync starts anew).
class SessionBroken implements Exception {
  const SessionBroken();
  @override
  String toString() => 'SessionBroken';
}

List<int> secureRandomBytes(int n) {
  final r = Random.secure();
  return List<int>.generate(n, (_) => r.nextInt(256));
}

class SessionConfig {
  final List<int> groupKey;

  /// Injected by tests for repeatable transcripts.
  final List<int> Function(int n) randomBytes;

  SessionConfig(
      {required this.groupKey, this.randomBytes = secureRandomBytes}) {
    if (groupKey.length != 32) {
      throw ArgumentError('group key must be 32 bytes');
    }
  }
}

const _protocol = 'diegema-session/2';
const _tagLength = 32;

class AuthSession {
  final FrameChannel _channel;
  final SecretKey _sendKey;
  final SecretKey _receiveKey;
  int _sendCounter = 0;
  int _receiveCounter = 0;
  Future<void> _sending = Future.value();

  AuthSession._(this._channel, this._sendKey, this._receiveKey);

  /// Sends are queued, so frames leave in counter order even when callers
  /// don't await each one.
  Future<void> send(List<int> message) {
    final counter = _sendCounter++;
    final sent = _sending.then((_) async {
      _channel.write([...message, ...await _tag(_sendKey, counter, message)]);
    });
    _sending = sent.catchError((Object _) {});
    return sent;
  }

  /// The next message. Throws [SessionBroken] when a frame doesn't verify
  /// and [ChannelClosed] when the other side has gone.
  Future<Uint8List> receive() async {
    final frame = await _channel.read();
    try {
      return await _verify(_receiveKey, _receiveCounter++, frame);
    } on _Unverified {
      await _channel.close();
      throw const SessionBroken();
    }
  }

  Future<void> close() => _channel.close();

  /// Runs the handshake as the device that connected.
  static Future<AuthSession> initiate(
          FrameChannel channel, SessionConfig config) =>
      _guard(channel, () => _Handshake(channel, config, true).run());

  /// Runs the handshake as the device that accepted the connection.
  static Future<AuthSession> respond(
          FrameChannel channel, SessionConfig config) =>
      _guard(channel, () => _Handshake(channel, config, false).run());

  static Future<AuthSession> _guard(
      FrameChannel channel, Future<AuthSession> Function() run) async {
    try {
      return await run();
    } catch (e) {
      await channel.close();
      if (e is HandshakeException) rethrow;
      if (e is ChannelClosed) {
        throw const HandshakeException(HandshakeFailure.closed);
      }
      if (e is _Unverified) {
        throw const HandshakeException(HandshakeFailure.wrongKey);
      }
      // Whatever else a malformed message caused (bad JSON, wrong types,
      // bad lengths) is the peer not speaking the protocol.
      throw HandshakeException(HandshakeFailure.protocol, '$e');
    }
  }
}

class _Unverified implements Exception {
  const _Unverified();
}

final _hmac = Hmac.sha256();

Future<List<int>> _mac(SecretKey key, List<int> data) async =>
    (await _hmac.calculateMac(data, secretKey: key)).bytes;

List<int> _counterBytes(int counter) =>
    (ByteData(8)..setUint64(0, counter, Endian.big)).buffer.asUint8List();

Future<List<int>> _tag(SecretKey key, int counter, List<int> payload) =>
    _mac(key, [..._counterBytes(counter), ...payload]);

Future<Uint8List> _verify(SecretKey key, int counter, Uint8List frame) async {
  if (frame.length < _tagLength) throw const _Unverified();
  final payload = frame.sublist(0, frame.length - _tagLength);
  final expected = await _tag(key, counter, payload);
  if (!_equal(expected, frame.sublist(frame.length - _tagLength))) {
    throw const _Unverified();
  }
  return payload;
}

String _b64(List<int> bytes) => base64Url.encode(bytes);
Uint8List _unb64(Object? s, int length) {
  final bytes = base64Url.decode(s as String);
  if (bytes.length != length) {
    throw FormatException('expected $length bytes, got ${bytes.length}');
  }
  return bytes;
}

class _Handshake {
  final FrameChannel channel;
  final SessionConfig config;
  final bool initiator;
  final _transcript = BytesBuilder();

  _Handshake(this.channel, this.config, this.initiator);

  void _record(List<int> frame) {
    final len = ByteData(4)..setUint32(0, frame.length, Endian.big);
    _transcript
      ..add(len.buffer.asUint8List())
      ..add(frame);
  }

  void _send(Map<String, Object?> message) {
    final frame = utf8.encode(jsonEncode(message));
    _record(frame);
    channel.write(frame);
  }

  Future<Map<String, Object?>> _receive({bool record = true}) async {
    final frame = await channel.read();
    if (record) _record(frame);
    final decoded = jsonDecode(utf8.decode(frame));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('not an object');
    }
    return decoded;
  }

  Future<(SecretKey, SecretKey)> _keys(
      List<int> nonceI, List<int> nonceR) async {
    final okm =
        await (await Hkdf(hmac: Hmac.sha256(), outputLength: 64).deriveKey(
      secretKey: SecretKey(config.groupKey),
      info: [...utf8.encode(_protocol), ...nonceI, ...nonceR],
    ))
            .extractBytes();
    return (SecretKey(okm.sublist(0, 32)), SecretKey(okm.sublist(32)));
  }

  /// HMAC over the transcript so far (M1 and the nonce part of M2).
  Future<List<int>> _proof(SecretKey key, String role, List<int> transcript) =>
      _mac(key, [...utf8.encode(role), ...transcript]);

  Future<AuthSession> run() async {
    final myNonce = config.randomBytes(32);
    late SecretKey kI, kR;
    if (initiator) {
      _send({'p': _protocol, 'n': _b64(myNonce)});
      final m1 = _transcript.toBytes();
      final m2 = await _receive(record: false);
      final nonceR = _unb64(m2['n'], 32);
      (kI, kR) = await _keys(myNonce, nonceR);
      final seen = [...m1, ...nonceR];
      if (!_equal(await _proof(kR, 'R', seen), _unb64(m2['a'], 32))) {
        throw const _Unverified();
      }
      _send({'a': _b64(await _proof(kI, 'I', seen))});
      return AuthSession._(channel, kI, kR);
    } else {
      final m1 = await _receive();
      if (m1['p'] != _protocol) {
        throw HandshakeException(HandshakeFailure.protocol, '${m1['p']}');
      }
      final nonceI = _unb64(m1['n'], 32);
      (kI, kR) = await _keys(nonceI, myNonce);
      final seen = [..._transcript.toBytes(), ...myNonce];
      _send({
        'n': _b64(myNonce),
        'a': _b64(await _proof(kR, 'R', seen)),
      });
      final m3 = await _receive(record: false);
      if (!_equal(await _proof(kI, 'I', seen), _unb64(m3['a'], 32))) {
        throw const _Unverified();
      }
      return AuthSession._(channel, kR, kI);
    }
  }
}

bool _equal(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
