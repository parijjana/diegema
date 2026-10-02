/// A book's chapter list couldn't be fetched: offline, timed out, or the
/// feed answered with an error. Distinct from a feed that loads and has no
/// chapters, which still returns a book with an empty chapter list.
class ChaptersUnavailable implements Exception {
  final String reason;
  const ChaptersUnavailable(this.reason);

  @override
  String toString() => 'ChaptersUnavailable: $reason';
}
