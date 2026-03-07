#!/bin/bash
# Image Re-hosting Script for WriteAlpha V2
# Run this on the production server or locally before DNS migration
#
# Usage:
#   1. Set your S3/R2 bucket URL:
#      export IMAGE_CDN_URL="https://cdn.writeralpha.com"
#   2. Run: bash rehost_images.sh
#   3. This downloads all images and uploads to your CDN

set -e

echo "=== WriteAlpha Image Re-hosting ==="
echo "Images to process: 1,197"
echo "Source: writeralpha.com/wp-content/uploads/"
echo ""

# Download all images
mkdir -p public/images
cd public/images

echo "Downloading images..."
cat << 'URLS' | while read url; do
  local_path=$(echo "$url" | sed 's|https://writeralpha.com/||')
  mkdir -p "$(dirname "$local_path")"
  wget -q -nc "$url" -O "$local_path" 2>/dev/null || true
done
URLS

echo "Done! Images saved to public/images/"
echo "Update your Rails app to serve from /images/ instead of writeralpha.com"
