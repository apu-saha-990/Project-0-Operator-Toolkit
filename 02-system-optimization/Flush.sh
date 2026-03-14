#!/bin/bash

# BlockDAG Complete System Cleanup Script
# This script removes ALL BlockDAG-related files and folders from your entire system

set -e

# Global variables for sudo management
SUDO_CACHED=false
SUDO_KEEPALIVE_PID=""

# Cleanup function
cleanup_sudo() {
    if [ "$SUDO_CACHED" = true ]; then
        echo ""
        echo "🔒 Cleaning up sudo cache..."
        
        # Kill keepalive process
        if [ -n "$SUDO_KEEPALIVE_PID" ]; then
            kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
        fi
        
        # Clear sudo cache
        sudo -k
        echo "✅ Sudo cache cleared"
    fi
}

# Trap exit to cleanup sudo
trap cleanup_sudo EXIT INT TERM

# Cache sudo credentials
cache_sudo() {
    if [ "$SUDO_CACHED" = false ]; then
        echo "🔐 Caching sudo credentials for cleanup operations..."
        echo "Please enter your password:"
        
        if sudo -v; then
            SUDO_CACHED=true
            echo "✅ Sudo cached successfully"
            echo "ℹ️  Credentials will be cleared on exit"
            echo ""
            
            # Keep sudo alive in background
            (while true; do sudo -n true; sleep 50; done 2>/dev/null) &
            SUDO_KEEPALIVE_PID=$!
            
            sleep 1
            return 0
        else
            echo "❌ Failed to cache sudo"
            echo "⚠️  You may be prompted for password multiple times"
            echo ""
            return 1
        fi
    fi
    return 0
}

echo "========================================="
echo "BlockDAG COMPLETE System Cleanup Script"
echo "========================================="
echo ""
echo "This script will perform a thorough cleanup:"
echo "  1. Stop and remove all BlockDAG containers (all versions)"
echo "  2. Remove all BlockDAG Docker images (awakening, primordial, etc.)"
echo "  3. Remove all BlockDAG Docker volumes"
echo "  4. Remove all BlockDAG Docker networks"
echo "  5. Search entire system for BlockDAG files (all versions)"
echo "  6. Optionally delete ALL BlockDAG-related files"
echo ""
read -p "Do you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Cache sudo credentials
cache_sudo

echo ""
echo "========================================="
echo "PHASE 1: Docker Cleanup"
echo "========================================="

echo ""
echo "Step 1: Stopping all BlockDAG containers..."
# Find containers from all BlockDAG image versions
CONTAINERS=$(docker ps -a --format "{{.Names}}\t{{.Image}}" | grep -iE "blockdag|awakening|primordial" | cut -f1 2>/dev/null || true)

if [ -z "$CONTAINERS" ]; then
    echo "  No BlockDAG containers found."
else
    echo "$CONTAINERS" | while read -r container; do
        echo "  Stopping: $container"
        docker stop -t 10 "$container" 2>/dev/null || true
    done
fi

echo ""
echo "Step 2: Removing all BlockDAG containers..."
CONTAINERS=$(docker ps -a --format "{{.Names}}\t{{.Image}}" | grep -iE "blockdag|awakening|primordial" | cut -f1 2>/dev/null || true)

if [ -z "$CONTAINERS" ]; then
    echo "  No BlockDAG containers to remove."
else
    echo "$CONTAINERS" | while read -r container; do
        echo "  Removing: $container"
        docker rm "$container" 2>/dev/null || true
    done
fi

echo ""
echo "Step 3: Removing BlockDAG Docker images..."
# Search for all BlockDAG image versions
IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -iE "blockdag|awakening|primordial" 2>/dev/null || true)

if [ -z "$IMAGES" ]; then
    echo "  No BlockDAG images found."
else
    echo "$IMAGES" | while read -r image; do
        echo "  Removing image: $image"
        docker rmi "$image" 2>/dev/null || true
    done
fi

echo ""
echo "Step 4: Removing BlockDAG Docker volumes..."
VOLUMES=$(docker volume ls --filter "name=bdag" --format "{{.Name}}" 2>/dev/null || true)

if [ -z "$VOLUMES" ]; then
    echo "  No BlockDAG volumes found."
else
    echo "$VOLUMES" | while read -r volume; do
        echo "  Removing volume: $volume"
        docker volume rm "$volume" 2>/dev/null || true
    done
fi

echo ""
echo "Step 5: Removing BlockDAG Docker networks..."
NETWORKS=$(docker network ls --filter "name=blockdag" --format "{{.Name}}" 2>/dev/null || true)

