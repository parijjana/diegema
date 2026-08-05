#!/usr/bin/env bash
# Downloads the cover image for every book in the web demo's curated
# catalog (assets/demo/catalog.json) from archive.org's img service and
# bundles them locally as `assets/demo/covers/<identifier>.jpg`.
#
# Unlike scripts/fetch_demo_audio.sh, the output of THIS script IS meant
# to be committed. Covers are small (a handful of KB each after
# downscaling) and the demo must work standalone in a browser: CanvasKit
# fetches image bytes itself via XHR/fetch and archive.org's img service
# does not send an `access-control-allow-origin` header, so hotlinked
# covers are silently blocked by CORS on the deployed web demo. Bundling
# them as local assets sidesteps the problem entirely.
#
# This script only affects DEMO_MODE. The real (non-demo) app keeps
# fetching covers from archive.org over the network at runtime, same as
# always — bundling makes no sense there and native platforms have no
# CORS restriction to work around.
#
# Requires: curl, python3 (stdlib only), sips (macOS built-in).
#
# Usage:
#   scripts/fetch_demo_covers.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="$PROJECT_ROOT/assets/demo/catalog.json"
OUT_DIR="$PROJECT_ROOT/assets/demo/covers"

if [[ ! -f "$CATALOG" ]]; then
  echo "error: $CATALOG not found" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required (used to parse catalog.json)" >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "error: sips is required (macOS built-in image tool) to downscale covers" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# One archive.org identifier per line, in catalog order.
python3 - "$CATALOG" <<'PYEOF' > "$OUT_DIR/.manifest.txt"
import json, sys
with open(sys.argv[1]) as fh:
    catalog = json.load(fh)
for book in catalog.get("books", []):
    print(book["id"])
PYEOF

total_count=0
missing_ids=()

while IFS= read -r id; do
  [[ -z "$id" ]] && continue
  dest="$OUT_DIR/$id.jpg"
  url="https://archive.org/services/img/$id"

  echo "fetching: $url"
  if ! curl -fsL --retry 3 --retry-delay 2 -o "$dest" "$url"; then
    echo "  WARNING: download failed for $id — no cover will be bundled" >&2
    rm -f "$dest"
    missing_ids+=("$id")
    continue
  fi

  # Sanity check: archive.org returns 200 with an HTML error page for some
  # missing-cover cases instead of a real 404. Reject anything that isn't
  # actually an image before it gets bundled as one.
  if ! file "$dest" | grep -qi "image"; then
    echo "  WARNING: response for $id was not an image — discarding" >&2
    rm -f "$dest"
    missing_ids+=("$id")
    continue
  fi

  # Downscale to ~400px on the long edge (a no-op if already smaller) and
  # re-encode as JPEG quality 82. These only ever render at small tile
  # sizes, so there is no reason to ship anything larger.
  sips -Z 400 -s format jpeg -s formatOptions 82 "$dest" --out "$dest" >/dev/null

  total_count=$((total_count + 1))
done < "$OUT_DIR/.manifest.txt"

rm -f "$OUT_DIR/.manifest.txt"

total_bytes=0
for f in "$OUT_DIR"/*.jpg; do
  [[ -f "$f" ]] || continue
  size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null || echo 0)
  total_bytes=$((total_bytes + size))
done
total_kb=$(python3 -c "print(f'{$total_bytes / 1024:.1f}')")

echo ""
echo "Bundled $total_count cover(s), ${total_kb} KB total, into $OUT_DIR/"
if [[ ${#missing_ids[@]} -gt 0 ]]; then
  echo ""
  echo "No cover available for ${#missing_ids[@]} identifier(s) — the app's"
  echo "existing placeholder cover will be used for these in the demo:"
  for id in "${missing_ids[@]}"; do
    echo "  - $id"
  done
fi
