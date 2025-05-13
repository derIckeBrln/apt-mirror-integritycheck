#!/bin/bash

set -euo pipefail

MIRROR_DIR="/data/apt-mirror/mirror/archive.ubuntu.com/ubuntu"
MIRROR_LIST="/etc/apt/mirror.list"
FIX_MODE=false
CHANGES_MADE=false

# Parse optional flag
if [[ "${1:-}" == "--fix" ]]; then
  FIX_MODE=true
fi

echo "🔍 Starting mirror check in: $MIRROR_DIR"
echo "📄 Reading: $MIRROR_LIST"

# 1. Read configured distributions and components
mapfile -t DEB_LINES < <(grep -E '^deb\s+' "$MIRROR_LIST" | grep -v '://security.ubuntu.com')

declare -A VALID_PATHS

for line in "${DEB_LINES[@]}"; do
  release=$(echo "$line" | awk '{print $3}')
  components=$(echo "$line" | cut -d' ' -f4-)
  for comp in $components; do
    for arch in amd64 i386; do
      VALID_PATHS["$release/$comp/binary-$arch"]=1
    done
  done
done

# 2. Loop through top-level Release files only
find "$MIRROR_DIR/dists" -mindepth 1 -maxdepth 1 -type d | while read -r distdir; do
  release_file="$distdir/Release"
  [[ -f "$release_file" ]] || continue

  relname=$(basename "$distdir")
  echo -e "\n📁 Checking: $relname"

  grep -E 'Packages(\.gz|\.xz|\.bz2)?$' "$release_file" | while read -r line; do
    size=$(echo "$line" | awk '{print $1}')
    sha256=$(echo "$line" | awk '{print $2}')
    relpath=$(echo "$line" | awk '{print $3}')
    relbase=$(dirname "$relpath")

    if [[ -z "${VALID_PATHS[$relbase]:-}" ]]; then
      continue
    fi

    filepath="$MIRROR_DIR/$relpath"
    if [[ ! -f "$filepath" ]]; then
      echo "⚠️  Missing: $relpath"
      continue
    fi

    actual_size=$(stat -c %s "$filepath" 2>/dev/null || echo 0)
    actual_hash=$(sha256sum "$filepath" 2>/dev/null | awk '{print $1}')

    if [[ "$actual_size" != "$size" || "$actual_hash" != "$sha256" ]]; then
      echo "❌ Corrupted: $relpath"
      echo "    Expected: Size=$size  SHA256=$sha256"
      echo "    Actual:   Size=$actual_size  SHA256=$actual_hash"

      if [[ "$FIX_MODE" = true ]]; then
        echo "    → Deleting: $filepath"
        rm -f "$filepath"
        CHANGES_MADE=true
      else
        echo "    → (Tip: use --fix to automatically remove broken files)"
      fi
    else
      echo "✅ OK: $relpath"
    fi
  done
done

# 3. Trigger apt-mirror if needed
if [[ "$FIX_MODE" = true && "$CHANGES_MADE" = true ]]; then
  echo -e "\n♻️  Changes applied — running apt-mirror to resync..."
  apt-mirror
else
  echo -e "\n✅ Mirror check complete — no repair needed."
fi
