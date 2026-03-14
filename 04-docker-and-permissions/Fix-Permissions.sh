#!/bin/bash

# ============================================================================
# Directory Ownership & Permission Fixer v2.1
# Enhanced with modern security and sudo management
# Fixed: More tolerant error handling for counting phase
# By BlockDAG Investors Group
# ============================================================================

set -o pipefail

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

# --- COUNTERS ---
DIR_COUNT=0
FILE_COUNT=0
SCRIPT_COUNT=0

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

# Trap handlers for cleanup - only for critical errors
trap 'echo -e "\n\n⛔ Script interrupted by user. Cleaning up..."; cleanup_sudo; exit 130' INT TERM
trap 'cleanup_sudo' EXIT

# ============================================================================
# PATH SANITIZATION FUNCTION
# ============================================================================

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
# MAIN SCRIPT START
# ============================================================================

clear
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}     📁 Directory Ownership & Permission Fixer 📁${NC}"
echo -e "${GREEN}        💎 by BlockDAG Investors Group 💎${NC}"
echo -e "${MAGENTA}                Version 2.1 Fixed${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}This script will:${NC}"
echo -e "${WHITE}  1. 👤 Change ownership to your user${NC}"
echo -e "${WHITE}  2. 📂 Set proper permissions for directories (755)${NC}"
echo -e "${WHITE}  3. 📄 Set proper permissions for files (644)${NC}"
echo -e "${WHITE}  4. 🔧 Make shell scripts executable${NC}"
echo ""

# Get current user
CURRENT_USER=$(whoami)
echo -e "${CYAN}Current user: ${GREEN}$CURRENT_USER${NC}"
echo ""

# --- PATH INPUT ---
read -rp "📂 Enter the full path to the directory/folder: " DIR_PATH_RAW
echo ""

echo -e "${CYAN}🛡️  Validating path security...${NC}"
DIR_PATH=$(sanitize_path "$DIR_PATH_RAW" "target directory") || exit 1
echo -e "${GREEN}✅ Path validated successfully${NC}"
echo ""

# Remove trailing slash if present
DIR_PATH="${DIR_PATH%/}"

# Check if directory exists
if [ ! -d "$DIR_PATH" ]; then
    echo -e "${RED}❌ Error: Directory does not exist: $DIR_PATH${NC}"
    exit 1
fi

# Check if directory is readable
if [ ! -r "$DIR_PATH" ]; then
    echo -e "${RED}❌ Error: Directory is not readable: $DIR_PATH${NC}"
    echo -e "${YELLOW}💡 Tip: You may need sudo access to read this directory${NC}"
    exit 1
fi

# --- SHOW PREVIEW ---
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}           📋 OPERATION PREVIEW${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Directory to fix:${NC}     ${WHITE}$DIR_PATH${NC}"
echo -e "${BLUE}Owner will be set to:${NC} ${GREEN}$CURRENT_USER:$CURRENT_USER${NC}"
echo ""
echo -e "${YELLOW}Permissions to be set:${NC}"
echo -e "  ${CYAN}•${NC} Directories: ${GREEN}755${NC} (rwxr-xr-x)"
echo -e "  ${CYAN}•${NC} Files:       ${GREEN}644${NC} (rw-r--r--)"
echo -e "  ${CYAN}•${NC} Scripts:     ${GREEN}755${NC} (rwxr-xr-x)"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

read -rp "✓ Continue with these changes? (y/n): " CONFIRM

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}ℹ️  Operation cancelled by user.${NC}"
    exit 0
fi

echo ""

# --- CACHE SUDO ---
echo -e "${WHITE}⚙️  Preparing for permission changes...${NC}"
cache_sudo || { echo -e "${RED}❌ Failed to acquire sudo access. Exiting.${NC}"; exit 1; }

# --- COUNT BEFORE (NON-CRITICAL - ALLOW FAILURES) ---
echo -e "${CYAN}📊 Analyzing directory structure...${NC}"

# Try to count, but don't fail the script if this doesn't work
{
    DIR_COUNT=$(find "$DIR_PATH" -type d 2>/dev/null | wc -l || echo "0")
    FILE_COUNT=$(find "$DIR_PATH" -type f 2>/dev/null | wc -l || echo "0")
    SCRIPT_COUNT=$(find "$DIR_PATH" -type f -name "*.sh" 2>/dev/null | wc -l || echo "0")
} 2>/dev/null

# If counting failed (returned 0 or empty), show unknown
if [ "$DIR_COUNT" = "0" ] && [ "$FILE_COUNT" = "0" ]; then
    echo -e "${YELLOW}⚠️  Could not count items (permission restrictions)${NC}"
    echo -e "${BLUE}Found:${NC} ${YELLOW}Unknown (will fix all accessible items)${NC}"
else
    echo -e "${BLUE}Found:${NC}"
    echo -e "  ${CYAN}•${NC} ${WHITE}$DIR_COUNT${NC} directories"
    echo -e "  ${CYAN}•${NC} ${WHITE}$FILE_COUNT${NC} files"
    echo -e "  ${CYAN}•${NC} ${WHITE}$SCRIPT_COUNT${NC} shell scripts"
fi
echo ""

