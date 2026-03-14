#!/usr/bin/env bash
#
# Copy a specific folder (including hidden files and symlinks)
# Asks user for source and destination folders.
# Uses sudo when creating destination or copying.

echo "🔹 Enter the SOURCE folder path (the folder you want to copy):"
read -r SOURCE

echo "🔹 Enter the DESTINATION directory (where to copy the folder into):"
read -r DEST

# Validate input
if [ -z "$SOURCE" ] || [ -z "$DEST" ]; then
  echo "❌ Source or destination cannot be empty."
  exit 1
fi

if [ ! -d "$SOURCE" ]; then
  echo "❌ Source folder does not exist: $SOURCE"
  exit 1
fi

# Extract just the folder name (so we can recreate it under destination)
FOLDER_NAME=$(basename "$SOURCE")

echo "📁 Checking destination..."
if [ ! -d "$DEST" ]; then
  echo "⚙️  Destination does not exist. Creating with sudo..."
  sudo mkdir -p "$DEST"
fi

echo "📦 Copying folder '$FOLDER_NAME' to '$DEST' (including hidden files and symlinks)..."
sudo cp -a "$SOURCE" "$DEST/"

if [ $? -eq 0 ]; then
  echo "✅ Folder '$FOLDER_NAME' copied successfully to $DEST/"
else
  echo "❌ Copy failed."
fi

