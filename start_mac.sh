#!/usr/bin/env bash

# 1️⃣ Ensure Homebrew is installed
if ! command -v brew &> /dev/null; then
  cat <<EOF
⚠️  Homebrew not found on your system.
   Homebrew is required to install the WebP tools automatically.
   Please install Homebrew first by following the instructions here:
     https://brew.sh
   Then re‑run this script.
EOF
  exit 1
fi

# 2️⃣ Check for webp (WebP tools)
if ! command -v webp &> /dev/null; then
  read -r -p "The 'webp' tool is not installed. Install via Homebrew now? [Y/n] " response
  response=${response:-Y}
  if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Installing WebP tools with Homebrew..."
    brew install webp

    # verify installation
    if ! command -v webp &> /dev/null; then
      echo "❌  Failed to install 'webp'. Please install it manually and rerun."
      exit 1
    fi
  else
    echo "❌  'webp' is required for conversion. Exiting."
    exit 1
  fi
fi

# 3️⃣ Define source and destination directories
MEDIA_DIR="media"
OUTPUT_DIR="media_webp"

if [ ! -d "$MEDIA_DIR" ]; then
  echo "❌  Source directory '$MEDIA_DIR' not found. Exiting."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# 4️⃣ Enable globbing for multiple extensions
shopt -s nullglob

# 5️⃣ Loop through images in media/
for img in "$MEDIA_DIR"/*.{jpg,jpeg,png}; do
  filename="$(basename "${img%.*}")"
  extension="${img##*.}"
  target="$OUTPUT_DIR/${filename}.webp"

  echo "🔄 Converting '$img' → '$target'"

  if [[ "${extension,,}" == "png" ]]; then
    # lossless for PNGs
    webp -lossless -z 9 "$img" -o "$target"
  else
    # optimized lossy for JPEGs
    webp -q 85 -m 6 -pass 10 -mt "$img" -o "$target"
  fi
done

echo "✅  Conversion complete. WebP files are in '$OUTPUT_DIR/'."
