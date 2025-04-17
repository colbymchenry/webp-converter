#!/usr/bin/env bash

# ─── 1️⃣ Ensure Homebrew is installed ─────────────────────────────────────────
if ! command -v brew &> /dev/null; then
  cat <<EOF
⚠️  Homebrew is not installed.
   Homebrew is required to install the WebP tools automatically.
   Install it here: https://brew.sh
   Then re‑run this script.
EOF
  exit 1
fi

# ─── 2️⃣ Check for webp/cwebp, install if missing ─────────────────────────────
if ! command -v webp &> /dev/null && ! command -v cwebp &> /dev/null; then
  read -r -p "'webp' tool not found. Install via Homebrew now? [Y/n] " response
  response=${response:-Y}
  if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Installing WebP tools with Homebrew..."
    brew install webp
  else
    echo "❌  'webp' is required for conversion. Exiting."
    exit 1
  fi
fi

# ─── 3️⃣ If only cwebp exists, symlink it to webp ─────────────────────────────
if ! command -v webp &> /dev/null && command -v cwebp &> /dev/null; then
  echo "Creating 'webp' alias to 'cwebp' in $(brew --prefix)/bin"
  ln -sf "$(command -v cwebp)" "$(brew --prefix)/bin/webp"
fi

# ─── 4️⃣ Decide which command to use ──────────────────────────────────────────
if command -v webp &> /dev/null; then
  CMD=webp
elif command -v cwebp &> /dev/null; then
  CMD=cwebp
else
  echo "❌  Neither 'webp' nor 'cwebp' is available. Exiting."
  exit 1
fi

# ─── 5️⃣ Define directories ───────────────────────────────────────────────────
MEDIA_DIR="media"
OUTPUT_DIR="media_webp"

if [ ! -d "$MEDIA_DIR" ]; then
  echo "❌  Source directory '$MEDIA_DIR' not found. Exiting."
  exit 1
fi
mkdir -p "$OUTPUT_DIR"

# ─── 6️⃣ Enable globbing ───────────────────────────────────────────────────────
shopt -s nullglob

# ─── 7️⃣ Loop and convert ─────────────────────────────────────────────────────
for img in "$MEDIA_DIR"/*.{jpg,jpeg,png}; do
  filename="$(basename "${img%.*}")"
  extension="${img##*.}"
  # lowercase the extension in a Bash‑3‑compatible way
  ext="$(echo "$extension" | tr '[:upper:]' '[:lower:]')"
  target="$OUTPUT_DIR/${filename}.webp"

  echo "🔄 Converting '$img' → '$target'"
  if [ "$ext" = "png" ]; then
    # lossless for PNGs
    $CMD -lossless -z 9 "$img" -o "$target"
  else
    # optimized lossy for JPEGs
    $CMD -q 85 -m 6 -pass 10 -mt "$img" -o "$target"
  fi
done

echo "✅  Conversion complete. WebP files are in '$OUTPUT_DIR/'."
