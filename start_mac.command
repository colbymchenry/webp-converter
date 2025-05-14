#!/usr/bin/env bash

# ─── Make the script run from its own directory ───────────────────────────────
# this ensures all relative paths (like "media/") resolve next to the .command
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"


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

# Ask user for maximum file size in KB
read -r -p "Enter maximum file size per image in KB (e.g., 100 for 100KB): " MAX_SIZE_KB
if ! [[ "$MAX_SIZE_KB" =~ ^[0-9]+$ ]]; then
  echo "❌  Invalid input. Please enter a number. Exiting."
  exit 1
fi

# Convert to bytes
MAX_SIZE_BYTES=$((MAX_SIZE_KB * 1024))
echo "🎯 Target maximum file size: ${MAX_SIZE_KB}KB (${MAX_SIZE_BYTES} bytes)"

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
  
  # Get original file size
  original_size=$(stat -f%z "$img")
  echo "📊 Original size: $(( original_size / 1024 ))KB"
  
  # Initial quality settings
  if [ "$ext" = "png" ]; then
    quality_param="-lossless -z 9"
    min_quality=75  # Minimum quality before switching to lossy
  else
    quality=80
    quality_param="-q $quality"
    min_quality=30  # Don't go below this quality
  fi
  
  # Try compression with progressive quality reduction
  attempt=1
  max_attempts=10
  
  while [ $attempt -le $max_attempts ]; do
    echo "  ↳ Attempt $attempt with $quality_param"
    
    if [ "$ext" = "png" ] && [ $attempt -eq 1 ]; then
      # First attempt for PNG with lossless
      $CMD $quality_param -m 6 "$img" -o "$target"
    elif [ "$ext" = "png" ] && [ $attempt -eq 2 ]; then
      # Second attempt for PNG with near-lossless
      quality=90
      $CMD -near_lossless $quality -m 6 "$img" -o "$target"
      quality_param="-near_lossless $quality"
    elif [ "$ext" = "png" ]; then
      # Subsequent attempts for PNG with lossy
      quality=$((quality - 10))
      if [ $quality -lt $min_quality ]; then
        quality=$min_quality
      fi
      $CMD -q $quality -m 6 -sharp_yuv -af "$img" -o "$target"
      quality_param="-q $quality"
    else
      # JPEG compression
      $CMD $quality_param -m 6 -pass 10 -mt -af -sharp_yuv "$img" -o "$target"
      quality=$((quality - 10))
      if [ $quality -lt $min_quality ]; then
        quality=$min_quality
      fi
      quality_param="-q $quality"
    fi
    
    # Check file size
    webp_size=$(stat -f%z "$target")
    echo "  ↳ Current size: $(( webp_size / 1024 ))KB"
    
    if [ $webp_size -le $MAX_SIZE_BYTES ]; then
      echo "✅ Target size achieved on attempt $attempt"
      break
    fi
    
    if [ $quality -le $min_quality ] && ([ "$ext" != "png" ] || [ $attempt -gt 2 ]); then
      echo "⚠️  Reached minimum quality but still above target size"
      break
    fi
    
    attempt=$((attempt + 1))
    
    if [ $attempt -gt $max_attempts ]; then
      echo "⚠️  Maximum attempts reached, using best result"
      break
    fi
  done
  
  echo "📊 Final size: $(( webp_size / 1024 ))KB ($(( (original_size - webp_size) * 100 / original_size ))% reduction)"
  echo ""
done

echo "✅  Conversion complete. WebP files are in '$OUTPUT_DIR/'."
