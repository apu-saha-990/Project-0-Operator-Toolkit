#!/bin/bash

# ==========================================
# 🐧 Welcome to Puddle De Leon JumpStart Tool 🐧
# 💙 by BlockDAG Investors Group with Love 💙
# Version 2.0 - Enhanced Security & Sudo Management
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
NC='\033[0m' # No Color

# --- SUDO MANAGEMENT VARIABLES ---
SUDO_CACHED=false
SUDO_KEEPALIVE_PID=""

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
trap 'echo -e "\n\n⛔ Script interrupted by user. Cleaning up..."; cleanup_sudo; exit 130' INT TERM
trap 'echo -e "\n\n💥 Script encountered an error. Cleaning up..."; cleanup_sudo; exit 1' ERR
trap 'cleanup_sudo' EXIT

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
# MAIN SCRIPT START
# ==========================================

clear
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}        🐧 Puddle De Leon JumpStart Tool 🐧${NC}"
echo -e "${GREEN}        💙 by BlockDAG Investors Group 💙${NC}"
echo -e "${MAGENTA}              Version 2.0 Enhanced${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"

# --- NODE STOP WARNING ---
echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                ${YELLOW}⚠️  CRITICAL WARNING ⚠️${NC}                 ${CYAN}║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${WHITE}Before using JumpStart, you MUST:${NC}                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${RED}🛑 STOP YOUR BLOCKDAG NODE FIRST!${NC}                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}Running JumpStart while node is active will cause:${NC}  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    ${YELLOW}• Database corruption${NC}                            ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    ${YELLOW}• Data inconsistencies${NC}                           ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    ${YELLOW}• Failed synchronization${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    ${YELLOW}• Potential data loss${NC}                            ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${WHITE}Please ensure your node is completely stopped${NC}      ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${WHITE}before continuing with this JumpStart process.${NC}     ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                       ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

read -rp "⚠️  Have you stopped your BlockDAG node? (y/n): " NODE_STOPPED
if [[ "$NODE_STOPPED" != [yY] ]]; then
    echo ""
    echo -e "${RED}❌ Please stop your node first, then run this script again.${NC}"
    echo -e "${BLUE}💡 Tip: Use 'docker stop' command to stop your node safely.${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}✅ Proceeding with JumpStart...${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────${NC}\n"

# --- SUDO CHECK ---
echo -e "${WHITE}⚙️  Requesting sudo credentials...${NC}"
cache_sudo || { echo -e "${RED}❌ Failed to acquire sudo access. Exiting.${NC}"; exit 1; }
echo -e "${CYAN}───────────────────────────────────────────────────────${NC}\n"

# --- ASK FOR PATHS ---
echo -e "${BLUE}📂 Please provide the required paths:${NC}\n"

read -rp "📦 Paste your JumpStart folder path: " JUMPSTART_PATH_RAW
echo ""
echo -e "${CYAN}🛡️  Validating JumpStart path...${NC}"
JUMPSTART_PATH=$(sanitize_path "$JUMPSTART_PATH_RAW" "JumpStart folder") || exit 1
echo -e "${GREEN}✅ JumpStart path validated${NC}"
echo ""

read -rp "🧭 Paste your Node folder path: " NODE_PATH_RAW
echo ""
echo -e "${CYAN}🛡️  Validating Node path...${NC}"
NODE_PATH=$(sanitize_path "$NODE_PATH_RAW" "Node folder") || exit 1
echo -e "${GREEN}✅ Node path validated${NC}"
echo ""

# Validate paths exist
if [ ! -d "$JUMPSTART_PATH" ]; then
  echo -e "${RED}❌ JumpStart path does not exist or is not accessible!${NC}"
  exit 1
fi

if [ ! -d "$NODE_PATH" ]; then
  echo -e "${RED}❌ Node path does not exist or is not accessible!${NC}"
  exit 1
fi

echo -e "${CYAN}───────────────────────────────────────────────────────${NC}\n"

# --- DIAGNOSTIC MODE ---
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}           🔍 DIAGNOSTIC MODE${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"

echo -e "${WHITE}📋 Folders in your JumpStart folder:${NC}"
jumpstart_folders=$(find "$JUMPSTART_PATH" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
echo "$jumpstart_folders" | nl
echo ""
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

# Step 2: Find bin/bin2/bin3 folder
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

# Verify testnet path exists (must exist)
if [ ! -d "$TESTNET_PATH" ]; then
  echo -e "${RED}❌ Testnet path not found: $TESTNET_PATH${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Testnet path verified!${NC}"

# Check if bdageth exists
if [ -d "$BDAGETH_PATH" ]; then
  echo -e "${GREEN}✅ Bdageth path verified!${NC}"
else
  echo -e "${YELLOW}⚠️  Bdageth path not found - will only match folders in testnet${NC}"
fi
echo -e "${CYAN}───────────────────────────────────────────────────────${NC}\n"

# --- SHOW MATCHING PREVIEW ---
echo -e "${MAGENTA}🎯 Folder Matching Preview:${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"

MATCH_COUNT=0
declare -a MATCH_LIST

# Define which folders go where
# BdagChain goes to testnet/, others go to testnet/bdageth/
for src_folder in $jumpstart_folders; do
  if [ "$src_folder" = "BdagChain" ]; then
    # BdagChain goes directly in testnet
    if sudo test -d "$TESTNET_PATH/$src_folder"; then
      echo -e "${GREEN}✓ ${src_folder}${NC}"
      echo -e "${WHITE}  📤 Source:      ${JUMPSTART_PATH}/${src_folder}${NC}"
      echo -e "${YELLOW}  📥 Destination: ${TESTNET_PATH}/${src_folder}${NC}"
      echo -e "${CYAN}  ─────────────────────────────────────────────────────${NC}\n"
      MATCH_COUNT=$((MATCH_COUNT + 1))
      MATCH_LIST+=("$src_folder:$TESTNET_PATH")
    else
      echo -e "${RED}✗ ${src_folder}${NC}"
      echo -e "${YELLOW}  ⚠️  Not found in testnet path (will be skipped)${NC}"
      echo -e "${CYAN}  ─────────────────────────────────────────────────────${NC}\n"
    fi
  else
    # All other folders go to testnet/bdageth/
    if sudo test -d "$BDAGETH_PATH/$src_folder"; then
      echo -e "${GREEN}✓ ${src_folder}${NC}"
      echo -e "${WHITE}  📤 Source:      ${JUMPSTART_PATH}/${src_folder}${NC}"
      echo -e "${YELLOW}  📥 Destination: ${BDAGETH_PATH}/${src_folder}${NC}"
      echo -e "${CYAN}  ─────────────────────────────────────────────────────${NC}\n"
      MATCH_COUNT=$((MATCH_COUNT + 1))
      MATCH_LIST+=("$src_folder:$BDAGETH_PATH")
    else
      echo -e "${RED}✗ ${src_folder}${NC}"
      echo -e "${YELLOW}  ⚠️  Not found in bdageth path (will be skipped)${NC}"
      echo -e "${CYAN}  ─────────────────────────────────────────────────────${NC}\n"
    fi
  fi
done

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}📊 Total folders to replace: ${GREEN}${MATCH_COUNT}${NC}\n"

if [ "$MATCH_COUNT" -eq 0 ]; then
  echo -e "${RED}❌ No matching folders found. Nothing to replace.${NC}"
  exit 1
fi

# --- CONFIRMATION ---
read -rp "✓ Do you want to proceed with replacement? (Y/N): " proceed
if [[ ! $proceed =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}ℹ️  Operation cancelled by user.${NC}"
  exit 0
fi
echo ""

# --- FOLDER REPLACEMENT ---
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}           🔄 REPLACEMENT IN PROGRESS${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"

BACKUP_DIR="${HOME}/puddle_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo -e "${YELLOW}💾 Backup location: ${BACKUP_DIR}${NC}\n"

for entry in "${MATCH_LIST[@]}"; do
  src_folder="${entry%%:*}"
  dest_base="${entry##*:}"
  dest_path="$dest_base/$src_folder"
  
  echo -e "${WHITE}🔄 Processing: ${src_folder}${NC}"
  
  # Backup
  backup_path="$BACKUP_DIR/${src_folder}_$(date +%s)"
  echo -e "${YELLOW}   📦 Backing up...${NC}"
  sudo cp -r "$dest_path" "$backup_path"
  
  # Delete old folder
  echo -e "${YELLOW}   🗑️  Deleting old folder...${NC}"
  sudo rm -rf "$dest_path"
  
  # Copy fresh from JumpStart
  echo -e "${YELLOW}   📋 Copying fresh folder...${NC}"
  sudo cp -r "$JUMPSTART_PATH/$src_folder" "$dest_path"
  
  echo -e "${GREEN}   ✅ Complete!${NC}"
  echo -e "${CYAN}   ─────────────────────────────────────────────────────${NC}\n"
done

# --- POST ACTION ---
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}           📋 NEXT STEPS${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}   1. 🚀 Start your Node${NC}"
echo -e "${WHITE}   2. 📊 Check your logs${NC}"
echo -e "${WHITE}   3. ⚠️  Watch for any errors${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"

read -rp "✓ Did the jumpstart work successfully? (Y/N): " answer
if [[ $answer =~ ^[Yy]$ ]]; then
  # Success - keep changes, delete backup
  sudo rm -rf "$BACKUP_DIR"
  echo -e "${GREEN}✅ Changes kept. Backup deleted successfully.${NC}\n"
else
  # Failed - revert changes, restore backup, delete backup
  echo -e "${RED}🔙 Reverting changes from backup...${NC}\n"
  for backup_folder in "$BACKUP_DIR"/*; do
    if [ -d "$backup_folder" ]; then
      folder_name=$(basename "$backup_folder" | sed 's/_[0-9]*$//')
      # Find original location from our match list
      for entry in "${MATCH_LIST[@]}"; do
        if [[ "$entry" == "$folder_name:"* ]]; then
          dest_base="${entry##*:}"
          original_location="$dest_base/$folder_name"
          echo -e "${WHITE}   🔙 Restoring: ${folder_name}${NC}"
          # Delete current folder and restore backup
          sudo rm -rf "$original_location"
          sudo cp -r "$backup_folder" "$original_location"
        fi
      done
    fi
  done
  sudo rm -rf "$BACKUP_DIR"
  echo -e "${GREEN}✅ Changes reverted. Backup restored and deleted.${NC}\n"
fi

# --- END MESSAGE ---
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           ✅ OPERATION COMPLETE${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}        💙 Thank you for using Puddle-De-Leon JumpStart! 💙${NC}"
echo -e "${WHITE}        🚀 Happy Noding! 🚀${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        🔐 Sudo cache cleared automatically${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"
