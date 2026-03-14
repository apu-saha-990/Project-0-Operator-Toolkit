#!/bin/bash

# ============================================================================
# Blockdag Node Restoration Script v3.2
# A robust backup restoration tool with real-time progress monitoring
# Supports internal drives, external drives, and network filesystems
# Enhanced with modern sudo management and improved UX
# ============================================================================

set -o pipefail
set -E

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Log file setup
LOG_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE=""

# Global variables for rsync configuration
RSYNC_FLAGS=""
SUDO_LIKELY_NEEDED=true

# Sudo management variables
SUDO_CACHED=false
SUDO_KEEPALIVE_PID=""

# ============================================================================
# SUDO MANAGEMENT FUNCTIONS
# ============================================================================

cleanup_sudo() {
    if [ "$SUDO_CACHED" = true ]; then
        echo ""
        echo -e "${CYAN}🔒 Cleaning up sudo cache...${NC}"
        
        # Kill keepalive process
        if [ -n "$SUDO_KEEPALIVE_PID" ]; then
            kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
        fi
        
        # Clear sudo cache
        sudo -k
        echo -e "${GREEN}✅ Sudo cache cleared${NC}"
    fi
}

# Trap handlers - Enhanced for better error handling
trap 'echo -e "\n\n⛔ Script interrupted by user. Exiting safely..."; log_message "Script interrupted by user"; cleanup_sudo; read -p "Press Enter to close..."; exit 130' INT TERM
trap 'echo -e "\n\n💥 Script encountered an error on line $LINENO. Check log: $LOG_FILE"; log_message "ERROR: Script failed on line $LINENO"; cleanup_sudo; read -p "Press Enter to close..."; exit 1' ERR
trap 'final_exit_code=$?; cleanup_sudo; if [ $final_exit_code -ne 0 ]; then echo ""; echo "══════════════════════════════════════════════════════════"; echo "⚠️  Script exited unexpectedly! Exit code: $final_exit_code"; echo "📋 Check log file: $LOG_FILE"; echo "══════════════════════════════════════════════════════════"; echo ""; read -p "Press Enter to close terminal..."; fi' EXIT

