import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/screens/linked_devices_screen.dart';
import 'package:diegema/services/sync/sync_controller.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/theme/app_theme.dart';

import '../helpers/fake_sync_controller.dart';
import '../support/test_harness.dart';

void main() {
  // Built in setUp (the real zone), as the FakeAsync lesson asks.
  late FakeSyncController sync;
  var clockNow = DateTime(2026, 10, 3, 12);

  setUp(() {
    clockNow = DateTime(2026, 10, 3, 12);
    sync = FakeSyncController(records: [
      rec(SyncKind.device, 'mac', 'mac', 1,
          {'name': 'MacBook', 'platform': 'macos'}),
      rec(SyncKind.device, 'pc', 'pc', 2, {'name': 'Desk PC'}),
    ])
      ..syncClock = () => clockNow;
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    SyncStatus status = SyncStatus.linked,
    bool? mac = false,
    double textScale = 1.0,
    Size size = const Size(360, 800),
  }) async {
    sync.syncStatus = status;
    await setSurface(tester, size);
    await tester.pumpWidget(SyncScope(
      controller: sync,
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!),
        home: LinkedDevicesScreen(pollForScanner: mac, now: () => clockNow),
      ),
    ));
    await pumpFrames(tester);
  }

  Future<void> show(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 100,
        scrollable: find.byType(Scrollable).first);
    await pumpFrames(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await show(tester, find.text(text));
    await tester.tap(find.text(text));
    await pumpFrames(tester);
  }

  Future<void> close(WidgetTester tester) => unmount(tester);

  const explainer =
      "Link your phone, tablet and computers to keep your place in each book in step. Sync works when they're on the same Wi-Fi.";
  const unreadable =
      "Sync can't start on this device. Its saved link can't be read, which can happen after restoring from a backup.";

  group('layouts', () {
    testWidgets('unlinked: name, link actions and the explainer only',
        (tester) async {
      await pumpScreen(tester, status: SyncStatus.unlinked);
      expect(find.text('This device'), findsOneWidget);
      expect(find.text(explainer), findsOneWidget);
      expect(find.text('Link a device'), findsOneWidget);
      expect(find.text('Paste a code'), findsOneWidget);
      expect(find.text('Sync now'), findsNothing);
      expect(find.text('Other devices'), findsNothing);
      expect(find.text('Unlink this device'), findsNothing);
      expect(find.text('Reset sync'), findsNothing);
      await close(tester);
    });

    testWidgets('linked: sync, link actions, devices, unlink', (tester) async {
      await pumpScreen(tester);
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Link a device'), findsOneWidget);
      expect(find.text(explainer), findsNothing);
      expect(find.text(unreadable), findsNothing);
      await show(tester, find.text('Unlink this device'));
      expect(find.text('Other devices'), findsOneWidget);
      expect(find.text('MacBook'), findsOneWidget);
      await close(tester);
    });

    testWidgets('keysUnreadable: the card and Reset sync, no sync actions',
        (tester) async {
      await pumpScreen(tester, status: SyncStatus.keysUnreadable);
      expect(find.text(unreadable), findsOneWidget);
      expect(find.text('Reset sync'), findsOneWidget);
      expect(find.text('Sync now'), findsNothing);
      expect(find.text('Link a device'), findsNothing);
      expect(find.text('Unlink this device'), findsNothing);
      await close(tester);
    });
  });

  group('Reset sync', () {
    testWidgets('confirm resets and the screen becomes unlinked',
        (tester) async {
      await pumpScreen(tester, status: SyncStatus.keysUnreadable);
      await tester.tap(find.text('Reset sync'));
      await pumpFrames(tester);
      expect(
          find.text(
              'This device will need to be linked again. Your library stays.'),
          findsOneWidget);
      expect(sync.resetCalls, 0);
      await tester.tap(find.widgetWithText(TextButton, 'Reset sync'));
      await pumpFrames(tester);
      expect(sync.resetCalls, 1);
      expect(find.text(unreadable), findsNothing);
      expect(find.text(explainer), findsOneWidget);
      await close(tester);
    });

    testWidgets('cancel does nothing', (tester) async {
      await pumpScreen(tester, status: SyncStatus.keysUnreadable);
      await tester.tap(find.text('Reset sync'));
      await pumpFrames(tester);
      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(sync.resetCalls, 0);
      expect(find.text(unreadable), findsOneWidget);
      await close(tester);
    });
  });

  group('Sync now', () {
    testWidgets('shows a spinner while it runs, then the result',
        (tester) async {
      sync.syncReached = 2;
      sync.syncGate = Completer<void>();
      await pumpScreen(tester);
      expect(find.text('Not synced yet since the app opened'), findsOneWidget);

      await tester.tap(find.text('Sync now'));
      await tester.pump();
      expect(sync.syncNowCalls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      sync.syncGate!.complete();
      await pumpFrames(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Synced just now with 2 devices'), findsOneWidget);
      await close(tester);
    });

    testWidgets('one device and none found', (tester) async {
      sync.syncReached = 1;
      await pumpScreen(tester);
      await tester.tap(find.text('Sync now'));
      await pumpFrames(tester);
      expect(find.text('Synced just now with 1 device'), findsOneWidget);

      sync.syncReached = 0;
      await tester.tap(find.text('Sync now'));
      await pumpFrames(tester);
      expect(
          find.text(
              'Last tried just now: no linked devices found on this Wi-Fi'),
          findsOneWidget);
      await close(tester);
    });

    testWidgets('relative time advances with the clock', (tester) async {
      sync.lastSyncNotifier.value = LastSync(clockNow, 1);
      await pumpScreen(tester);
      expect(find.text('Synced just now with 1 device'), findsOneWidget);
      clockNow = clockNow.add(const Duration(minutes: 3, seconds: 5));
      await tester.pump(const Duration(minutes: 3, seconds: 5));
      expect(find.text('Synced 3 min ago with 1 device'), findsOneWidget);

      sync.lastSyncNotifier.value =
          LastSync(clockNow.subtract(const Duration(minutes: 5)), 0);
      await tester.pump();
      expect(
          find.text(
              'Last tried 5 min ago: no linked devices found on this Wi-Fi'),
          findsOneWidget);
      await close(tester);
    });

    testWidgets('the Mac line shows only with the flag', (tester) async {
      const line =
          'A Mac reaches your phone only while Diegema is open or playing on the phone.';
      await pumpScreen(tester, mac: false);
      expect(find.text(line), findsNothing);
      await close(tester);
      await pumpScreen(tester, mac: true);
      expect(find.text(line), findsOneWidget);
      await close(tester);
    });
  });

  group('Remove', () {
    testWidgets('confirm forgets that device', (tester) async {
      await pumpScreen(tester);
      await show(tester, find.byTooltip('Remove Desk PC'));
      await tester.tap(find.byTooltip('Remove Desk PC'));
      await pumpFrames(tester);
      expect(find.text('Remove Desk PC?'), findsOneWidget);
      expect(find.textContaining('unlink all your devices'), findsOneWidget);
      expect(sync.forgotten, isEmpty);
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await pumpFrames(tester);
      expect(sync.forgotten, ['pc']);
      await close(tester);
    });

    testWidgets('cancel does nothing', (tester) async {
      await pumpScreen(tester);
      await show(tester, find.byTooltip('Remove Desk PC'));
      await tester.tap(find.byTooltip('Remove Desk PC'));
      await pumpFrames(tester);
      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(sync.forgotten, isEmpty);
      await close(tester);
    });
  });

  group('Unlink', () {
    testWidgets('confirm unlinks and the screen becomes unlinked',
        (tester) async {
      sync.linked = true;
      await pumpScreen(tester);
      await tapText(tester, 'Unlink this device');
      expect(find.textContaining('forgets your other devices'), findsOneWidget);
      expect(sync.unlinkCalls, 0);
      await tester.tap(find.widgetWithText(TextButton, 'Unlink'));
      await pumpFrames(tester);
      expect(sync.unlinkCalls, 1);
      expect(find.text('Sync now'), findsNothing);
      await close(tester);
    });

    testWidgets('cancel does nothing', (tester) async {
      await pumpScreen(tester);
      await tapText(tester, 'Unlink this device');
      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(sync.unlinkCalls, 0);
      await tester.scrollUntilVisible(find.text('Sync now'), -100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Sync now'), findsOneWidget);
      await close(tester);
    });
  });

  group('no overflow at 2.0 text on 360x800', () {
    for (final status in [SyncStatus.linked, SyncStatus.keysUnreadable]) {
      testWidgets(status.name, (tester) async {
        sync.lastSyncNotifier.value = LastSync(DateTime.now(), 0);
        await pumpScreen(tester, status: status, textScale: 2.0, mac: true);
        expect(tester.takeException(), isNull);
        final list = find.byType(Scrollable).first;
        await tester.drag(list, const Offset(0, -3000));
        await pumpFrames(tester);
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }
  });
}
