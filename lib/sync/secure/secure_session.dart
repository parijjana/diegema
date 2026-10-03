import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'frame_channel.dart';

/// The encrypted session two devices run before any sync or linking
/// (SYNC_DESIGN §2, §4). Proportionate to the data (what you listen to and
/// where you are in it): a stranger on the same Wi-Fi can neither read nor
/// forge the traffic, and nothing more elaborate.
///
/// Handshake, initiator I (the device that connects) and responder R:
///
///   M1  I→R  {p, m, e: I's ephemeral X25519, n: nonce_I | c: H(nonce_I)}
///   M2  R→I  {e: R's ephemeral X25519, n: nonce_R}
///   M3  I→R  {n: nonce_I}                         numeric mode only
///   keys = HKDF-SHA256(X25519 secret, salt: the pre-shared key, info: transcript)
///   A1  I→R  sealed {k: I's device key, s: Ed25519(transcript)}
///   A2  R→I  sealed {k: R's device key, s: Ed25519(transcript)}
///
/// The pre-shared key is the group key ([SessionMode.group]) or the one-time
/// token from a link QR ([SessionMode.token]). Mixing it into the keys means
/// A1 only opens for someone who knows it. [SessionMode.numeric] has none:
/// both screens show a six-digit code from the transcript, and each side
/// sends its A message only after its user confirms that the codes match.
/// The commitment in M1 means a man in the middle gets one guess in a
/// million at making the two codes agree.
enum SessionMode { group, token, numeric }

enum HandshakeFailure {
  /// Malformed or unexpected message, or a different protocol version.
  protocol,

  /// The two sides were set up for different modes.
  modeMismatch,

  /// Numeric mode: the revealed nonce does not match its commitment.
  commitment,

  /// A sealed frame did not open: the other side has a different group key
  /// or token, or the traffic was altered.
  wrongKey,

  /// The device key's signature over the transcript does not verify.
  badSignature,

  /// The device key is not one this side accepts (not a group member, not
  /// the key in the scanned QR).
  peerRejected,

  /// Numeric mode: this side's user said the codes do not match.
  codeRejected,

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

/// A device's long-term identity key (Ed25519). The 32-byte seed is what
/// gets stored in the platform keystore.
class DeviceIdentity {
  final SimpleKeyPair _keyPair;
  final Uint8List publicKey;

  DeviceIdentity._(this._keyPair, this.publicKey);

  static Future<DeviceIdentity> fromSeed(List<int> seed) async {
    final kp = await Ed25519().newKeyPairFromSeed(seed);
    final pub = await kp.extractPublicKey();
    return DeviceIdentity._(kp, Uint8List.fromList(pub.bytes));
  }

  static Future<(DeviceIdentity, Uint8List)> generate(
      {List<int> Function(int)? randomBytes}) async {
    final seed = Uint8List.fromList((randomBytes ?? secureRandomBytes)(32));
    return (await fromSeed(seed), seed);
  }

  Future<Uint8List> sign(List<int> message) async => Uint8List.fromList(
      (await Ed25519().sign(message, keyPair: _keyPair)).bytes);
}

List<int> secureRandomBytes(int n) {
  final r = Random.secure();
  return List<int>.generate(n, (_) => r.nextInt(256));
}

/// Decides whether a peer's device key is acceptable. Returning false
/// fails the handshake with [HandshakeFailure.peerRejected].
typedef PeerPolicy = Future<bool> Function(Uint8List devicePublicKey);

/// Numeric mode: show [code] and resolve to whether the user confirmed that
/// both screens show the same number.
typedef ConfirmCode = Future<bool> Function(String code);

class SessionConfig {
  final SessionMode mode;
  final DeviceIdentity identity;

  /// The group key or link token; null in numeric mode.
  final List<int>? preSharedKey;
  final PeerPolicy acceptPeer;
  final ConfirmCode? confirmCode;

  /// Injected by tests for repeatable transcripts.
  final List<int> Function(int n) randomBytes;

