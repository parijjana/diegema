#!/usr/bin/env bash
# Run a flutter command with assets/demo/** bundled. Store builds leave the demo
# assets out (see pubspec.yaml); the screenshot harness needs them.
#
#   tool/with_demo_assets.sh flutter run -d macos -t lib/screenshot_main.dart --dart-define=DEMO_MODE=true
#
# pubspec.yaml is edited for the duration of the command and always restored.
set -euo pipefail
cd "$(dirname "$0")/.."
[ $# -gt 0 ] || { echo "usage: $0 <flutter command...>" >&2; exit 2; }
backup="${TMPDIR:-/tmp}/diegema_pubspec.backup.$$"
cp pubspec.yaml "$backup"
restore() { cp "$backup" pubspec.yaml; rm -f "$backup"; }
trap restore EXIT INT TERM
awk '{print} /^  assets:$/ {print "    - assets/demo/catalog.json"; print "    - assets/demo/covers/"}' \
  "$backup" > pubspec.yaml
"$@"
