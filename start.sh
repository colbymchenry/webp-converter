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

# Ask user for maximum file size in KB
read -r -p "Enter maximum file size per image in KB (e.g., 100 for 100KB): " MAX_SIZE_KB
if ! [[ "$MAX_SIZE_KB" =~ ^[0-9]+$ ]]; then
  echo "❌  Invalid input. Please enter a number. Exiting."
  exit 1
fi

# Convert to bytes
MAX_SIZE_BYTES=$((MAX_SIZE_KB * 1024))
echo "🎯 Target maximum file size: ${MAX_SIZE_KB}KB (${MAX_SIZE_BYTES} bytes)"

# 4️⃣ Enable globbing for multiple extensions
shopt -s nullglob

# 5️⃣ Loop through images in media/
for img in "$MEDIA_DIR"/*.{jpg,jpeg,png}; do
  filename="$(basename "${img%.*}")"
  extension="${img##*.}"
  target="$OUTPUT_DIR/${filename}.webp"

  echo "🔄 Converting '$img' → '$target'"
  
  original_size=$(stat -c%s "$img" 2>/dev/null || stat -f%z "$img")
  echo "📊 Original size: $(( original_size / 1024 ))KB"
  
  # Initial quality settings
  if [[ "${extension,,}" == "png" ]]; then
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
    
    if [[ "${extension,,}" == "png" && $attempt -eq 1 ]]; then
      # First attempt for PNG with lossless
      cwebp $quality_param -m 6 "$img" -o "$target"
    elif [[ "${extension,,}" == "png" && $attempt -eq 2 ]]; then
      # Second attempt for PNG with near-lossless
      quality=90
      cwebp -near_lossless $quality -m 6 "$img" -o "$target"
      quality_param="-near_lossless $quality"
    elif [[ "${extension,,}" == "png" ]]; then
      # Subsequent attempts for PNG with lossy
      quality=$((quality - 10))
      if [ $quality -lt $min_quality ]; then
        quality=$min_quality
      fi
      cwebp -q $quality -m 6 -sharp_yuv -af "$img" -o "$target"
      quality_param="-q $quality"
    else
      # JPEG compression
      cwebp $quality_param -m 6 -pass 10 -mt -af -sharp_yuv "$img" -o "$target"
      quality=$((quality - 10))
      if [ $quality -lt $min_quality ]; then
        quality=$min_quality
      fi
      quality_param="-q $quality"
    fi
    
    # Check file size
    webp_size=$(stat -c%s "$target" 2>/dev/null || stat -f%z "$target")
    echo "  ↳ Current size: $(( webp_size / 1024 ))KB"
    
    if [ $webp_size -le $MAX_SIZE_BYTES ]; then
      echo "✅ Target size achieved on attempt $attempt"
      break
    fi
    
    if [ $quality -le $min_quality ] && [[ "${extension,,}" != "png" || $attempt -gt 2 ]]; then
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