  SessionConfig({
    required this.mode,
    required this.identity,
    required this.acceptPeer,
    this.preSharedKey,
    this.confirmCode,
    this.randomBytes = secureRandomBytes,
  }) {
    if ((mode == SessionMode.numeric) != (preSharedKey == null)) {
      throw ArgumentError('a pre-shared key is required except in numeric '
          'mode, and not allowed in it');
    }
    if (mode == SessionMode.numeric && confirmCode == null) {
      throw ArgumentError('numeric mode needs confirmCode');
    }
  }
}

const _protocol = 'diegema-session/1';
const _maxCounter = 0xFFFFFFFFFFFF;

/// An established session. Frames are ChaCha20-Poly1305 sealed with one key
/// per direction and a counter nonce, so a dropped, repeated or reordered
/// frame fails to open.
class SecureSession {
  final FrameChannel _channel;
  final SecretKey _sendKey;
  final SecretKey _receiveKey;
  int _sendCounter;
  int _receiveCounter;

  /// The other device's Ed25519 key, already accepted by the policy.
  final Uint8List peerPublicKey;

  /// SHA-256 of the handshake messages; identical on both sides.
  final Uint8List transcriptHash;

  /// Numeric mode only: the six-digit code both users compared.
  final String? code;

  SecureSession._(
    this._channel,
    this._sendKey,
    this._receiveKey,
    this._sendCounter,
    this._receiveCounter,
    this.peerPublicKey,
    this.transcriptHash,
    this.code,
  );

  Future<void> send(List<int> message) async {
    _channel.write(await _seal(_sendKey, _sendCounter++, message));
  }

  Future<Uint8List> receive() async {
    final frame = await _channel.read();
    return _open(_receiveKey, _receiveCounter++, frame);
  }

  Future<void> close() => _channel.close();

  /// Runs the handshake as the device that connected.
  static Future<SecureSession> initiate(
          FrameChannel channel, SessionConfig config) =>
      _guard(channel, () => _Handshake(channel, config, true).run());

  /// Runs the handshake as the device that accepted the connection.
  static Future<SecureSession> respond(
          FrameChannel channel, SessionConfig config) =>
      _guard(channel, () => _Handshake(channel, config, false).run());

  static Future<SecureSession> _guard(
      FrameChannel channel, Future<SecureSession> Function() run) async {
    try {
      return await run();
    } catch (e) {
      await channel.close();
      if (e is HandshakeException) rethrow;
      if (e is ChannelClosed) {
        throw const HandshakeException(HandshakeFailure.closed);
      }
      if (e is FormatException || e is TypeError) {
        throw HandshakeException(HandshakeFailure.protocol, '$e');
      }
      rethrow;
    }
  }
}

final _aead = Chacha20.poly1305Aead();

List<int> _nonce(int counter) {
  if (counter > _maxCounter) throw StateError('session exhausted');
  final n = ByteData(12)..setUint64(4, counter, Endian.big);
  return n.buffer.asUint8List();
}

Future<Uint8List> _seal(SecretKey key, int counter, List<int> clear) async {
  final box =
      await _aead.encrypt(clear, secretKey: key, nonce: _nonce(counter));
  return Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
}

Future<Uint8List> _open(SecretKey key, int counter, Uint8List frame) async {
  if (frame.length < 16) {
    throw const HandshakeException(HandshakeFailure.wrongKey, 'short frame');
  }
  final box = SecretBox(
    frame.sublist(0, frame.length - 16),
    nonce: _nonce(counter),
    mac: Mac(frame.sublist(frame.length - 16)),
  );
  try {
    return Uint8List.fromList(await _aead.decrypt(box, secretKey: key));
  } on SecretBoxAuthenticationError {
    throw const HandshakeException(HandshakeFailure.wrongKey);
  }
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

  Future<Map<String, Object?>> _receive() async {
    final frame = await channel.read();
    _record(frame);
    final decoded = jsonDecode(utf8.decode(frame));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('not an object');
    }
    return decoded;
  }