if [ -z "$NETWORKS" ]; then
    echo "  No BlockDAG networks found."
else
    echo "$NETWORKS" | while read -r network; do
        # Skip default Docker networks
        if [[ "$network" != "bridge" && "$network" != "host" && "$network" != "none" ]]; then
            echo "  Removing network: $network"
            docker network rm "$network" 2>/dev/null || true
        fi
    done
fi

echo ""
echo "========================================="
echo "PHASE 2: System-wide File Search"
echo "========================================="
echo ""
echo "WARNING: This will search your ENTIRE system for BlockDAG files."
echo "This may take 2-5 minutes depending on system size."
echo ""
read -p "Search entire system for all BlockDAG files and folders? (yes/no): " SEARCH_SYSTEM

if [ "$SEARCH_SYSTEM" != "yes" ]; then
    echo "Skipping system-wide search."
    echo ""
    echo "Cleanup complete!"
    exit 0
fi

echo ""
echo "Searching entire system... (this may take a few minutes)"
echo ""

# Create temporary file for results
TEMP_FILE=$(mktemp)

# Search for BlockDAG-related items (suppress permission errors)
echo "Searching for directories and files..."

# Search common locations for blockdag-related items (all versions)
sudo find / \( -path /proc -o -path /sys -o -path /dev -o -path /run -o -path /snap \) -prune -o \
    \( -iname "*blockdag*" -o -iname "*bdag*" -o -iname "*awakening*" -o -iname "*primordial*" -o -iname "*preawakening*" -o -iname "*pre-awakening*" \) \
    -print 2>/dev/null | grep -v ".git" > "$TEMP_FILE" || true

# Count results
RESULT_COUNT=$(wc -l < "$TEMP_FILE")

if [ "$RESULT_COUNT" -eq 0 ]; then
    echo ""
    echo "No BlockDAG files or folders found on the system."
    rm "$TEMP_FILE"
    echo ""
    echo "Cleanup complete!"
    exit 0
fi

echo ""
echo "========================================="
echo "FOUND $RESULT_COUNT BlockDAG-RELATED ITEMS"
echo "========================================="
echo ""

# Display findings with file sizes
echo "Directories and files found:"
echo ""

while IFS= read -r item; do
    if [ -e "$item" ]; then
        if [ -d "$item" ]; then
            SIZE=$(du -sh "$item" 2>/dev/null | cut -f1 || echo "???")
            echo "  [DIR]  $SIZE   $item"
        else
            SIZE=$(ls -lh "$item" 2>/dev/null | awk '{print $5}' || echo "???")
            echo "  [FILE] $SIZE   $item"
        fi
    fi
done < "$TEMP_FILE"

echo ""
echo "========================================="
echo "⚠️  CRITICAL WARNING  ⚠️"
echo "========================================="
echo ""
echo "You are about to DELETE ALL of the above files and folders!"
echo ""
echo "This includes:"
echo "  - All synced blockchain data (hundreds of GB)"
echo "  - All configuration files"
echo "  - All scripts and executables"
echo "  - All wallet files and keys"
echo "  - EVERYTHING related to BlockDAG"
echo ""
echo "THIS ACTION IS IRREVERSIBLE AND PERMANENT!"
echo ""
read -p "Type 'DELETE EVERYTHING' to confirm complete removal: " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "DELETE EVERYTHING" ]; then
    echo ""
    echo "Deletion cancelled. No files were removed."
    rm "$TEMP_FILE"
    exit 0
fi

echo ""
echo "========================================="
echo "Deleting all BlockDAG files..."
echo "========================================="
echo ""

# Delete all found items
DELETED_COUNT=0
FAILED_COUNT=0

while IFS= read -r item; do
    if [ -e "$item" ]; then
        echo "Deleting: $item"
        if sudo rm -rf "$item" 2>/dev/null; then
            DELETED_COUNT=$((DELETED_COUNT + 1))
        else
            FAILED_COUNT=$((FAILED_COUNT + 1))
            echo "  ⚠️  Failed to delete: $item"
        fi
    fi
done < "$TEMP_FILE"

rm "$TEMP_FILE"

echo ""
echo "========================================="
echo "CLEANUP SUMMARY"
echo "========================================="
echo ""
echo "Items deleted: $DELETED_COUNT"
echo "Items failed: $FAILED_COUNT"
echo ""

if [ "$FAILED_COUNT" -eq 0 ]; then
    echo "✅ SUCCESS: All BlockDAG files removed from system!"
else
    echo "⚠️  Some items could not be deleted (possibly in use or protected)"
fi

echo ""
echo "========================================="
echo "BlockDAG has been completely removed!"
echo "========================================="
