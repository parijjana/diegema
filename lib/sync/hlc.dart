/// Hybrid logical clock (wall time + counter + device), so records from
/// devices whose clocks are a few minutes apart still order sensibly and
/// every stamp is unique. Pure Dart: the sync core has no Flutter imports.
class Hlc implements Comparable<Hlc> {
  final int wallMillis;
  final int counter;
  final String deviceId;

  const Hlc(this.wallMillis, this.counter, this.deviceId);

  /// Earlier than any real stamp from [deviceId].
  const Hlc.zero(this.deviceId)
      : wallMillis = 0,
        counter = 0;

  /// The next stamp for a local event at wall time [nowMillis].
  Hlc tick(int nowMillis) => nowMillis > wallMillis
      ? Hlc(nowMillis, 0, deviceId)
      : Hlc(wallMillis, counter + 1, deviceId);

  /// This clock after seeing [remote], so the next local stamp sorts after
  /// everything already received.
  Hlc receive(Hlc remote, int nowMillis) {
    final wall = [wallMillis, remote.wallMillis, nowMillis]
        .reduce((a, b) => a > b ? a : b);
    final int next;
    if (wall == wallMillis && wall == remote.wallMillis) {
      next = (counter > remote.counter ? counter : remote.counter) + 1;
    } else if (wall == wallMillis) {
      next = counter + 1;
    } else if (wall == remote.wallMillis) {
      next = remote.counter + 1;
    } else {
      next = 0;
    }
    return Hlc(wall, next, deviceId);
  }

  @override
  int compareTo(Hlc other) {
    if (wallMillis != other.wallMillis) {
      return wallMillis.compareTo(other.wallMillis);
    }
    if (counter != other.counter) return counter.compareTo(other.counter);
    return deviceId.compareTo(other.deviceId);
  }

  bool operator >(Hlc other) => compareTo(other) > 0;
  bool operator <(Hlc other) => compareTo(other) < 0;

  /// Sortable as text: `<wall 15 digits>-<counter 6 digits>-<device>`.
  String encode() => '${wallMillis.toString().padLeft(15, '0')}-'
      '${counter.toString().padLeft(6, '0')}-$deviceId';

  static Hlc decode(String text) {
    final first = text.indexOf('-');
    final second = text.indexOf('-', first + 1);
    if (first <= 0 || second <= first) {
      throw FormatException('Not an HLC stamp', text);
    }
    return Hlc(
      int.parse(text.substring(0, first)),
      int.parse(text.substring(first + 1, second)),
      text.substring(second + 1),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.wallMillis == wallMillis &&
      other.counter == counter &&
      other.deviceId == deviceId;

  @override
  int get hashCode => Object.hash(wallMillis, counter, deviceId);

  @override
  String toString() => encode();
}