  Future<SecureSession> run() async {
    final numeric = config.mode == SessionMode.numeric;
    final x25519 = X25519();
    final eph = await x25519.newKeyPairFromSeed(config.randomBytes(32));
    final ephPub = (await eph.extractPublicKey()).bytes;
    final myNonce = Uint8List.fromList(config.randomBytes(32));

    late Uint8List peerEph;
    if (initiator) {
      _send({
        'p': _protocol,
        'm': config.mode.name,
        'e': _b64(ephPub),
        if (numeric)
          'c': _b64((await Sha256().hash(myNonce)).bytes)
        else
          'n': _b64(myNonce),
      });
      final m2 = await _receive();
      peerEph = _unb64(m2['e'], 32);
      _unb64(m2['n'], 32);
      if (numeric) _send({'n': _b64(myNonce)});
    } else {
      final m1 = await _receive();
      if (m1['p'] != _protocol) {
        throw HandshakeException(HandshakeFailure.protocol, '${m1['p']}');
      }
      if (m1['m'] != config.mode.name) {
        throw HandshakeException(HandshakeFailure.modeMismatch, '${m1['m']}');
      }
      peerEph = _unb64(m1['e'], 32);
      final commitment = numeric ? _unb64(m1['c'], 32) : null;
      if (!numeric) _unb64(m1['n'], 32);
      _send({'e': _b64(ephPub), 'n': _b64(myNonce)});
      if (numeric) {
        final m3 = await _receive();
        final revealed = _unb64(m3['n'], 32);
        final hashed = (await Sha256().hash(revealed)).bytes;
        if (!_equal(hashed, commitment!)) {
          throw const HandshakeException(HandshakeFailure.commitment);
        }
      }
    }

    final transcript =
        Uint8List.fromList((await Sha256().hash(_transcript.toBytes())).bytes);
    final shared = await x25519.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: SimplePublicKey(peerEph, type: KeyPairType.x25519),
    );
    final okm =
        await (await Hkdf(hmac: Hmac.sha256(), outputLength: 64).deriveKey(
      secretKey: shared,
      nonce: config.preSharedKey ?? const [],
      info: [...utf8.encode('$_protocol keys'), ...transcript],
    ))
            .extractBytes();
    final iToR = SecretKey(okm.sublist(0, 32));
    final rToI = SecretKey(okm.sublist(32));
    final sendKey = initiator ? iToR : rToI;
    final receiveKey = initiator ? rToI : iToR;

    String? code;
    if (numeric) {
      code = await sixDigitCode(transcript);
      if (!await config.confirmCode!(code)) {
        throw const HandshakeException(HandshakeFailure.codeRejected);
      }
    }

    final mySig = await config.identity
        .sign(_authMessage(initiator: initiator, transcript: transcript));
    final myAuth = utf8.encode(
        jsonEncode({'k': _b64(config.identity.publicKey), 's': _b64(mySig)}));

    Future<Uint8List> receiveAuth() async {
      final opened = await _open(receiveKey, 0, await channel.read());
      final auth = jsonDecode(utf8.decode(opened)) as Map<String, Object?>;
      final peerKey = _unb64(auth['k'], 32);
      final sig = _unb64(auth['s'], 64);
      final ok = await Ed25519().verify(
        _authMessage(initiator: !initiator, transcript: transcript),
        signature: Signature(sig,
            publicKey: SimplePublicKey(peerKey, type: KeyPairType.ed25519)),
      );
      if (!ok) throw const HandshakeException(HandshakeFailure.badSignature);
      if (!await config.acceptPeer(peerKey)) {
        throw const HandshakeException(HandshakeFailure.peerRejected);
      }
      return peerKey;
    }

    late Uint8List peerKey;
    if (initiator) {
      channel.write(await _seal(sendKey, 0, myAuth));
      peerKey = await receiveAuth();
    } else {
      peerKey = await receiveAuth();
      channel.write(await _seal(sendKey, 0, myAuth));
    }
    return SecureSession._(
        channel, sendKey, receiveKey, 1, 1, peerKey, transcript, code);
  }
}

List<int> _authMessage(
        {required bool initiator, required List<int> transcript}) =>
    [...utf8.encode('$_protocol auth ${initiator ? 'I' : 'R'}'), ...transcript];

/// The code both screens show in numeric mode.
Future<String> sixDigitCode(List<int> transcript) async {
  final h =
      (await Sha256().hash([...utf8.encode('$_protocol code'), ...transcript]))
          .bytes;
  final n = ByteData.sublistView(Uint8List.fromList(h), 0, 4)
      .getUint32(0, Endian.big);
  return (n % 1000000).toString().padLeft(6, '0');
}

bool _equal(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
