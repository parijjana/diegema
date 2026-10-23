import 'package:diegema/sync/link_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = List<int>.generate(32, (i) => i);
  LinkCode code({int? port = 50123, List<String> a = const ['192.168.1.14']}) =>
      LinkCode(
          groupKey: key,
          addresses: a,
          port: port,
          name: 'Anita’s phone',
          expiresAtMillis: 1000);

  test('round trip, small enough for a quick QR', () {
    final text = code().encode();
    expect(text, startsWith('DIEGEMALINK1.'));
    expect(text.length, lessThan(200));
    final back = LinkCode.decode(text)!;
    expect(back.groupKey, key);
    expect(back.addresses, ['192.168.1.14']);
    expect(back.port, 50123);
    expect(back.name, 'Anita’s phone');
    expect(back.expiresAtMillis, 1000);
  });

  test('a Mac code has no port and no addresses', () {
    final back = LinkCode.decode(code(port: null, a: const []).encode())!;
    expect(back.port, isNull);
    expect(back.addresses, isEmpty);
  });

  test('a pasted code with line breaks and spaces still reads', () {
    final text = code().encode();
    final mangled =
        ' ${text.substring(0, 20)}\n${text.substring(20, 50)} \r\n${text.substring(50)}\n';
    expect(LinkCode.decode(mangled)?.port, 50123);
  });

  test('expiry', () {
    expect(code().expiredAt(999), isFalse);
    expect(code().expiredAt(1000), isTrue);
  });

  test('anything else is null, never a throw', () {
    for (final bad in [
      '',
      'hello',
      'KORILAN1.abc',
      'DIEGEMALINK1.',
      'DIEGEMALINK1.!!!!',
      'DIEGEMALINK1.${'e30'}', // {}
      LinkCode(
              groupKey: List<int>.filled(16, 1),
              addresses: const [],
              port: null,
              name: '',
              expiresAtMillis: 1)
          .encode(), // short key
      code(port: 70000).encode(),
    ]) {
      expect(LinkCode.decode(bad), isNull, reason: bad);
    }
  });
}
