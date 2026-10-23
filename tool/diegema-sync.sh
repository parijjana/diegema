#!/bin/sh
# diegema-sync: builds the CLI on first use (or when its sources change),
# then runs it. Usage: tool/diegema-sync.sh <status|devices|log|peers|sync> [options]
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
exe="$root/build/diegema-sync-cli/bundle/bin/diegema_sync"
if [ ! -x "$exe" ] || [ -n "$(find "$root/bin" "$root/lib/sync" "$root/lib/sync_cli" "$root/lib/database" "$root/pubspec.lock" -newer "$exe" 2>/dev/null | head -1)" ]; then
  (cd "$root" && dart build cli -t bin/diegema_sync.dart -o build/diegema-sync-cli >/dev/null)
fi
exec "$exe" "$@"