cache_sudo() {
    if [ "$SUDO_CACHED" = false ]; then
        echo -e "${CYAN}🔐 Caching sudo credentials...${NC}"
        echo -e "${YELLOW}Please enter your password:${NC}"
        
        if sudo -v; then
            SUDO_CACHED=true
            echo -e "${GREEN}✅ Sudo cached successfully${NC}"
            echo -e "${BLUE}ℹ️  Credentials will be cleared on exit${NC}"
            echo ""
            
            # Keep sudo alive in background
            (while true; do sudo -n true; sleep 50; done 2>/dev/null) &
            SUDO_KEEPALIVE_PID=$!
            
            sleep 1
            return 0
        else
            echo -e "${RED}❌ Failed to cache sudo${NC}"
            echo -e "${YELLOW}⚠️  You may be prompted for password multiple times${NC}"
            echo ""
            return 1
        fi
    fi
    return 0
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_message() {
    if [ -n "$LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    fi
}

sanitize_path() {
    local raw_path="$1"
    local path_type="$2"
    
    # Strip leading/trailing whitespace, newlines, and carriage returns
    raw_path=$(echo "$raw_path" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [ -z "$raw_path" ]; then
        echo "❌ Error: Path cannot be empty" >&2
        log_message "ERROR: Empty path provided for $path_type"
        return 1
    fi
    
    # Only block truly dangerous characters for command injection
    # Allow normal path characters including spaces, dashes, underscores
    if [[ "$raw_path" =~ [\$\`\;] ]]; then
        echo "❌ Error: Path contains potentially dangerous characters" >&2
        echo "   Invalid characters: \$ \` ;" >&2
        log_message "ERROR: Dangerous characters detected in path for $path_type: $raw_path"
        return 1
    fi
    
    # Relax directory traversal check - allow reasonable use of ../
    local dot_count=$(echo "$raw_path" | grep -o "\.\." | wc -l)
    if [ "$dot_count" -gt 10 ]; then
        echo "❌ Error: Excessive directory traversal detected" >&2
        echo "   (More than 10 '../' patterns found)" >&2
        log_message "ERROR: Excessive traversal in path for $path_type: $raw_path"
        return 1
    fi
    
    # Expand ~ to home directory if present
    raw_path="${raw_path/#\~/$HOME}"
    
    # Try to resolve the path
    local cleaned
    if command -v realpath &> /dev/null; then
        cleaned=$(realpath -m "$raw_path" 2>/dev/null)
    else
        # Fallback if realpath is not available
        if [ -d "$raw_path" ]; then
            cleaned=$(cd "$raw_path" 2>/dev/null && pwd)
        else
            cleaned=$(cd "$(dirname "$raw_path")" 2>/dev/null && pwd)/$(basename "$raw_path")
        fi
    fi
    
    if [ $? -ne 0 ] || [ -z "$cleaned" ]; then
        # If realpath fails, use the path as-is but make it absolute
        if [[ "$raw_path" != /* ]]; then
            cleaned="$(pwd)/$raw_path"
        else
            cleaned="$raw_path"
        fi
    fi
    
    # Ensure it's an absolute path
    if [[ "$cleaned" != /* ]]; then
        echo "❌ Error: Could not resolve to absolute path" >&2
        log_message "ERROR: Non-absolute path for $path_type: $cleaned"
        return 1
    fi
    
    if [ ${#cleaned} -gt 4096 ]; then
        echo "❌ Error: Path is too long (max 4096 characters)" >&2
        log_message "ERROR: Path too long for $path_type"
        return 1
    fi
    
    log_message "Path sanitized successfully for $path_type: $raw_path -> $cleaned"
    echo "$cleaned"
    return 0
}

print_welcome() {
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║          🔷 Blockdag Node Restoration Script 🔷          ║"
    echo "║                          By                              ║"
    echo "║            💎 Blockdag Investors Group 💎                ║"
    echo "║                                                          ║"
    echo "║                     Version 3.2                          ║"
    echo "║         (Enhanced Sudo & UX Improvements)                ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    log_message "Script started - Version 3.2 (Enhanced sudo management & UX)"
}

print_node_warning() {
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  CRITICAL WARNING ⚠️                ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║                                                          ║"
    echo "║  Before proceeding with the restoration process:         ║"
    echo "║                                                          ║"
    echo "║  🛑 STOP YOUR BLOCKDAG NODE FIRST!                       ║"
    echo "║                                                          ║"
    echo "║  Running a restore while the node is active can cause:   ║"
    echo "║    • Database corruption                                 ║"
    echo "║    • Data inconsistencies                                ║"
    echo "║    • Failed restoration                                  ║"
    echo "║    • Loss of sync status                                 ║"
    echo "║                                                          ║"
    echo "║  We STRONGLY recommend stopping your node before         ║"
    echo "║  continuing with this restoration.                       ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    read -rp "⚠️  Have you stopped your Blockdag node? (y/n): " NODE_STOPPED
    if [[ "$NODE_STOPPED" != [yY] ]]; then
        echo ""
        echo "❌ Please stop your node first, then run this script again."
        echo "💡 Tip: Check node documentation for proper shutdown procedure."
        log_message "User did not stop node - script exited"
        exit 0
    fi
    
    echo ""
    echo "✅ Proceeding with restoration..."
    log_message "User confirmed node is stopped"
    echo ""
}

check_requirements() {
    echo -e "${BLUE}🔍 Checking system requirements...${NC}"
    
    if ! command -v rsync &> /dev/null; then
        echo -e "${RED}   ❌ rsync is not installed${NC}"
        echo ""
        echo "Please install rsync first:"
        echo "  Ubuntu/Debian: sudo apt-get install rsync"
        echo "  CentOS/RHEL:   sudo yum install rsync"
        echo "  macOS:         brew install rsync"
        log_message "ERROR: rsync not installed"
        exit 1
    fi
    echo -e "${GREEN}   ✅ rsync installed${NC}"
    
    if ! command -v tput &> /dev/null; then
        echo -e "${YELLOW}   ⚠️  tput not available (progress display may be limited)${NC}"
        log_message "WARNING: tput not available"
    else
        echo -e "${GREEN}   ✅ Required tools available${NC}"
    fi
    
    if ! command -v realpath &> /dev/null; then
        echo -e "${YELLOW}   ⚠️  realpath not available (using fallback)${NC}"
        log_message "WARNING: realpath not available"
    else
        echo -e "${GREEN}   ✅ Path sanitization tools available${NC}"
    fi
    
    log_message "System requirements check passed"
    echo ""
}

human_readable() {
    local BYTES=$1
    if [ "$BYTES" -lt 1024 ]; then
        echo "${BYTES} B"
    elif [ "$BYTES" -lt $((1024*1024)) ]; then
        echo "$((BYTES/1024)) KB"
    elif [ "$BYTES" -lt $((1024*1024*1024)) ]; then
        echo "$((BYTES/1024/1024)) MB"
    else
        echo "$((BYTES/1024/1024/1024)) GB"
    fi
}

check_disk_space() {
    local DEST=$1
    
    if command -v df &> /dev/null; then
        local AVAILABLE=$(df -BG "$DEST" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//')
        if [ -n "$AVAILABLE" ] && [ "$AVAILABLE" -gt 0 ] 2>/dev/null; then
            echo -e "${CYAN}💾 Available space at destination: ${AVAILABLE} GB${NC}"
            log_message "Available disk space: ${AVAILABLE} GB"
            
            if [ "$AVAILABLE" -lt 5 ]; then
                echo -e "${YELLOW}⚠️  Warning: Low disk space available!${NC}"
                log_message "WARNING: Low disk space (${AVAILABLE} GB)"
            fi
        fi
    fi
}

validate_path() {
    local PATH_TYPE=$1
    local PATH_VAR=$2
    
    if [ ! -d "$PATH_VAR" ]; then
        echo -e "${RED}❌ $PATH_TYPE does not exist: $PATH_VAR${NC}"
        log_message "ERROR: $PATH_TYPE does not exist: $PATH_VAR"
        exit 1
    fi
    
    if [ ! -r "$PATH_VAR" ]; then
        echo -e "${RED}❌ $PATH_TYPE is not readable: $PATH_VAR${NC}"
        log_message "ERROR: $PATH_TYPE is not readable: $PATH_VAR"
        exit 1
    fi
}

detect_filesystem() {
    local DEST=$1
    
    echo "────────────────────────────────────────────────────────"
    echo -e "${CYAN}🔍 Analyzing destination filesystem...${NC}"
    echo ""
    
    local FS_TYPE=$(df -T "$DEST" 2>/dev/null | tail -1 | awk '{print $2}')
    
    if [ -z "$FS_TYPE" ]; then
        echo -e "${YELLOW}   ⚠️  Could not determine filesystem type${NC}"
        echo "   Using safe default settings"
        RSYNC_FLAGS="-av"
        SUDO_LIKELY_NEEDED=false
        log_message "WARNING: Could not detect filesystem type"
        echo ""
        return
    fi
    
    echo -e "${BLUE}💿 Detected filesystem: ${CYAN}$FS_TYPE${NC}"
    log_message "Filesystem detected: $FS_TYPE"
    
    local DEVICE=$(df "$DEST" 2>/dev/null | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//')
    local IS_REMOVABLE="unknown"
    
    if [ -n "$DEVICE" ] && [ -b "$DEVICE" ]; then
        IS_REMOVABLE=$(lsblk -no RM "$DEVICE" 2>/dev/null || echo "unknown")
    fi
    
    if [ "$IS_REMOVABLE" = "1" ]; then
        echo -e "${MAGENTA}📱 External/removable drive detected${NC}"
        echo ""
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║              ⚠️  EXTERNAL DRIVE WARNING ⚠️               ║"
        echo "╠══════════════════════════════════════════════════════════╣"
        echo "║                                                          ║"
        echo "║  • Keep drive connected during entire restore process    ║"
        echo "║  • Do NOT unplug until completion message appears        ║"
        echo "║  • External drives may be slower than internal drives    ║"
        echo "║  • Estimated time will be shown during restore           ║"
        echo "║                                                          ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        log_message "External/removable drive detected"
        echo ""
    fi
    
    case $FS_TYPE in
        ext4|ext3|ext2|xfs|btrfs)
            echo -e "${GREEN}   ✅ Native Linux filesystem - full restoration support${NC}"
            echo -e "${BLUE}   📋 All permissions, ownership, and attributes will be preserved${NC}"
            RSYNC_FLAGS="-aHAX"
            SUDO_LIKELY_NEEDED=true
            log_message "Using full preservation mode (ext4/xfs/btrfs)"
            ;;
        ntfs|fuseblk)
            echo -e "${YELLOW}   ⚠️  NTFS filesystem detected${NC}"
            echo ""
            echo "   Important limitations:"
            echo "   • Unix permissions will NOT be preserved"
            echo "   • File ownership will NOT be preserved"
            echo "   • Extended attributes will NOT be preserved"
            echo ""
            echo -e "${YELLOW}   ⚠  This may cause issues with node operation!${NC}"
            echo -e "${BLUE}   💡 For best results, use an ext4-formatted drive${NC}"
            echo ""
            RSYNC_FLAGS="-rtv --modify-window=1"
            SUDO_LIKELY_NEEDED=false
            log_message "Using NTFS compatibility mode (limited preservation)"
            
            read -rp "   Continue with NTFS drive anyway? (y/n): " CONTINUE_NTFS
            if [[ "$CONTINUE_NTFS" != [yY] ]]; then
                echo -e "${RED}❌ Restore cancelled. Please use an ext4-formatted drive.${NC}"
                log_message "User cancelled due to NTFS filesystem"
                exit 0
            fi
            ;;
        vfat|exfat|msdos)
            echo -e "${RED}   ❌ FAT32/exFAT filesystem detected${NC}"
            echo ""
            echo "   CRITICAL LIMITATIONS:"
            echo "   • NO Unix permissions support"
            echo "   • NO file ownership support"
            echo "   • NO symbolic links support"
            echo "   • NO extended attributes support"
            echo "   • Limited timestamp accuracy"
            echo ""
            echo -e "${RED}   ⚠️  STRONGLY NOT RECOMMENDED for Blockdag node data!${NC}"
            echo -e "${YELLOW}   💡 This may cause severe node malfunctions${NC}"
            echo ""
            RSYNC_FLAGS="-rtv --modify-window=2"
            SUDO_LIKELY_NEEDED=false
            log_message "WARNING: FAT32/exFAT detected (not recommended)"
            
            read -rp "   Are you ABSOLUTELY SURE you want to continue? (yes/no): " CONTINUE_FAT
            if [[ "$CONTINUE_FAT" != "yes" ]]; then
                echo -e "${RED}❌ Restore cancelled. Please use an ext4-formatted drive.${NC}"
                log_message "User cancelled due to FAT32/exFAT filesystem"
                exit 0
            fi
            
            echo ""
            echo -e "${RED}   ⚠️  Final warning: Proceeding at your own risk!${NC}"
            sleep 2
            ;;
        nfs|nfs4|cifs|smb|smbfs)
            echo -e "${BLUE}   🌐 Network filesystem detected${NC}"
            echo -e "${YELLOW}   ⚠️  Network performance may affect restore speed${NC}"
            echo -e "${BLUE}   💡 Ensure stable network connection${NC}"
            RSYNC_FLAGS="-av --modify-window=1"
            SUDO_LIKELY_NEEDED=false
            log_message "Network filesystem detected"
            ;;
        zfs)
            echo -e "${GREEN}   ✅ ZFS filesystem - full restoration support${NC}"
            echo -e "${BLUE}   📋 All permissions and attributes will be preserved${NC}"
            RSYNC_FLAGS="-aHAX"
            SUDO_LIKELY_NEEDED=true
            log_message "Using full preservation mode (ZFS)"
            ;;
        *)
            echo -e "${YELLOW}   ⚠️  Unknown filesystem type: $FS_TYPE${NC}"
            echo "   Using safe compatibility mode"
            RSYNC_FLAGS="-av"
            SUDO_LIKELY_NEEDED=false
            log_message "WARNING: Unknown filesystem type, using safe mode"
            ;;
    esac
    
    echo ""
    log_message "Rsync flags set to: $RSYNC_FLAGS"
}

detect_sudo_requirement() {
    local SRC=$1
    local DEST=$2
    local NEEDS_SUDO=false
    
    echo "────────────────────────────────────────────────────────"
    echo -e "${CYAN}🔍 Analyzing permission requirements...${NC}"
    echo ""
    
    if [[ "$RSYNC_FLAGS" == *"-rtv"* ]]; then
        echo -e "${BLUE}   ℹ️  Filesystem doesn't support Unix permissions${NC}"
        echo "   Sudo not applicable for this destination"
        log_message "Sudo check skipped (incompatible filesystem)"
        RSYNC_CMD="rsync"
        USE_SUDO_TEXT="Not applicable"
        echo ""
        echo "$USE_SUDO_TEXT" > /tmp/.blockdag_sudo_status_$$
        echo "$RSYNC_CMD" > /tmp/.blockdag_rsync_cmd_$$
        return
    fi
    
    if touch "$DEST/.test_write_$$" 2>/dev/null; then
        rm -f "$DEST/.test_write_$$"
        echo -e "${GREEN}   ✅ Destination is writable without sudo${NC}"
        log_message "Destination write test: PASSED (no sudo needed)"
    else
        echo -e "${YELLOW}   🔒 Destination requires elevated permissions${NC}"
        log_message "Destination write test: FAILED (sudo required)"
        NEEDS_SUDO=true
    fi
    
    if find "$SRC" -user root -print -quit 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}   🔒 Backup contains system files (root-owned)${NC}"
        log_message "Source contains root-owned files (sudo required)"
        NEEDS_SUDO=true
    else
        echo -e "${GREEN}   ✅ Backup contains user-owned files only${NC}"
        log_message "Source contains user-owned files only"
    fi
    
    echo ""
    
    if [ "$NEEDS_SUDO" = true ]; then
        echo -e "${CYAN}⚡ Automatically enabling sudo for this restore${NC}"
        echo "   Reason: Required for proper file permissions and ownership"
        log_message "Auto-detected: sudo IS required"
        RSYNC_CMD="sudo rsync"
        USE_SUDO_TEXT="Yes (Auto-detected)"
    else
        echo -e "${BLUE}ℹ️  Sudo not required, but available as an option${NC}"
        echo ""
        read -rp "🔒 Use sudo anyway? (recommended for system files) (y/n): " USE_SUDO_INPUT
        if [[ "$USE_SUDO_INPUT" == [yY] ]]; then
            USE_SUDO_TEXT="Yes (User choice)"
            RSYNC_CMD="sudo rsync"
            log_message "User chose to use sudo"
        else
            USE_SUDO_TEXT="No"
            RSYNC_CMD="rsync"
            log_message "User chose NOT to use sudo"
        fi
    fi
    
    echo ""
    echo "$USE_SUDO_TEXT" > /tmp/.blockdag_sudo_status_$$
    echo "$RSYNC_CMD" > /tmp/.blockdag_rsync_cmd_$$
}

print_summary() {
    local SRC=$1
    local DEST=$2
    local USE_SUDO=$3
    local IS_DRYRUN=$4
    local FS_INFO=$5
    
    echo "────────────────────────────────────────────────────────"
    echo -e "${CYAN}📋 RESTORE SUMMARY:${NC}"
    echo "────────────────────────────────────────────────────────"
    echo -e "${BLUE}   Source:${NC}      $SRC"
    echo -e "${BLUE}   Destination:${NC} $DEST"
    echo -e "${BLUE}   Filesystem:${NC}  $FS_INFO"
    echo -e "${BLUE}   Sudo:${NC}        $USE_SUDO"
    echo -e "${BLUE}   Mode:${NC}        $IS_DRYRUN"
    echo -e "${BLUE}   Rsync flags:${NC} $RSYNC_FLAGS"
    echo -e "${GREEN}   Security:${NC}    Path sanitization enabled ✅"
    echo "────────────────────────────────────────────────────────"
    echo ""
    
    log_message "Restore Summary - Source: $SRC, Dest: $DEST, FS: $FS_INFO, Sudo: $USE_SUDO, Mode: $IS_DRYRUN, Flags: $RSYNC_FLAGS"
}

draw_progress_box() {
    local SRC=$1
    local DEST=$2
    local TRANSFERRED=$3
    local PROGRESS=$4
    local SPEED=$5
    local TIME=$6
    local XFR=$7
    local TOCHK=$8
    local TOTAL=$9
    
    echo "────────────────────────────────────────────────────────"
    echo -e "${CYAN}🔄 In Progress...${NC}"
    echo "────────────────────────────────────────────────────────"
    echo -e "${BLUE}📂 Source:${NC}      $SRC"
    echo -e "${BLUE}📁 Destination:${NC} $DEST"
    echo "────────────────────────────────────────────────────────"
    echo -e "${GREEN}📊 Progress:${NC}    $PROGRESS"
    echo -e "${GREEN}📦 Transferred:${NC} $TRANSFERRED"
    echo -e "${CYAN}⚡ Speed:${NC}       $SPEED"
    echo -e "${MAGENTA}⏱️  Time:${NC}        $TIME"
    echo -e "${BLUE}📄 Files:${NC}       $XFR transferred, $TOCHK/$TOTAL to check"
    echo "────────────────────────────────────────────────────────"
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

print_welcome
print_node_warning
check_requirements

echo "────────────────────────────────────────────────────────"
echo ""

read -rp "📂 Enter the full path of the backup folder to restore: " BACKUP_DIR_RAW
echo ""
echo -e "${CYAN}🛡️  Validating path security...${NC}"
BACKUP_DIR=$(sanitize_path "$BACKUP_DIR_RAW" "backup folder") || exit 1
BACKUP_DIR="${BACKUP_DIR%/}"
echo -e "${GREEN}✅ Path validated successfully${NC}"
echo ""

validate_path "Backup folder" "$BACKUP_DIR"
echo ""

read -rp "📁 Enter the full path of the destination folder: " DEST_DIR_RAW
echo ""
echo -e "${CYAN}🛡️  Validating path security...${NC}"
DEST_DIR=$(sanitize_path "$DEST_DIR_RAW" "destination folder") || exit 1
DEST_DIR="${DEST_DIR%/}"
echo -e "${GREEN}✅ Path validated successfully${NC}"
echo ""

validate_path "Destination folder" "$DEST_DIR"

if [ -w "$DEST_DIR" ]; then
    LOG_FILE="$DEST_DIR/blockdag_restore_${LOG_TIMESTAMP}.log"
    LOG_LOCATION="destination folder"
elif [ -w "$HOME" ]; then
    mkdir -p "$HOME/.blockdag/logs" 2>/dev/null
    LOG_FILE="$HOME/.blockdag/logs/blockdag_restore_${LOG_TIMESTAMP}.log"
    LOG_LOCATION="home directory"
else
    LOG_FILE="/tmp/blockdag_restore_${LOG_TIMESTAMP}.log"
    LOG_LOCATION="/tmp (temporary)"
fi

echo ""
echo -e "${BLUE}📝 Log file will be saved to: ${CYAN}$LOG_LOCATION${NC}"
echo -e "   Full path: ${GREEN}$LOG_FILE${NC}"
log_message "Log file initialized at: $LOG_FILE"
log_message "Path sanitization: ENABLED"
echo ""

detect_filesystem "$DEST_DIR"

FS_TYPE=$(df -T "$DEST_DIR" 2>/dev/null | tail -1 | awk '{print $2}')
FS_INFO="${FS_TYPE:-unknown}"

detect_sudo_requirement "$BACKUP_DIR" "$DEST_DIR"

USE_SUDO_TEXT=$(cat /tmp/.blockdag_sudo_status_$$ 2>/dev/null || echo "Not determined")
RSYNC_CMD=$(cat /tmp/.blockdag_rsync_cmd_$$ 2>/dev/null || echo "rsync")
rm -f /tmp/.blockdag_sudo_status_$$ /tmp/.blockdag_rsync_cmd_$$

read -rp "🧪 Do a dry-run first? (recommended) (y/n): " DRY_RUN_INPUT
DO_DRYRUN=false
MODE_TEXT="Full restore"
if [[ "$DRY_RUN_INPUT" == [yY] ]]; then
    DO_DRYRUN=true
    MODE_TEXT="Dry-run"
    log_message "User chose dry-run mode"
fi
echo ""

print_summary "$BACKUP_DIR" "$DEST_DIR" "$USE_SUDO_TEXT" "$MODE_TEXT" "$FS_INFO"

check_disk_space "$DEST_DIR"
echo ""

echo -e "${YELLOW}⚠️  This will overwrite existing files in the destination!${NC}"
echo ""
read -rp "🤔 Proceed with restore? (y/n): " CONFIRM
if [[ "$CONFIRM" != [yY] ]]; then
    echo -e "${RED}❌ Restore cancelled by user.${NC}"
    log_message "Restore cancelled by user"
    exit 0
fi
echo ""

# Cache sudo if needed
if [[ "$RSYNC_CMD" == *"sudo"* ]]; then
    cache_sudo
fi

if [ "$DO_DRYRUN" = true ]; then
    echo -e "${CYAN}🧪 Running dry-run to preview changes...${NC}"
    log_message "Starting dry-run"
    echo ""
    
    DRYRUN_OUTPUT=$($RSYNC_CMD $RSYNC_FLAGS -n --stats "$BACKUP_DIR/" "$DEST_DIR/" 2>&1)
    DRYRUN_EXIT=$?
    
    echo "$DRYRUN_OUTPUT"
    echo ""
    
    if [ $DRYRUN_EXIT -ne 0 ]; then
        echo -e "${RED}❌ Dry-run encountered errors!${NC}"
        echo ""
        echo "Common issues:"
        echo "  • Permission denied → Sudo may be required"
        echo "  • File not found → Check paths"
        echo "  • Disk full → Free up space"
        echo "  • Filesystem incompatibility → Check warnings above"
        echo ""
        log_message "ERROR: Dry-run failed with exit code $DRYRUN_EXIT"
        echo -e "${BLUE}📋 Check log file for details: $LOG_FILE${NC}"
        echo ""
        
        if [[ "$USE_SUDO_TEXT" == "No" ]] && [[ "$RSYNC_FLAGS" == *"-aHAX"* ]]; then
            read -rp "🔄 Retry dry-run with sudo? (y/n): " RETRY_SUDO
            if [[ "$RETRY_SUDO" == [yY] ]]; then
                echo ""
                echo -e "${CYAN}🔒 Retrying with sudo...${NC}"
                RSYNC_CMD="sudo rsync"
                USE_SUDO_TEXT="Yes (After retry)"
                
                # Cache sudo for retry
                cache_sudo
                
                DRYRUN_OUTPUT=$($RSYNC_CMD $RSYNC_FLAGS -n --stats "$BACKUP_DIR/" "$DEST_DIR/" 2>&1)
                DRYRUN_EXIT=$?
                
                echo "$DRYRUN_OUTPUT"
                echo ""
                
                if [ $DRYRUN_EXIT -eq 0 ]; then
                    echo -e "${GREEN}✅ Dry-run with sudo completed successfully!${NC}"
                else
                    echo -e "${RED}❌ Dry-run still failed. Please check the errors above.${NC}"
                    exit 1
                fi
            else
                exit 1
            fi
        else
            exit 1
        fi
    else
        echo -e "${GREEN}✅ Dry-run completed successfully!${NC}"
    fi
    
    echo ""
    read -rp "🚀 Proceed with actual restore? (y/n): " PROCEED
    if [[ "$PROCEED" != [yY] ]]; then
        echo -e "${RED}❌ Restore cancelled.${NC}"
        log_message "Restore cancelled after dry-run"
        exit 0
    fi
    echo ""
fi

echo -e "${CYAN}🛠️  Starting restore...${NC}"
log_message "Starting actual restore with command: $RSYNC_CMD $RSYNC_FLAGS"
sleep 1
echo ""

draw_progress_box "$BACKUP_DIR" "$DEST_DIR" "0 B" "0%" "0 B/s" "0:00:00" "0" "0" "0"

BOX_LINES=9

echo -e "${BLUE}🔄 Starting rsync process...${NC}"
log_message "Executing: $RSYNC_CMD $RSYNC_FLAGS --info=progress2"

if [[ "$RSYNC_CMD" == *"sudo"* ]] && [ "$SUDO_CACHED" = false ]; then
    echo -e "${YELLOW}🔒 Sudo access required - you may be prompted for password${NC}"
    sudo -v || { echo -e "${RED}❌ Sudo authentication failed${NC}"; log_message "ERROR: Sudo authentication failed"; exit 1; }
    echo -e "${GREEN}✅ Sudo authenticated successfully${NC}"
    echo ""
fi

$RSYNC_CMD $RSYNC_FLAGS --info=progress2 "$BACKUP_DIR/" "$DEST_DIR/" 2>&1 | while IFS= read -r line; do
    echo "$line" >> "$LOG_FILE"
    
    if [[ "$line" =~ ([0-9,]+)[[:space:]]+([0-9]+%)?[[:space:]]+([0-9\.A-Za-z/]+)[[:space:]]+([0-9:]+)[[:space:]]*\(xfr#([0-9]+),[[:space:]]*to-chk=([0-9]+)/([0-9]+)\) ]]; then
        BYTES="${BASH_REMATCH[1]//,/}"
        DONE="${BASH_REMATCH[2]:-0%}"
        SPEED="${BASH_REMATCH[3]}"
        TIME="${BASH_REMATCH[4]}"
        XFR="${BASH_REMATCH[5]}"
        TOCHK="${BASH_REMATCH[6]}"
        TOTAL="${BASH_REMATCH[7]}"
        
        if command -v tput &> /dev/null; then
            tput cuu $BOX_LINES
            tput ed
        fi
        
        draw_progress_box "$BACKUP_DIR" "$DEST_DIR" "$(human_readable $BYTES)" "$DONE" "$SPEED" "$TIME" "$XFR" "$TOCHK" "$TOTAL"
    fi
done

RSYNC_EXIT=${PIPESTATUS[0]}

log_message "Rsync completed with exit code: $RSYNC_EXIT"

if [ $RSYNC_EXIT -ne 0 ]; then
    echo "" >> "$LOG_FILE"
    echo "ERROR: Rsync failed with exit code $RSYNC_EXIT" >> "$LOG_FILE"
    echo "This may indicate permission issues, disk space problems, or connection loss" >> "$LOG_FILE"
fi

echo ""
if [ $RSYNC_EXIT -eq 0 ]; then
    echo -e "${GREEN}✅ Restore complete! 🎉${NC}"
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                   🎊 SUCCESS! 🎊                         ║"
    echo "╠══════════════════════════════════════════════════════════╣"
    echo "║                                                          ║"
    echo "║  Your Blockdag node has been successfully restored!      ║"
    echo "║                                                          ║"
    echo "║  Next steps:                                             ║"
    echo "║    1. Review the restoration log if needed               ║"
    echo "║    2. Verify file permissions (if applicable)            ║"
    echo "║    3. Start your Blockdag node                           ║"
    echo "║    4. Monitor node logs for proper operation             ║"
    echo "║    5. Verify node is syncing properly                    ║"
    echo "║                                                          ║"
    echo "║  🛡️  Security: All paths were sanitized and validated    ║"
    echo "║  🔐 Sudo cache has been cleared automatically            ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    log_message "Restore completed successfully"
else
    echo -e "${YELLOW}⚠️  Restore completed with warnings (exit code: $RSYNC_EXIT)${NC}"
    echo ""
    echo "Some files may not have been restored properly."
    echo "Please check the log file for details."
    log_message "WARNING: Restore completed with exit code $RSYNC_EXIT"
fi

echo ""
echo -e "${BLUE}📋 Full log file path: ${GREEN}$LOG_FILE${NC}"

if [[ "$LOG_FILE" == "/tmp/"* ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  Note: Log is in /tmp and may be deleted on system reboot${NC}"
    echo "   Consider copying it to a permanent location if needed"
    echo -e "   Command: ${CYAN}cp $LOG_FILE ~/blockdag_restore_backup.log${NC}"
fi

echo ""
echo "────────────────────────────────────────────────────────"
echo -e "         ${MAGENTA}💎 Thank you for using Blockdag Tools! 💎${NC}"
echo -e "         ${CYAN}🛡️  Enhanced with Security Features 🛡️${NC}"
echo "────────────────────────────────────────────────────────"
echo ""
echo -e "${RED}🛑 IMPORTANT: Press Enter to close this window${NC}"
echo ""

log_message "Script finished - waiting for user to close terminal"

read -p "Press Enter to exit..."
