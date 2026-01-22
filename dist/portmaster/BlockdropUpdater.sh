#!/bin/bash
# BlockdropUpdater.sh - Updates Blockdrop from GitHub
# Place this next to Blockdrop.sh in your ports folder
#
# Usage: Run from PortMaster menu or: ./BlockdropUpdater.sh

REPO="al5ina5/love-tetris"
BRANCH="main"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$SCRIPT_DIR/Blockdrop"

echo "=== Blockdrop Updater ==="
echo "Game directory: $GAME_DIR"
echo ""

# Check game folder exists
if [ ! -d "$GAME_DIR" ]; then
    echo "ERROR: Blockdrop folder not found at $GAME_DIR"
    echo "Make sure BlockdropUpdater.sh is in the same folder as Blockdrop/"
    exit 1
fi

# Check for curl or wget
if command -v curl &> /dev/null; then
    DOWNLOADER="curl"
elif command -v wget &> /dev/null; then
    DOWNLOADER="wget"
else
    echo "ERROR: Neither curl nor wget found!"
    exit 1
fi

echo "Using $DOWNLOADER for downloads..."
echo ""

# Download function
download_file() {
    local url="$1"
    local dest="$2"
    
    echo "Downloading: $(basename "$dest")"
    
    if [ "$DOWNLOADER" = "curl" ]; then
        curl -L -s -o "$dest" "$url"
    else
        wget -q -O "$dest" "$url"
    fi
    
    if [ $? -eq 0 ] && [ -f "$dest" ] && [ -s "$dest" ]; then
        echo "  OK"
        return 0
    else
        echo "  FAILED"
        return 1
    fi
}

# Base URL for raw files
BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/dist/portmaster"

echo "Downloading updates..."
echo ""

# Backup current .love file
if [ -f "$GAME_DIR/Blockdrop.love" ]; then
    cp "$GAME_DIR/Blockdrop.love" "$GAME_DIR/Blockdrop.love.backup"
    echo "Backed up current Blockdrop.love"
fi

# Download new files
download_file "$BASE_URL/Blockdrop/Blockdrop.love" "$GAME_DIR/Blockdrop.love"
LOVE_OK=$?

download_file "$BASE_URL/Blockdrop/Blockdrop.gptk" "$GAME_DIR/Blockdrop.gptk"
GPTK_OK=$?

download_file "$BASE_URL/Blockdrop/port.json" "$GAME_DIR/port.json"
JSON_OK=$?

echo ""

if [ $LOVE_OK -eq 0 ]; then
    # Remove backup on success
    rm -f "$GAME_DIR/Blockdrop.love.backup"
    echo "=== Update complete! ==="
    echo "Restart the game to use the new version."
else
    # Restore backup on failure
    if [ -f "$GAME_DIR/Blockdrop.love.backup" ]; then
        mv "$GAME_DIR/Blockdrop.love.backup" "$GAME_DIR/Blockdrop.love"
        echo "Update failed - restored previous version."
    fi
    echo "=== Update FAILED ==="
    exit 1
fi
