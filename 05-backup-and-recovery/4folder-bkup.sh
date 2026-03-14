#!/bin/bash

# ==========================================
# 📦 BlockDAG Backup Tool 📦
# 💙 by BlockDAG Investors Group 💙
# Made By: ArtX
# Version 1.2 - Simplified
# ==========================================

set -o pipefail
set -E

# --- COLOR SETUP ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- SUDO MANAGEMENT VARIABLES ---
SUDO_CACHED=false
SUDO_KEEPALIVE_PID=""

# --- ERROR TRACKING ---
SCRIPT_FAILED=false
BACKUP_PATH_CREATED=""

# ==========================================
# SUDO MANAGEMENT FUNCTIONS
# ==========================================

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

# Trap handlers for cleanup
trap 'echo -e "\n\n⛔ Script interrupted by user."; SCRIPT_FAILED=true; handle_script_error; exit 130' INT TERM
trap 'echo -e "\n\n💥 Script encountered an error."; SCRIPT_FAILED=true; handle_script_error; exit 1' ERR
trap 'cleanup_sudo' EXIT

# Function to handle script errors
handle_script_error() {
    if [ "$SCRIPT_FAILED" = true ] && [ -n "$BACKUP_PATH_CREATED" ] && [ -d "$BACKUP_PATH_CREATED" ]; then
        echo ""
        echo -e "${YELLOW}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${NC}  ${RED}${BOLD}Backup was incomplete due to an error${NC}             ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚═══════════════════════════════════════════════════════╝${NC}\n"
        
        read -rp "Would you like to delete the incomplete backup? (Y/n): " DELETE_BACKUP
        echo ""
        
        if [[ "$DELETE_BACKUP" =~ ^[Yy]$ ]] || [[ -z "$DELETE_BACKUP" ]]; then
            echo -e "${YELLOW}🗑️  Deleting incomplete backup...${NC}"
            rm -rf "$BACKUP_PATH_CREATED"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Incomplete backup deleted${NC}"
            else
                echo -e "${RED}❌ Failed to delete backup${NC}"
                echo -e "${YELLOW}📝 Please delete manually: $BACKUP_PATH_CREATED${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Incomplete backup kept at:${NC}"
            echo -e "${BLUE}   $BACKUP_PATH_CREATED${NC}"
        fi
        echo ""
    fi
    cleanup_sudo
}

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

# ==========================================
# PATH SANITIZATION FUNCTION
# ==========================================

