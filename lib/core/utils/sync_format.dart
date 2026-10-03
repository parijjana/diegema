import '../../sync/sync_view.dart';

/// Always h:mm:ss, so "Ch 4, 0:12:34" lines up between devices.
String formatClockHms(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${s ~/ 3600}:${two((s % 3600) ~/ 60)}:${two(s % 60)}';
}

/// "Ch 4, 0:12:34": a synced position (chapters are stored zero-based).
String formatSyncPosition(int chapter, int seconds) =>
    'Ch ${chapter + 1}, ${formatClockHms(seconds)}';

/// "just now", "5 min ago", "3 h ago", "yesterday", "4 days ago".
String relativeTime(int atMillis, int nowMillis) {
  final diff = Duration(milliseconds: nowMillis - atMillis);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 2) return 'yesterday';
  if (diff.inDays < 60) return '${diff.inDays} days ago';
  return '${diff.inDays ~/ 30} months ago';
}

/// "MacBook", or "MacBook and 1 more" (names sorted, so it is stable).
String deviceListLabel(SyncView view, Set<String> deviceIds) {
  final names = [for (final id in deviceIds) view.deviceName(id)]..sort();
  if (names.isEmpty) return 'another device';
  if (names.length == 1) return names.first;
  return '${names.first} and ${names.length - 1} more';
}
