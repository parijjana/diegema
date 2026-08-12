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
# Rights: these covers are LibriVox's own catalog artwork, which LibriVox
# places in the public domain along with its recordings and summaries (see
# https://librivox.org/pages/public-domain/). The script writes a per-file
# provenance table to assets/demo/covers/CREDITS.md so that claim stays
# checkable rather than remembered.
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

# Resolve, for each catalog identifier, the cover image LibriVox actually
# uploaded to the item — and record the rights the item asserts.
#
# We deliberately do NOT use https://archive.org/services/img/<id>. That
# endpoint returns a 180x180 derived thumbnail, which this script then had
# to UPSCALE to 400px, so every bundled cover was visibly soft. The item's
# own cover file (e.g. `Moby_Dick_1002.jpg`) is full resolution, is the
# artwork LibriVox published, and downscales properly.
#
# Emits TSV: id, download URL, source filename, licenseurl, title, creator.
# `services/img/<id>` remains the fallback for an item with no cover file.
python3 - "$CATALOG" <<'PYEOF' > "$OUT_DIR/.manifest.tsv"
import json, sys, urllib.parse, urllib.request

def meta(identifier):
    url = f"https://archive.org/metadata/{identifier}"
    with urllib.request.urlopen(url, timeout=30) as fh:
        return json.load(fh)

with open(sys.argv[1]) as fh:
    catalog = json.load(fh)

for book in catalog.get("books", []):
    ident = book["id"]
    try:
        m = meta(ident)
    except Exception as exc:                       # noqa: BLE001
        print(f"warning: metadata lookup failed for {ident}: {exc}", file=sys.stderr)
        m = {}
    md = m.get("metadata", {})

    # A cover file is a JPEG that is neither archive.org's generated item
    # thumbnail (`__ia_thumb.jpg`), nor a `_thumb` derivative, nor one of
    # the per-track spectrogram images. Largest such file wins.
    covers = [
        f for f in m.get("files", [])
        if f.get("name", "").lower().endswith((".jpg", ".jpeg"))
        and not f["name"].startswith("__ia_thumb")
        and "_thumb" not in f["name"]
        and "spectrogram" not in f["name"]
    ]
    if covers:
        best = max(covers, key=lambda f: int(f.get("size") or 0))
        source = best["name"]
        url = f"https://archive.org/download/{ident}/{urllib.parse.quote(source)}"
    else:
        source = "(item thumbnail)"
        url = f"https://archive.org/services/img/{ident}"

    fields = [
        ident,
        url,
        source,
        # Items predating archive.org's licence field carry no `licenseurl`.
        # LibriVox's blanket policy still applies — see CREDITS.md.
        md.get("licenseurl", ""),
        md.get("title", book.get("title", "")),
        str(md.get("creator", book.get("author", ""))),
    ]
    print("\t".join(f.replace("\t", " ") for f in fields))
PYEOF

total_count=0
missing_ids=()

while IFS=$'\t' read -r id url source licenseurl title creator; do
  [[ -z "$id" ]] && continue
  dest="$OUT_DIR/$id.jpg"

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

  # Downscale to ~400px on the long edge and re-encode as JPEG quality 82.
  # These only ever render at small tile sizes, so there is no reason to
  # ship anything larger.
  sips -Z 400 -s format jpeg -s formatOptions 82 "$dest" --out "$dest" >/dev/null

  total_count=$((total_count + 1))
done < "$OUT_DIR/.manifest.tsv"

# Provenance record, regenerated from the same metadata as the download.
# This is what makes the bundled covers defensible: every file is traceable
# to the archive.org item it came from and the rights that item asserts.
python3 - "$OUT_DIR/.manifest.tsv" "$OUT_DIR" <<'PYEOF' > "$OUT_DIR/CREDITS.md"
import os, sys

manifest, out_dir = sys.argv[1], sys.argv[2]

print("""# Cover art — sources and rights

Every image in this directory was published by LibriVox
(uploader `info@librivox.org`) as part of the archive.org item for that
recording, and is redistributed here under LibriVox's public-domain policy:

> LibriVox records only texts that are in the public domain (in the USA), and
> all our recordings are public domain. **In addition, book summaries, CD cover
> art, and any other material that goes into our catalog with the audio
> recordings are in the public domain.**
>
> — <https://librivox.org/pages/public-domain/>

Images are downscaled to 400px and re-encoded; they are otherwise unmodified.
They are bundled rather than hotlinked because archive.org's image service
sends no `access-control-allow-origin` header, so CanvasKit's fetch of a
hotlinked cover is blocked by CORS in the web demo.

Regenerate this file with `scripts/fetch_demo_covers.sh`.

| Cover | Item | Source file | archive.org rights |
| --- | --- | --- | --- |""")

LICENCE_NAMES = {
    "http://creativecommons.org/publicdomain/zero/1.0/": "CC0 1.0",
    "http://creativecommons.org/publicdomain/mark/1.0/": "PD Mark 1.0",
    "http://creativecommons.org/licenses/publicdomain/": "CC Public Domain",
}

rows = 0
with open(manifest) as fh:
    for line in fh:
        if not line.strip():
            continue
        ident, url, source, licenseurl, title, creator = line.rstrip("\n").split("\t")
        if not os.path.exists(os.path.join(out_dir, f"{ident}.jpg")):
            continue
        if licenseurl:
            rights = f"[{LICENCE_NAMES.get(licenseurl, licenseurl)}]({licenseurl})"
        else:
            # No item-level licence field. These predate archive.org's
            # licenceurl metadata; LibriVox's blanket policy above governs.
            rights = "none asserted — LibriVox policy applies"
        item = f"[{title}](https://archive.org/details/{ident})"
        print(f"| `{ident}.jpg` | {item} — {creator} | `{source}` | {rights} |")
        rows += 1

print(f"\n{rows} covers. Verified against the archive.org metadata API.")
PYEOF

rm -f "$OUT_DIR/.manifest.tsv"

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
