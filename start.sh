#!/usr/bin/env bash

# 1️⃣ Ensure Chocolatey is installed
if ! command -v choco &> /dev/null; then
  cat <<EOF
⚠️  Chocolatey not found on your system.
   Chocolatey is required to install the WebP tools automatically.
   Please install Chocolatey first by following the instructions here:
     https://chocolatey.org/install
   Then re-run this script.
EOF
  exit 1
fi

# 2️⃣ Check for cwebp (WebP tools)
if ! command -v cwebp &> /dev/null; then
  read -r -p "cwebp is not installed. Install via Chocolatey now? [Y/n] " response
  response=${response:-Y}
  if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Installing WebP tools with Chocolatey..."
    choco install webp -y
    if ! command -v cwebp &> /dev/null; then
      echo "❌  Failed to install cwebp. Please install it manually and rerun."
      exit 1
    fi
  else
    echo "❌  cwebp is required for conversion. Exiting."
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
    cwebp -lossless -z 9 "$img" -o "$target"
  else
    cwebp -q 85 -m 6 -pass 10 -mt "$img" -o "$target"
  fi
done

echo "✅  Conversion complete. WebP files are in '$OUTPUT_DIR/'."