# --- PROCESSING ---
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}           🔄 PROCESSING${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Change ownership
echo -e "${WHITE}1. 👤 Changing ownership to $CURRENT_USER...${NC}"
if sudo chown -R "$CURRENT_USER:$CURRENT_USER" "$DIR_PATH" 2>/dev/null; then
    echo -e "${GREEN}   ✅ Ownership changed successfully${NC}"
else
    echo -e "${RED}   ❌ Failed to change ownership${NC}"
    echo -e "${YELLOW}   💡 Check if you have sudo privileges${NC}"
    exit 1
fi
echo ""

# Set directory permissions (755)
echo -e "${WHITE}2. 📂 Setting directory permissions (755)...${NC}"
DIRS_FIXED=0
if find "$DIR_PATH" -type d -exec chmod 755 {} \; 2>/dev/null; then
    # Try to count how many were fixed
    DIRS_FIXED=$(find "$DIR_PATH" -type d 2>/dev/null | wc -l || echo "many")
    echo -e "${GREEN}   ✅ Directory permissions set successfully${NC}"
    if [ "$DIRS_FIXED" != "many" ] && [ "$DIRS_FIXED" != "0" ]; then
        echo -e "${BLUE}   📊 Fixed: ${DIRS_FIXED} directories${NC}"
    fi
else
    echo -e "${YELLOW}   ⚠️  Warning: Some directory permissions may not have been set${NC}"
fi
echo ""

# Set file permissions (644)
echo -e "${WHITE}3. 📄 Setting file permissions (644)...${NC}"
FILES_FIXED=0
if find "$DIR_PATH" -type f -exec chmod 644 {} \; 2>/dev/null; then
    # Try to count how many were fixed
    FILES_FIXED=$(find "$DIR_PATH" -type f 2>/dev/null | wc -l || echo "many")
    echo -e "${GREEN}   ✅ File permissions set successfully${NC}"
    if [ "$FILES_FIXED" != "many" ] && [ "$FILES_FIXED" != "0" ]; then
        echo -e "${BLUE}   📊 Fixed: ${FILES_FIXED} files${NC}"
    fi
else
    echo -e "${YELLOW}   ⚠️  Warning: Some file permissions may not have been set${NC}"
fi
echo ""

# Make shell scripts executable
echo -e "${WHITE}4. 🔧 Making shell scripts executable...${NC}"
SCRIPTS_FIXED=0
if find "$DIR_PATH" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null; then
    # Try to count how many were fixed
    SCRIPTS_FIXED=$(find "$DIR_PATH" -type f -name "*.sh" 2>/dev/null | wc -l || echo "many")
    echo -e "${GREEN}   ✅ Shell scripts made executable${NC}"
    if [ "$SCRIPTS_FIXED" != "many" ] && [ "$SCRIPTS_FIXED" != "0" ]; then
        echo -e "${BLUE}   📊 Fixed: ${SCRIPTS_FIXED} scripts${NC}"
    fi
else
    echo -e "${YELLOW}   ⚠️  Warning: Some scripts may not have been made executable${NC}"
fi
echo ""

# --- VERIFICATION ---
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${MAGENTA}           🔍 VERIFICATION${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}Showing ownership and permissions (first 15 items):${NC}"
echo ""
ls -lah "$DIR_PATH" 2>/dev/null | head -n 15 || echo -e "${YELLOW}Could not list directory${NC}"
echo ""

# --- SUMMARY ---
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           ✅ OPERATION COMPLETE!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${WHITE}📊 Summary:${NC}"
echo -e "  ${CYAN}•${NC} ${BLUE}Target directory:${NC}  ${WHITE}$DIR_PATH${NC}"
echo -e "  ${CYAN}•${NC} ${BLUE}Owner:${NC}             ${GREEN}$CURRENT_USER:$CURRENT_USER${NC}"

# Show counts only if we successfully got them
if [ "$DIRS_FIXED" != "0" ] && [ "$DIRS_FIXED" != "many" ]; then
    echo -e "  ${CYAN}•${NC} ${BLUE}Directories fixed:${NC} ${GREEN}$DIRS_FIXED${NC} (755 - rwxr-xr-x)"
else
    echo -e "  ${CYAN}•${NC} ${BLUE}Directories:${NC}       ${GREEN}Fixed${NC} (755 - rwxr-xr-x)"
fi

if [ "$FILES_FIXED" != "0" ] && [ "$FILES_FIXED" != "many" ]; then
    echo -e "  ${CYAN}•${NC} ${BLUE}Files fixed:${NC}       ${GREEN}$FILES_FIXED${NC} (644 - rw-r--r--)"
else
    echo -e "  ${CYAN}•${NC} ${BLUE}Files:${NC}             ${GREEN}Fixed${NC} (644 - rw-r--r--)"
fi

if [ "$SCRIPTS_FIXED" != "0" ] && [ "$SCRIPTS_FIXED" != "many" ]; then
    echo -e "  ${CYAN}•${NC} ${BLUE}Scripts fixed:${NC}     ${GREEN}$SCRIPTS_FIXED${NC} (755 - rwxr-xr-x)"
else
    echo -e "  ${CYAN}•${NC} ${BLUE}Scripts:${NC}           ${GREEN}Fixed${NC} (755 - rwxr-xr-x)"
fi
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}        💎 Thank you for using this tool! 💎${NC}"
echo -e "${BLUE}        🔐 Sudo cache cleared automatically${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""
