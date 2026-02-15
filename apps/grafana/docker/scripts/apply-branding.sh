#!/bin/bash
set -euo pipefail

# Grafana Logo Branding Script
# This init container script downloads a logo from a URL and replaces
# the default Grafana icon in /usr/share/grafana/public/img/

# Configuration
LOGO_URL="${LOGO_URL:-}"
LOGO_PATH="${LOGO_PATH:-/usr/share/grafana/public/img/grafana_icon.svg}"
TEMP_LOGO="/tmp/logo"
RETRY_COUNT="${RETRY_COUNT:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"

# Exit gracefully if LOGO_URL is not set
if [ -z "$LOGO_URL" ]; then
  echo "[Branding] LOGO_URL not set, skipping logo replacement"
  exit 0
fi

echo "[Branding] Starting logo replacement process"
echo "[Branding] Target: $LOGO_PATH"

# Determine download tool
DOWNLOAD_CMD=""
if command -v curl &> /dev/null; then
  DOWNLOAD_CMD="curl"
elif command -v wget &> /dev/null; then
  DOWNLOAD_CMD="wget"
else
  echo "[Branding] ERROR: Neither curl nor wget available" >&2
  exit 1
fi

# Download logo with retry logic
ATTEMPT=1
DOWNLOAD_SUCCESS=false

while [ $ATTEMPT -le "$RETRY_COUNT" ]; do
  echo "[Branding] Download attempt $ATTEMPT of $RETRY_COUNT"
  
  if [ "$DOWNLOAD_CMD" = "curl" ]; then
    if curl -fsSL --output "$TEMP_LOGO" "$LOGO_URL" 2>/dev/null; then
      DOWNLOAD_SUCCESS=true
      break
    fi
  elif [ "$DOWNLOAD_CMD" = "wget" ]; then
    if wget -qO "$TEMP_LOGO" "$LOGO_URL" 2>/dev/null; then
      DOWNLOAD_SUCCESS=true
      break
    fi
  fi
  
  ATTEMPT=$((ATTEMPT + 1))
  
  if [ $ATTEMPT -le "$RETRY_COUNT" ]; then
    echo "[Branding] Download failed, retrying in ${RETRY_DELAY}s..."
    sleep "$RETRY_DELAY"
  fi
done

if [ "$DOWNLOAD_SUCCESS" = false ]; then
  echo "[Branding] ERROR: Failed to download logo after $RETRY_COUNT attempts" >&2
  exit 1
fi

# Detect file type from HTTP header or file extension
CONTENT_TYPE=""

if [ "$DOWNLOAD_CMD" = "curl" ]; then
  CONTENT_TYPE=$(curl -sI "$LOGO_URL" 2>/dev/null | grep -i "^content-type:" | head -1 | awk '{print $2}' | tr -d '\r' | cut -d';' -f1)
fi

# Fallback to file extension if Content-Type header not available
if [ -z "$CONTENT_TYPE" ]; then
  EXT="${LOGO_URL##*.}"
  EXT=$(echo "$EXT" | tr '[:upper:]' '[:lower:]' | cut -d'?' -f1)
  
  case "$EXT" in
    svg)
      CONTENT_TYPE="image/svg+xml"
      ;;
    png)
      CONTENT_TYPE="image/png"
      ;;
    jpg|jpeg)
      CONTENT_TYPE="image/jpeg"
      ;;
    gif)
      CONTENT_TYPE="image/gif"
      ;;
    *)
      echo "[Branding] WARNING: Unknown file type '$EXT', assuming SVG"
      CONTENT_TYPE="image/svg+xml"
      ;;
  esac
fi

echo "[Branding] Downloaded file type: $CONTENT_TYPE"

# If downloaded file is not SVG, attempt conversion if ImageMagick is available
if [ "$CONTENT_TYPE" != "image/svg+xml" ]; then
  if command -v convert &> /dev/null; then
    echo "[Branding] Converting $CONTENT_TYPE to SVG using ImageMagick"
    
    if convert "$TEMP_LOGO" "$TEMP_LOGO.svg" 2>/dev/null; then
      mv "$TEMP_LOGO.svg" "$TEMP_LOGO"
      echo "[Branding] Conversion successful"
    else
      echo "[Branding] WARNING: ImageMagick conversion failed, using original format"
    fi
  else
    echo "[Branding] WARNING: ImageMagick not available for $CONTENT_TYPE conversion"
    echo "[Branding] Proceeding with non-SVG logo (may not render optimally)"
  fi
fi

# Verify target directory exists
if [ ! -d "$(dirname "$LOGO_PATH")" ]; then
  echo "[Branding] ERROR: Logo target directory does not exist: $(dirname "$LOGO_PATH")" >&2
  exit 1
fi

# Backup original logo if it exists
if [ -f "$LOGO_PATH" ]; then
  echo "[Branding] Backing up original logo"
  cp "$LOGO_PATH" "$LOGO_PATH.bak"
fi

# Replace the logo
if cp "$TEMP_LOGO" "$LOGO_PATH"; then
  echo "[Branding] Successfully replaced logo at $LOGO_PATH"
else
  echo "[Branding] ERROR: Failed to replace logo" >&2
  exit 1
fi

# Verify replacement
if [ -f "$LOGO_PATH" ]; then
  SIZE=$(wc -c < "$LOGO_PATH")
  echo "[Branding] Logo replacement verified (size: $SIZE bytes)"
else
  echo "[Branding] ERROR: Logo verification failed" >&2
  exit 1
fi

# Cleanup
rm -f "$TEMP_LOGO" "$TEMP_LOGO.svg"

echo "[Branding] Logo replacement complete"
exit 0
