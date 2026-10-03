import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:diegema/screens/linked_devices_screen.dart';
import 'package:diegema/services/sync/sync_controller.dart';
import 'package:diegema/sync/sync_record.dart';
import 'package:diegema/theme/app_theme.dart';

import '../helpers/fake_sync_controller.dart';
import '../support/test_harness.dart';

void main() {
  late FakeSyncController sync;

  // Built in setUp (the real zone), as the FakeAsync lesson asks.
  setUp(() {
    sync = FakeSyncController();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    bool pollForScanner = false,
    double textScale = 1.0,
    Brightness brightness = Brightness.light,
  }) async {
    await setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(SyncScope(
      controller: sync,
      child: MaterialApp(
        theme:
            brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!),
        home: LinkedDevicesScreen(pollForScanner: pollForScanner),
      ),
    ));
    await pumpFrames(tester);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Link a device'), 100,
        scrollable: find.byType(Scrollable).first);
    await pumpFrames(tester);
    await tester.tap(find.text('Link a device'));
    await pumpFrames(tester);
  }

  /// Closes everything so the sheet's timers are cancelled.
  Future<void> close(WidgetTester tester) => unmount(tester);

  testWidgets('sheet shows a QR, the code, a countdown and the steps',
      (tester) async {
    await pumpScreen(tester);
    await openSheet(tester);

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('DIEGEMALINK1.fake'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.textContaining('Good for 4:'), findsOneWidget);
    expect(find.textContaining('Scan a code.'), findsOneWidget);
    await close(tester);
  });

  testWidgets('QR also renders in the dark theme', (tester) async {
    await pumpScreen(tester, brightness: Brightness.dark);
    await openSheet(tester);
    expect(find.byType(QrImageView), findsOneWidget);
    await close(tester);
  });

  testWidgets('Copy marks itself copied', (tester) async {
    await pumpScreen(tester);
    await openSheet(tester);
    await tester.tap(find.text('Copy'));
    await pumpFrames(tester);
    expect(find.text('Copied'), findsOneWidget);
    await close(tester);
  });

  testWidgets('countdown runs out and offers a new code', (tester) async {
    await pumpScreen(tester);
    await openSheet(tester);
    await tester.pump(const Duration(minutes: 5, seconds: 2));
    expect(find.text('Show a new code'), findsOneWidget);
    await tester.tap(find.text('Show a new code'));
    await pumpFrames(tester);
    expect(find.textContaining('Good for'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a failing offer says linking is not available', (tester) async {
    sync.offerFails = true;
    await pumpScreen(tester);
    await openSheet(tester);
    expect(find.text("Linking isn't available on this device right now."),
        findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await close(tester);
  });

  testWidgets('"Linked to <name>" appears when a new device shows up',
      (tester) async {
    await pumpScreen(tester);
    await openSheet(tester);
    expect(find.textContaining('Linked to'), findsNothing);

    sync.setRecords([
      rec(SyncKind.device, 'mac', 'mac', 1, {'name': 'MacBook'}),
    ]);
    await pumpFrames(tester);

    expect(find.text('Linked to MacBook'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await pumpFrames(tester);
    expect(find.text('Linked to MacBook'), findsNothing);
    await close(tester);
  });

  testWidgets('a device that was already linked is not "new"', (tester) async {
    sync.setRecords([
      rec(SyncKind.device, 'mac', 'mac', 1, {'name': 'MacBook'}),
    ]);
    await pumpScreen(tester);
    await openSheet(tester);
    sync.setRecords([
      rec(SyncKind.device, 'mac', 'mac', 1, {'name': 'MacBook'}),
      rec(SyncKind.device, 'pc', 'pc', 2, {'name': 'Desk PC'}),
    ]);
    await pumpFrames(tester);
    expect(find.text('Linked to Desk PC'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a Mac dials the scanner every 3 seconds while open',
      (tester) async {
    await pumpScreen(tester, pollForScanner: true);
    await openSheet(tester);
    final start = sync.syncNowCalls;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(sync.syncNowCalls - start, 2);

    await close(tester);
    final after = sync.syncNowCalls;
    await tester.pump(const Duration(seconds: 9));
    expect(sync.syncNowCalls, after);
  });

  testWidgets('a Mac stops dialling once the code has expired', (tester) async {
    await pumpScreen(tester, pollForScanner: true);
    await openSheet(tester);
    await tester.pump(const Duration(minutes: 5, seconds: 2));
    final atExpiry = sync.syncNowCalls;
    await tester.pump(const Duration(seconds: 9));
    expect(sync.syncNowCalls, atExpiry);
    await close(tester);
  });

  testWidgets('without the flag nothing is dialled', (tester) async {
    await pumpScreen(tester);
    await openSheet(tester);
    await tester.pump(const Duration(seconds: 9));
    expect(sync.syncNowCalls, 0);
    await close(tester);
  });

  testWidgets('no overflow at 2.0 text scale: screen and sheet',
      (tester) async {
    sync.canScan = true;
    await pumpScreen(tester, textScale: 2.0);
    expect(tester.takeException(), isNull);
    await openSheet(tester);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(minutes: 5, seconds: 2));
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  group('actions', () {
    testWidgets('Scan a code is hidden when the device cannot scan',
        (tester) async {
      await pumpScreen(tester);
      expect(find.text('Link a device'), findsOneWidget);
      expect(find.text('Paste a code'), findsOneWidget);
      expect(find.text('Scan a code'), findsNothing);
      await close(tester);
    });

    testWidgets('Scan a code shows on phones', (tester) async {
      sync.canScan = true;
      await pumpScreen(tester);
      expect(find.text('Scan a code'), findsOneWidget);
      await close(tester);
    });

    Future<void> paste(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(find.text('Paste a code'), 100,
          scrollable: find.byType(Scrollable).first);
      await pumpFrames(tester);
      await tester.tap(find.text('Paste a code'));
      await pumpFrames(tester);
      await tester.enterText(find.byType(TextField).last, text);
      await pumpFrames(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Link'));
      await pumpFrames(tester);
    }

    final messages = {
      JoinOutcome.linked: "Linked. Your devices will keep each other's place.",
      JoinOutcome.linkedNotSynced:
          "Linked. They'll sync when both are open on the same Wi-Fi.",
      JoinOutcome.invalid: "That isn't a Diegema link code.",
      JoinOutcome.expired:
          'That code has expired. Show a new one on the other device.',
    };
    for (final e in messages.entries) {
      testWidgets('pasting: ${e.key.name} says its message', (tester) async {
        sync.joinOutcome = e.key;
        await pumpScreen(tester);
        await paste(tester, '  DIEGEMALINK1.abc ');
        expect(sync.lastJoinCode, 'DIEGEMALINK1.abc');
        expect(find.text(e.value), findsOneWidget);
        await close(tester);
      });
    }

    testWidgets('other group: confirm, then join again replacing it',
        (tester) async {
      sync.joinOutcome = JoinOutcome.otherGroup;
      await pumpScreen(tester);
      await paste(tester, 'DIEGEMALINK1.abc');
      expect(
          find.text(
              'This device is already linked to other devices. Switch to the new ones?'),
          findsOneWidget);
      expect(sync.joins, [('DIEGEMALINK1.abc', false)]);

      await tester.tap(find.text('Switch'));
      await pumpFrames(tester);
      expect(sync.joins.last, ('DIEGEMALINK1.abc', true));
      expect(sync.joins.length, 2);
      expect(find.text("Linked. Your devices will keep each other's place."),
          findsOneWidget);
      await close(tester);
    });

    testWidgets('other group: declining does not join again', (tester) async {
      sync.joinOutcome = JoinOutcome.otherGroup;
      await pumpScreen(tester);
      await paste(tester, 'DIEGEMALINK1.abc');
      await tester.tap(find.text('Keep current'));
      await pumpFrames(tester);
      expect(sync.joins.length, 1);
      await close(tester);
    });

    testWidgets('no overflow in the paste dialog at 2.0 text scale',
        (tester) async {
      sync.joinOutcome = JoinOutcome.expired;
      await pumpScreen(tester, textScale: 2.0);
      await paste(tester, 'DIEGEMALINK1.abc');
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  });
}
