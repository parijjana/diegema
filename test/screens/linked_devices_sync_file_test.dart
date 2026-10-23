import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:diegema/screens/linked_devices_screen.dart';
import 'package:diegema/services/sync/sync_controller.dart';
import 'package:diegema/services/sync/sync_file_picker.dart';
import 'package:diegema/sync/sync_file.dart';
import 'package:diegema/theme/app_theme.dart';

import '../helpers/fake_sync_controller.dart';
import '../support/test_harness.dart';

class _FakePicker extends SyncFilePicker {
  final saves = <(String, List<int>)>[];
  bool saveResult = true;
  PickedSyncFile? picked;
  int picks = 0;
  Completer<PickedSyncFile?>? pickGate;

  @override
  Future<bool> save(String fileName, List<int> bytes) async {
    saves.add((fileName, bytes));
    return saveResult;
  }

  @override
  Future<PickedSyncFile?> pick() async {
    picks++;
    final gate = pickGate;
    if (gate != null) return gate.future;
    return picked;
  }
}

void main() {
  late FakeSyncController sync;
  late _FakePicker picker;

  setUp(() {
    sync = FakeSyncController();
    picker = _FakePicker();
  });

  Future<void> pumpScreen(WidgetTester tester,
      {SyncStatus status = SyncStatus.linked, double textScale = 1.0}) async {
    sync.syncStatus = status;
    await setSurface(tester, const Size(360, 800));
    await tester.pumpWidget(SyncScope(
      controller: sync,
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!),
        home: LinkedDevicesScreen(pollForScanner: false, filePicker: picker),
      ),
    ));
    await pumpFrames(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 100,
        scrollable: find.byType(Scrollable).first);
    await pumpFrames(tester);
    await tester.tap(find.text(text));
    await pumpFrames(tester);
  }

  PickedSyncFile file(List<int> bytes, {int? size}) =>
      PickedSyncFile('a.diegemasync', size ?? bytes.length, bytes);

  testWidgets('hidden when unlinked', (tester) async {
    await pumpScreen(tester, status: SyncStatus.unlinked);
    expect(find.text('Export sync file'), findsNothing);
    expect(find.text('Import sync file'), findsNothing);
    await unmount(tester);
  });

  testWidgets('shown when linked, with the explanation', (tester) async {
    await pumpScreen(tester);
    await tester.scrollUntilVisible(find.text('Export sync file'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.scrollUntilVisible(find.text('Import sync file'), 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Import sync file'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('two Macs'), -100,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('two Macs'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('export saves the right name and bytes', (tester) async {
    await pumpScreen(tester);
    await tapText(tester, 'Export sync file');
    expect(sync.exportCalls, 1);
    expect(picker.saves.single.$1, 'diegema-this-phone-2026-10-04.diegemasync');
    expect(picker.saves.single.$2, [1, 2, 3]);
    expect(find.text('Saved diegema-this-phone-2026-10-04.diegemasync'),
        findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a cancelled save does nothing', (tester) async {
    picker.saveResult = false;
    await pumpScreen(tester);
    await tapText(tester, 'Export sync file');
    expect(picker.saves, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
    await unmount(tester);
  });

  testWidgets('an export failure shows a plain message', (tester) async {
    sync.exportResult = null;
    await pumpScreen(tester);
    await tapText(tester, 'Export sync file');
    expect(picker.saves, isEmpty);
    expect(find.text("Couldn't save the sync file."), findsOneWidget);
    await unmount(tester);
  });

  Future<void> outcome(WidgetTester tester, Object result, String message,
      {int? changed}) async {
    picker.picked = file([9, 9]);
    sync.importResult = result;
    await pumpScreen(tester);
    await tapText(tester, 'Import sync file');
    expect(sync.imports.single, [9, 9]);
    expect(find.text(message), findsOneWidget);
    await unmount(tester);
  }

  testWidgets('import: changed records', (tester) async {
    await outcome(tester, 5, 'Imported: 5 updates from the file');
  });
  testWidgets('import: one record', (tester) async {
    await outcome(tester, 1, 'Imported: 1 update from the file');
  });
  testWidgets('import: nothing new', (tester) async {
    await outcome(tester, 0, 'Nothing new in this file');
  });
  testWidgets('import: other group', (tester) async {
    await outcome(tester, const SyncFileError(SyncFileProblem.otherGroup),
        "This file is from a device that isn't linked to this one.");
  });
  testWidgets('import: damaged', (tester) async {
    await outcome(tester, const SyncFileError(SyncFileProblem.damaged),
        'This file was changed or damaged after it was exported.');
  });
  testWidgets('import: not a sync file', (tester) async {
    await outcome(tester, const SyncFileError(SyncFileProblem.notSyncFile),
        "This isn't a Diegema sync file.");
  });

  testWidgets('a cancelled pick does nothing', (tester) async {
    await pumpScreen(tester);
    await tapText(tester, 'Import sync file');
    expect(picker.picks, 1);
    expect(sync.imports, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    await unmount(tester);
  });

  testWidgets('an oversized file is refused without importing', (tester) async {
    picker.picked = file([1], size: SyncFile.maxBytes + 1);
    await pumpScreen(tester);
    await tapText(tester, 'Import sync file');
    expect(sync.imports, isEmpty);
    expect(find.textContaining('too big'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('shows progress and ignores a second tap while picking',
      (tester) async {
    picker.pickGate = Completer<PickedSyncFile?>();
    await pumpScreen(tester);
    await tester.scrollUntilVisible(find.text('Import sync file'), 100,
        scrollable: find.byType(Scrollable).first);
    await pumpFrames(tester);
    await tester.tap(find.text('Import sync file'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Import sync file'), warnIfMissed: false);
    await tester.tap(find.text('Export sync file'), warnIfMissed: false);
    await tester.pump();
    expect(picker.picks, 1);
    expect(sync.exportCalls, 0);
    picker.pickGate!.complete(null);
    await pumpFrames(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await unmount(tester);
  });

  testWidgets('no overflow at 2.0 text scale', (tester) async {
    await pumpScreen(tester, textScale: 2.0);
    await tester.scrollUntilVisible(find.text('Import sync file'), 100,
        scrollable: find.byType(Scrollable).first);
    await pumpFrames(tester);
    expect(find.text('Import sync file'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