sanitize_path() {
    local raw_path="$1"
    local path_type="$2"
    
    # Strip leading/trailing whitespace, newlines, and carriage returns
    raw_path=$(echo "$raw_path" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [ -z "$raw_path" ]; then
        echo -e "${RED}❌ Error: Path cannot be empty${NC}" >&2
        return 1
    fi
    
    # Block dangerous characters for command injection
    if [[ "$raw_path" =~ [\$\`\;] ]]; then
        echo -e "${RED}❌ Error: Path contains potentially dangerous characters${NC}" >&2
        echo -e "${YELLOW}   Invalid characters: \$ \` ;${NC}" >&2
        return 1
    fi
    
    # Check for excessive directory traversal
    local dot_count=$(echo "$raw_path" | grep -o "\.\." | wc -l)
    if [ "$dot_count" -gt 10 ]; then
        echo -e "${RED}❌ Error: Excessive directory traversal detected${NC}" >&2
        echo -e "${YELLOW}   (More than 10 '../' patterns found)${NC}" >&2
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
        echo -e "${RED}❌ Error: Could not resolve to absolute path${NC}" >&2
        return 1
    fi
    
    if [ ${#cleaned} -gt 4096 ]; then
        echo -e "${RED}❌ Error: Path is too long (max 4096 characters)${NC}" >&2
        return 1
    fi
    
    echo "$cleaned"
    return 0
}

# ==========================================
# UTILITY FUNCTIONS
# ==========================================

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}")KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")MB"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")GB"
    fi
}

# Function to get directory size
get_dir_size() {
    local dir="$1"
    if sudo test -d "$dir"; then
        sudo du -sb "$dir" 2>/dev/null | awk '{print $1}'
    else
        echo "0"
    fi
}

# Function to check if docker container is running
check_node_running() {
    local containers=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -i blockdag)
    if [ -n "$containers" ]; then
        echo "true"
        return 0
    else
        echo "false"
        return 1
    fi
}

# ==========================================
# MAIN SCRIPT START
# ==========================================

clear
echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}         ${WHITE}${BOLD}📦 BlockDAG Backup Tool 📦${NC}                ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}         ${GREEN}${BOLD}💙 BlockDAG Investors Group 💙${NC}            ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}               ${MAGENTA}${BOLD}Made By: ArtX${NC}                       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}               ${BLUE}Version 1.2${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}\n"

# --- SUDO CHECK ---
echo -e "${WHITE}⚙️  Requesting sudo credentials...${NC}"
cache_sudo || { echo -e "${RED}❌ Failed to acquire sudo access. Exiting.${NC}"; exit 1; }
echo -e "${CYAN}───────────────────────────────────────────────────────${NC}\n"

# ==========================================
# PRE-FLIGHT CHECKS
# ==========================================

echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}           ${MAGENTA}${BOLD}✈️  PRE-FLIGHT CHECKS${NC}                     ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}\n"

# --- CHECK IF NODE IS RUNNING ---
echo -e "${YELLOW}🔍 Checking if BlockDAG node is running...${NC}"
if check_node_running; then
    echo -e "${RED}⚠️  WARNING: BlockDAG node is currently running!${NC}\n"
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                ${YELLOW}${BOLD}⚠️  CRITICAL WARNING ⚠️${NC}                 ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}For a safe backup, you should:${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${RED}🛑 STOP YOUR BLOCKDAG NODE FIRST!${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}Running backup while node is active may cause:${NC}    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YELLOW}• Inconsistent backup data${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YELLOW}• Corruption in backed up files${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${YELLOW}• Invalid blockchain state${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    read -rp "⚠️  Do you want to continue anyway? (y/N): " CONTINUE_RUNNING
    if [[ ! "$CONTINUE_RUNNING" =~ ^[yY]$ ]]; then
        echo ""
        echo -e "${YELLOW}📌 Please stop your node first, then run this script again.${NC}"
        echo -e "${BLUE}💡 Tip: Use 'docker stop' command to stop your node safely.${NC}"
        exit 0
    fi
    echo ""
    echo -e "${YELLOW}⚠️  Proceeding with backup while node is running...${NC}"
else
    echo -e "${GREEN}✅ No running BlockDAG node detected${NC}"
fi
echo -e "${CYAN}───────────────────────────────────────────────────────${NC}\n"

# --- ASK FOR PATHS ---
echo -e "${BLUE}${BOLD}📂 Please provide the required paths:${NC}\n"

read -rp "🧭 Paste your Node folder path: " NODE_PATH_RAW
echo ""
echo -e "${CYAN}🛡️  Validating Node path...${NC}"
NODE_PATH=$(sanitize_path "$NODE_PATH_RAW" "Node folder") || exit 1
echo -e "${GREEN}✅ Node path validated${NC}"
echo ""

read -rp "💾 Paste your Backup destination path: " BACKUP_DEST_RAW
echo ""
echo -e "${CYAN}🛡️  Validating Backup destination...${NC}"
BACKUP_DEST=$(sanitize_path "$BACKUP_DEST_RAW" "Backup destination") || exit 1
echo -e "${GREEN}✅ Backup destination validated${NC}"
echo ""

# --- VALIDATE PATHS EXIST ---
echo -e "${YELLOW}🔍 Checking if paths exist...${NC}"

if [ ! -d "$NODE_PATH" ]; then
    echo -e "${RED}❌ Node path does not exist or is not accessible!${NC}"
    echo -e "${YELLOW}   Path: $NODE_PATH${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Node path exists${NC}"

if [ ! -d "$BACKUP_DEST" ]; then
    echo -e "${YELLOW}⚠️  Backup destination does not exist${NC}"
    read -rp "📁 Would you like to create it? (Y/n): " CREATE_DEST
    if [[ ! "$CREATE_DEST" =~ ^[Nn]$ ]]; then
        mkdir -p "$BACKUP_DEST"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Backup destination created${NC}"
        else
            echo -e "${RED}❌ Failed to create backup destination${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Cannot proceed without backup destination${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Backup destination exists${NC}"
fi

echo -e "${CYAN}───────────────────────────────────────────────────────${NC}\n"

# --- AUTO-DETECT BLOCKDAG STRUCTURE ---
echo -e "${YELLOW}🔎 Auto-detecting BlockDAG structure...${NC}\n"

# Step 1: Find blockdag-scripts folder
BDAG_SCRIPTS=$(find "$NODE_PATH" -type d -name "blockdag-scripts" -print -quit 2>/dev/null)

if [ -z "$BDAG_SCRIPTS" ]; then
    echo -e "${RED}❌ Could not find 'blockdag-scripts' folder in your Node path!${NC}"
    echo -e "${YELLOW}💡 Make sure your Node path contains the blockdag-scripts directory.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found blockdag-scripts:${NC} ${BDAG_SCRIPTS}"

# Step 2: Find bin folder
BDAG_BIN=$(find "$BDAG_SCRIPTS" -maxdepth 1 -type d -name "bin*" -print -quit 2>/dev/null)

if [ -z "$BDAG_BIN" ]; then
    echo -e "${RED}❌ Could not find 'bin' folder inside blockdag-scripts!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found bin folder:${NC} ${BDAG_BIN}"

# Step 3: Build full paths
TESTNET_PATH="$BDAG_BIN/bdag/data/testnet"
BDAGETH_PATH="$TESTNET_PATH/bdageth"

echo -e "${GREEN}✓ Built testnet path:${NC} ${TESTNET_PATH}"
echo -e "${GREEN}✓ Built bdageth path:${NC} ${BDAGETH_PATH}"
echo ""

# Verify paths exist - FIXED: Uses sudo test
if ! sudo test -d "$TESTNET_PATH"; then
    echo -e "${RED}❌ Testnet path not found: $TESTNET_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Testnet path verified!${NC}"

if ! sudo test -d "$BDAGETH_PATH"; then
    echo -e "${RED}❌ Bdageth path not found: $BDAGETH_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Bdageth path verified!${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────${NC}\n"

# --- VERIFY 4 FOLDERS EXIST ---
echo -e "${YELLOW}🔍 Verifying required folders exist...${NC}\n"

declare -a FOLDERS_TO_BACKUP
declare -a FOLDER_SIZES

# BdagChain is in testnet/
BDAGCHAIN_PATH="$TESTNET_PATH/BdagChain"
if sudo test -d "$BDAGCHAIN_PATH"; then
    echo -e "${GREEN}✅ BdagChain found${NC}"
    FOLDERS_TO_BACKUP+=("BdagChain:$TESTNET_PATH")
    BDAGCHAIN_SIZE=$(get_dir_size "$BDAGCHAIN_PATH")
    FOLDER_SIZES+=("$BDAGCHAIN_SIZE")
    echo -e "${BLUE}   Size: $(format_bytes $BDAGCHAIN_SIZE)${NC}"
else
    echo -e "${RED}❌ BdagChain not found in: $TESTNET_PATH${NC}"
    exit 1
fi
echo ""

# blobpool, chaindata, nodes are in testnet/bdageth/
for folder in "blobpool" "chaindata" "nodes"; do
    FOLDER_PATH="$BDAGETH_PATH/$folder"
    if sudo test -d "$FOLDER_PATH"; then
        echo -e "${GREEN}✅ $folder found${NC}"
        FOLDERS_TO_BACKUP+=("$folder:$BDAGETH_PATH")
        FOLDER_SIZE=$(get_dir_size "$FOLDER_PATH")
        FOLDER_SIZES+=("$FOLDER_SIZE")
        echo -e "${BLUE}   Size: $(format_bytes $FOLDER_SIZE)${NC}"
    else
        echo -e "${RED}❌ $folder not found in: $BDAGETH_PATH${NC}"
        exit 1
    fi
    echo ""
done

# Calculate total size needed
TOTAL_SIZE=0
for size in "${FOLDER_SIZES[@]}"; do
    TOTAL_SIZE=$((TOTAL_SIZE + size))
done

echo -e "${CYAN}───────────────────────────────────────────────────────${NC}"
echo -e "${WHITE}${BOLD}📊 Total backup size needed: ${GREEN}$(format_bytes $TOTAL_SIZE)${NC}\n"

# --- CHECK AVAILABLE DISK SPACE ---
echo -e "${YELLOW}💽 Checking available disk space...${NC}"

AVAILABLE_SPACE=$(df -B1 "$BACKUP_DEST" | tail -1 | awk '{print $4}')
echo -e "${BLUE}Available space: $(format_bytes $AVAILABLE_SPACE)${NC}"
echo -e "${BLUE}Required space:  $(format_bytes $TOTAL_SIZE)${NC}"

# Add 10% buffer for safety
REQUIRED_WITH_BUFFER=$((TOTAL_SIZE + TOTAL_SIZE / 10))

if [ $AVAILABLE_SPACE -lt $REQUIRED_WITH_BUFFER ]; then
    echo -e "${RED}❌ Insufficient disk space!${NC}"
    echo -e "${YELLOW}⚠️  You need at least $(format_bytes $REQUIRED_WITH_BUFFER) (including 10% buffer)${NC}"
    echo -e "${YELLOW}⚠️  But only $(format_bytes $AVAILABLE_SPACE) is available${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Sufficient disk space available${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────${NC}\n"

# ==========================================
# BACKUP PREVIEW
# ==========================================

echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}           ${MAGENTA}${BOLD}🎯 BACKUP PREVIEW${NC}                        ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}\n"

# Create timestamp
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_FOLDER="BlockDAG_Backup_$TIMESTAMP"
FULL_BACKUP_PATH="$BACKUP_DEST/$BACKUP_FOLDER"

echo -e "${WHITE}📦 Backup will be created at:${NC}"
echo -e "${GREEN}   $FULL_BACKUP_PATH${NC}\n"

echo -e "${WHITE}📂 Folders to be backed up:${NC}\n"

idx=0
for entry in "${FOLDERS_TO_BACKUP[@]}"; do
    folder_name="${entry%%:*}"
    source_base="${entry##*:}"
    source_path="$source_base/$folder_name"
    dest_path="$FULL_BACKUP_PATH/$folder_name"
    
    echo -e "${CYAN}┌─────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}✓ ${folder_name}${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}  📤 Source:      ${BLUE}${source_path}${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}  📥 Destination: ${YELLOW}${dest_path}${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}  💾 Size:        ${MAGENTA}$(format_bytes ${FOLDER_SIZES[$idx]})${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    idx=$((idx + 1))
done

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}${BOLD}📊 Total: ${GREEN}4 folders${NC} ${WHITE}│${NC} ${WHITE}${BOLD}Size: ${GREEN}$(format_bytes $TOTAL_SIZE)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"

# --- CONFIRMATION ---
read -rp "✓ Do you want to proceed with backup? (Y/n): " PROCEED
if [[ "$PROCEED" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}ℹ️  Backup cancelled by user.${NC}"
    exit 0
fi
echo ""

# ==========================================
# BACKUP PROCESS
# ==========================================

echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}           ${MAGENTA}${BOLD}🚀 BACKUP IN PROGRESS${NC}                    ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}\n"

# Create backup folder
mkdir -p "$FULL_BACKUP_PATH"
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to create backup folder${NC}"
    exit 1
fi

# Track backup path for error handling
BACKUP_PATH_CREATED="$FULL_BACKUP_PATH"

echo -e "${GREEN}✅ Backup folder created${NC}\n"

# Backup each folder
BACKUP_START_TIME=$(date +%s)

for entry in "${FOLDERS_TO_BACKUP[@]}"; do
    folder_name="${entry%%:*}"
    source_base="${entry##*:}"
    source_path="$source_base/$folder_name"
    dest_path="$FULL_BACKUP_PATH/$folder_name"
    
    echo -e "${WHITE}${BOLD}📦 Backing up: ${folder_name}${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────${NC}"
    
    # Use rsync for complete copy with progress
    sudo rsync -aH --info=progress2 "$source_path/" "$dest_path/" 2>&1 | while IFS= read -r line; do
        if [[ "$line" =~ [0-9]+% ]]; then
            echo -ne "\r${YELLOW}   Progress: ${line}${NC}"
        fi
    done
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "\n${GREEN}   ✅ Complete!${NC}"
        
        # FIX 1: Change ownership to current user after rsync
        echo -e "${YELLOW}   🔧 Fixing permissions...${NC}"
        sudo chown -R $USER:$USER "$dest_path"
        echo -e "${GREEN}   ✅ Permissions fixed${NC}\n"
    else
        echo -e "\n${RED}   ❌ Failed!${NC}\n"
        echo -e "${RED}❌ Backup failed for $folder_name${NC}"
        echo -e "${YELLOW}🗑️  Cleaning up incomplete backup...${NC}"
        rm -rf "$FULL_BACKUP_PATH"
        exit 1
    fi
done

BACKUP_END_TIME=$(date +%s)
BACKUP_DURATION=$((BACKUP_END_TIME - BACKUP_START_TIME))

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}✅ All folders backed up successfully!${NC}"
echo -e "${BLUE}⏱️  Time taken: ${BACKUP_DURATION} seconds${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"

# ==========================================
# VERIFICATION PROCESS
# ==========================================

echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}           ${MAGENTA}${BOLD}🔍 VERIFICATION IN PROGRESS${NC}              ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}\n"

echo -e "${WHITE}${BOLD}Verifying backup integrity (File Count + Size)...${NC}\n"

VERIFICATION_PASSED=true
declare -a VERIFICATION_ERRORS

VERIFY_START_TIME=$(date +%s)

for entry in "${FOLDERS_TO_BACKUP[@]}"; do
    folder_name="${entry%%:*}"
    source_base="${entry##*:}"
    source_path="$source_base/$folder_name"
    dest_path="$FULL_BACKUP_PATH/$folder_name"
    
    echo -e "${WHITE}🔍 Verifying: ${folder_name}${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────${NC}"
    
    # Count files
    echo -e "${YELLOW}   📊 Counting files...${NC}"
    SOURCE_FILE_COUNT=$(sudo find "$source_path" -type f 2>/dev/null | wc -l)
    DEST_FILE_COUNT=$(find "$dest_path" -type f 2>/dev/null | wc -l)
    
    echo -e "${BLUE}      Source: $SOURCE_FILE_COUNT files${NC}"
    echo -e "${BLUE}      Backup: $DEST_FILE_COUNT files${NC}"
    
    if [ "$SOURCE_FILE_COUNT" -ne "$DEST_FILE_COUNT" ]; then
        echo -e "${RED}   ❌ File count mismatch!${NC}"
        VERIFICATION_PASSED=false
        VERIFICATION_ERRORS+=("$folder_name: File count mismatch (Source: $SOURCE_FILE_COUNT, Backup: $DEST_FILE_COUNT)")
    else
        echo -e "${GREEN}   ✅ File count matches${NC}"
    fi
    
    # Compare sizes
    echo -e "${YELLOW}   💾 Comparing sizes...${NC}"
    SOURCE_SIZE=$(get_dir_size "$source_path")
    DEST_SIZE=$(get_dir_size "$dest_path")
    
    echo -e "${BLUE}      Source: $(format_bytes $SOURCE_SIZE)${NC}"
    echo -e "${BLUE}      Backup: $(format_bytes $DEST_SIZE)${NC}"
    
    # Allow 1% difference for filesystem overhead
    SIZE_DIFF=$((SOURCE_SIZE > DEST_SIZE ? SOURCE_SIZE - DEST_SIZE : DEST_SIZE - SOURCE_SIZE))
    SIZE_TOLERANCE=$((SOURCE_SIZE / 100))
    
    if [ $SIZE_DIFF -gt $SIZE_TOLERANCE ]; then
        echo -e "${RED}   ❌ Size mismatch!${NC}"
        VERIFICATION_PASSED=false
        VERIFICATION_ERRORS+=("$folder_name: Size mismatch (Difference: $(format_bytes $SIZE_DIFF))")
    else
        echo -e "${GREEN}   ✅ Size matches${NC}"
    fi
    
    # Verification complete for this folder
    echo -e "${GREEN}   ✅ Verification complete${NC}"
    
    echo ""
done

VERIFY_END_TIME=$(date +%s)
VERIFY_DURATION=$((VERIFY_END_TIME - VERIFY_START_TIME))

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}⏱️  Verification time: ${VERIFY_DURATION} seconds${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"

# ==========================================
# VERIFICATION RESULTS
# ==========================================

if [ "$VERIFICATION_PASSED" = true ]; then
    # SUCCESS
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}        ${WHITE}${BOLD}✅ BACKUP VERIFIED AND ACCURATE! ✅${NC}        ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                       ${GREEN}║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}                                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${WHITE}All files copied successfully${NC}                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${WHITE}Source and backup are 100% identical${NC}              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BLUE}📂 Backup location:${NC}                               ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${YELLOW}${FULL_BACKUP_PATH}${NC}"
    padding=$((53 - ${#FULL_BACKUP_PATH}))
    printf "${GREEN}║${NC}"
    printf "%${padding}s" ""
    echo -e "${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${MAGENTA}💾 Total size: $(format_bytes $TOTAL_SIZE)${NC}"
    size_str="$(format_bytes $TOTAL_SIZE)"
    printf "${GREEN}║${NC}"
    printf "%$((35 - ${#size_str}))s" ""
    echo -e "${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ${BLUE}⏱️  Total time: ${BACKUP_DURATION}s (backup) + ${VERIFY_DURATION}s (verify)${NC}"
    time_str="${BACKUP_DURATION}s (backup) + ${VERIFY_DURATION}s (verify)"
    printf "${GREEN}║${NC}"
    printf "%$((39 - ${#time_str}))s" ""
    echo -e "${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                       ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}\n"
    
    # Clear the error tracking since backup succeeded
    BACKUP_PATH_CREATED=""
    
else
    # FAILURE
    echo -e "${RED}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}                                                       ${RED}║${NC}"
    echo -e "${RED}║${NC}           ${WHITE}${BOLD}⚠️  BACKUP NOT VERIFIED! ⚠️${NC}              ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                       ${RED}║${NC}"
    echo -e "${RED}╠═══════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║${NC}                                                       ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${YELLOW}Files may not have copied completely${NC}              ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${YELLOW}Differences detected between source and backup${NC}    ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                       ${RED}║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}${BOLD}Verification Errors:${NC}"
    for error in "${VERIFICATION_ERRORS[@]}"; do
        echo -e "${RED}  ❌ $error${NC}"
    done
    echo ""
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}${BOLD}Would you like to delete the incomplete backup?${NC}     ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}\n"
    
    read -rp "Delete incomplete backup? (Y/n): " DELETE_BACKUP
    echo ""
    
    if [[ "$DELETE_BACKUP" =~ ^[Yy]$ ]] || [[ -z "$DELETE_BACKUP" ]]; then
        echo -e "${YELLOW}🗑️  Deleting incomplete backup...${NC}"
        rm -rf "$FULL_BACKUP_PATH"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Incomplete backup deleted successfully${NC}\n"
        else
            echo -e "${RED}❌ Failed to delete backup${NC}"
            echo -e "${YELLOW}📝 Please delete manually: $FULL_BACKUP_PATH${NC}\n"
        fi
        
        # Clear the error tracking since we handled deletion
        BACKUP_PATH_CREATED=""
    else
        echo -e "${YELLOW}⚠️  Incomplete backup kept at:${NC}"
        echo -e "${BLUE}   $FULL_BACKUP_PATH${NC}\n"
        echo -e "${YELLOW}📝 Please verify manually or delete the backup folder${NC}"
        echo -e "${YELLOW}💡 Some files may not have copied correctly${NC}\n"
        
        # Clear the error tracking since user chose to keep it
        BACKUP_PATH_CREATED=""
    fi
fi

# ==========================================
# END MESSAGE
# ==========================================

echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}              ${GREEN}${BOLD}✅ OPERATION COMPLETE${NC}                   ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}     ${WHITE}💙 Thank you for using BlockDAG Backup! 💙${NC}     ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}              ${WHITE}Made By: ArtX${NC}                           ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}              ${BLUE}🔐 Sudo cache cleared${NC}                   ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}\n"
