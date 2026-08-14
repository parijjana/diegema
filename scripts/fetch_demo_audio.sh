#!/usr/bin/env bash
# Downloads the chapter MP3s for the PLAYABLE books in the web demo's
# curated catalog (assets/demo/catalog.json) from archive.org into
# demo_audio/ (gitignored — review before uploading).
#
# This script does NOT deploy anything anywhere. It is intentionally a
# separate, manual step: uploading the downloaded files to Cloudflare (or
# wherever the demo is hosted) is the user's call, with their own
# credentials — see rework_plan.md's "Demo build approach".
#
# Usage:
#   scripts/fetch_demo_audio.sh
#
# After running, point the web build at wherever you host these files:
#   flutter build web --release --dart-define=DEMO_MODE=true \
#     --dart-define=DEMO_AUDIO_BASE=https://your-site.example/audio/
#
# ...or leave DEMO_AUDIO_BASE unset and copy demo_audio/*/*.mp3 flat into
# an `audio/` folder next to the deployed site (the default is a relative
# `./audio/` path).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG="$PROJECT_ROOT/assets/demo/catalog.json"
OUT_DIR="$PROJECT_ROOT/demo_audio"

if [[ ! -f "$CATALOG" ]]; then
  echo "error: $CATALOG not found" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required (used to parse catalog.json)" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# Emit "<archive-id>\t<filename>" for every chapter of every playable book.
python3 - "$CATALOG" <<'PYEOF' > "$OUT_DIR/.manifest.tsv"
import json, sys
with open(sys.argv[1]) as fh:
    catalog = json.load(fh)
for book in catalog.get("books", []):
    if not book.get("playable"):
        continue
    for ch in book.get("chapters", []):
        print(f"{book['id']}\t{ch['filename']}")
PYEOF

total_files=0
total_bytes=0

while IFS=$'\t' read -r id filename; do
  [[ -z "$id" ]] && continue
  dest_dir="$OUT_DIR/$id"
  dest_file="$dest_dir/$filename"
  mkdir -p "$dest_dir"

  url="https://archive.org/download/$id/$filename"

  # Downloads land in a .part file and are only moved into place once curl
  # reports success, so an interrupted transfer can never leave a truncated
  # file that the skip check below would then treat as complete. archive.org
  # resets mid-stream often enough that this is not theoretical — it happened
  # on 2026-08-14 and left a 5.4MB fragment of a 6.6MB chapter looking done.
  #
  # `-C -` resumes an existing fragment rather than restarting from zero,
  # which matters on the larger chapters.
  part_file="$dest_file.part"

  if [[ -f "$dest_file" ]]; then
    echo "skip (already downloaded): $id/$filename"
  else
    echo "downloading: $url"
    # --retry-all-errors so a connection reset is retried, not just the
    # transient HTTP statuses curl retries by default.
    curl -fL -C - --retry 5 --retry-delay 2 --retry-all-errors \
      -o "$part_file" "$url"
    mv "$part_file" "$dest_file"
  fi

  total_files=$((total_files + 1))
  size=$(stat -f%z "$dest_file" 2>/dev/null || stat -c%s "$dest_file" 2>/dev/null || echo 0)
  total_bytes=$((total_bytes + size))
done < "$OUT_DIR/.manifest.tsv"

rm -f "$OUT_DIR/.manifest.tsv"

total_mb=$(python3 -c "print(f'{$total_bytes / 1024 / 1024:.2f}')")
echo ""
echo "Downloaded $total_files file(s), ${total_mb} MB total, into $OUT_DIR/"
echo ""
echo "Next steps:"
echo "  1. Review the files in $OUT_DIR/ (organized by archive.org identifier)."
echo "  2. Upload them to wherever the demo site's audio will live (e.g. a"
echo "     Cloudflare Pages/R2 bucket alongside the site) — that upload step"
echo "     is manual and uses your own Cloudflare credentials."
echo "  3. Rebuild with --dart-define=DEMO_AUDIO_BASE=<that URL>, or copy the"
echo "     files flat into an audio/ folder next to the deployed build/web"
echo "     output if you're keeping the default relative ./audio/ path."
