# Parked: device sync, v1.1

v1 has no sync (owner decision 2026-10-25, PR #41 flag). To keep v1 binaries free of the
sync-only plugins (audit S-17, S-03) the code that needs them was moved here with `git mv`
(history kept). Nothing in this directory is compiled or depended on by the app.

The platform-independent sync core (`lib/sync/`, `lib/services/sync/sync_service_io.dart`,
the sync UI, `DIEGEMA_SYNC` flag) is still in `lib/`; it uses only `cryptography`
(pure Dart) and so adds no native plugin.

## What is here, and where it goes back

| Here | Restore to | Needs |
|---|---|---|
| `lib/services/sync/lan_platform_io.dart` | `lib/services/sync/` | `bonsoir: 7.1.5`, `flutter_secure_storage: ^10.3.4` |
| `lib/sync_cli/` (+ `bin/diegema_sync.dart`, `diegema-sync.sh/.ps1`) | `lib/sync_cli/`, `bin/`, `tool/` | `multicast_dns: ^0.3.3+1`, `args: ^2.7.0` |
| `test/sync_cli/` | `test/sync_cli/` | as above |

Also for v1.1:

1. Re-add the four dependencies above to `pubspec.yaml`, plus `qr_flutter: ^4.1.0`
   (and `mobile_scanner` if scanning returns; see the note in `lib/screens/scan_code_screen.dart`).
2. Restore `sync_controller_io.dart` to build `SyncService(db, secrets: platformSecretStore(),
   discovery: BonsoirPeerDiscovery(), listens: platformListens)`.
3. In `lib/screens/qr_code_view.dart` put back `QrImageView(data: data, padding: EdgeInsets.zero,
   backgroundColor: Colors.white, eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
   dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black))`.
4. Android manifest: nothing to add for bonsoir beyond its own merged `CHANGE_WIFI_MULTICAST_STATE`;
   iOS: restore `NSLocalNetworkUsageDescription` and `NSBonjourServices` (`_diegema._tcp`);
   macOS Release.entitlements: add `com.apple.security.network.server`.
5. Build with `--dart-define=DIEGEMA_SYNC=true`.
