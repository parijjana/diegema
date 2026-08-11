import 'dart:async';

/// Universal rate limiter for the LibriVox / archive.org APIs.
class RateLimitDispatcher {
  final Map<String, Future<void>> _queues = {};

  /// Replaces every per-API cooldown when set, including any passed to
  /// [dispatch].
  ///
  /// Exists for tests. The cooldowns below are real wall-clock
  /// `Future.delayed`s, and widget tests only advance real time in the
  /// short slices `tester.runAsync` allows — so a screen that fans out
  /// across several shelves never finishes loading, and the pending timers
  /// hang the test binding outright (not even `--timeout` interrupts it,
  /// because the wait is inside `runAsync`). Passing [Duration.zero] here
  /// keeps the queueing and ordering behaviour these tests exercise while
  /// removing the waiting they cannot survive.
  final Duration? cooldownOverride;

  RateLimitDispatcher({this.cooldownOverride});

  static const Map<String, Duration> defaultCooldowns = {
    'librivox': Duration(seconds: 1),
  };

  Future<T> dispatch<T>({
    required String apiId,
    required Future<T> Function() call,
    Duration? cooldown,
  }) {
    final completer = Completer<T>();
    final effectiveCooldown = cooldownOverride ??
        cooldown ??
        defaultCooldowns[apiId] ??
        const Duration(seconds: 1);

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
