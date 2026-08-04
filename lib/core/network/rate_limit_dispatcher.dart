import 'dart:async';

/// Universal rate limiter for the LibriVox / archive.org APIs.
class RateLimitDispatcher {
  final Map<String, Future<void>> _queues = {};

  static const Map<String, Duration> defaultCooldowns = {
    'librivox': Duration(seconds: 1),
  };

  Future<T> dispatch<T>({
    required String apiId,
    required Future<T> Function() call,
    Duration? cooldown,
  }) {
    final completer = Completer<T>();
    final effectiveCooldown =
        cooldown ?? defaultCooldowns[apiId] ?? const Duration(seconds: 1);

    final previousFuture = _queues[apiId] ?? Future.value();

    final newFuture = previousFuture.then((_) async {
      try {
        final result = await call();
        completer.complete(result);
      } catch (e, s) {
        completer.completeError(e, s);
      } finally {
        await Future<void>.delayed(effectiveCooldown);
      }
    });

    _queues[apiId] = newFuture;

    return completer.future;
  }
}
