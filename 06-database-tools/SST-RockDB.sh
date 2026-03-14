#!/bin/bash

# ============================================================================
# BlockDAG .sst Integrity Checker & Auto Backup v2.0
# Enhanced with Security, Modern Sudo Management, and Professional UX
# Created By: ArtX
# For: BlockDAG Investors Community
# ============================================================================

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
SUDO_PREFIX=""

# --- STATISTICS ---
START_TIME=""
TOTAL_CHECKED=0
TOTAL_HEALTHY=0
TOTAL_CORRUPTED=0
TOTAL_SIZE_CORRUPTED=0

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

# Trap handlers for cleanup
trap 'echo -e "\n\n⛔ Script interrupted by user. Cleaning up..."; cleanup_sudo; exit 130' INT TERM
trap 'cleanup_sudo' EXIT

cache_sudo() {
    if [ "$SUDO_CACHED" = false ]; then
        echo -e "${CYAN}🔐 Caching sudo credentials...${NC}"
        echo -e "${YELLOW}Please enter your password:${NC}"
        
        if sudo -v; then
            SUDO_CACHED=true
            SUDO_PREFIX="sudo"
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
# ERROR HANDLING FUNCTION
# ============================================================================

show_error() {
    local title="$1"
    local problem="$2"
    local solution="$3"
    
    echo -e "\n${RED}${BOLD}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║  ⚠️  ERROR: $title${NC}"
    echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Problem:${NC} $problem"
    echo -e "${YELLOW}Solution:${NC} $solution"
    echo -e "${BLUE}Need help? Join our Discord: https://discord.com/invite/sAvyJ89PNm${NC}"
    echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════${NC}\n"
}

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

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

get_file_size() {
    local file="$1"
    local size_bytes=$($SUDO_PREFIX stat -c%s "$file" 2>/dev/null || echo "0")
    
    if [ "$size_bytes" -lt 1024 ]; then
        echo "${size_bytes} B"
    elif [ "$size_bytes" -lt $((1024*1024)) ]; then
        echo "$((size_bytes/1024)) KB"
    elif [ "$size_bytes" -lt $((1024*1024*1024)) ]; then
        echo "$((size_bytes/1024/1024)) MB"
    else
        local gb=$(echo "scale=2; $size_bytes/1024/1024/1024" | bc 2>/dev/null || echo "$((size_bytes/1024/1024/1024))")
        echo "${gb} GB"
    fi
}

format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [ $minutes -gt 0 ]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

# ============================================================================
# MAIN SCRIPT START
# ============================================================================

clear
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}║      🚀 BlockDAG .sst Integrity Checker v2.0 🚀          ║${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}║         💎 BlockDAG Investors Community 💎                ║${NC}"
echo -e "${CYAN}${BOLD}║                  Created By: ArtX                         ║${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# --- Step 1: Sudo Check ---
echo -e "${BLUE}${BOLD}Step 1: Sudo Authentication${NC}"
echo -e "${YELLOW}→ This script requires sudo access for some operations${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    cache_sudo || {
        show_error "Sudo Authentication Failed" \
            "Unable to obtain sudo access" \
            "Please ensure you have sudo privileges and try again"
        exit 1
    }
else
    SUDO_PREFIX=""
    echo -e "${GREEN}✅ Running as root${NC}"
    echo ""
fi

# --- Step 2: Check RocksDB tools ---
echo -e "${BLUE}${BOLD}Step 2: Checking RocksDB Tools${NC}"
echo -e "${YELLOW}→ Verifying sst_dump is installed...${NC}"

if ! command -v sst_dump &> /dev/null; then
    echo -e "${RED}✗ RocksDB tools not detected${NC}"
    echo ""
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║        📦 RocksDB Tools Installation Required            ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}The sst_dump tool is required for integrity checking.${NC}"
    echo ""
    read -p "Would you like to install rocksdb-tools now? (Y/n): " INSTALL_TOOLS
    INSTALL_TOOLS=${INSTALL_TOOLS:-Y}
    
    if [[ $INSTALL_TOOLS =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${CYAN}📥 Installing rocksdb-tools...${NC}"
        $SUDO_PREFIX apt-get update -qq && $SUDO_PREFIX apt-get install -y rocksdb-tools
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ rocksdb-tools installed successfully!${NC}"
        else
            show_error "Installation Failed" \
                "Failed to install rocksdb-tools" \
                "Please install manually:\n   sudo apt-get install rocksdb-tools\n\nThen re-run this script."
            exit 1
        fi
    else
        echo ""
        show_error "Required Tool Missing" \
            "sst_dump is required for this script to function" \
            "Please install rocksdb-tools manually:\n   sudo apt-get install rocksdb-tools\n\nThen re-run this script."
        exit 0
    fi
else
    echo -e "${GREEN}✅ sst_dump detected${NC}"
fi
echo ""

# --- Step 3: Get BdagChain Path ---
echo -e "${BLUE}${BOLD}Step 3: BdagChain Directory${NC}"
read -p "📂 Paste your BlockDAG BdagChain folder path: " BDAG_PATH_RAW
echo ""

echo -e "${CYAN}🛡️  Validating path security...${NC}"
BDAG_PATH=$(sanitize_path "$BDAG_PATH_RAW" "BdagChain folder") || exit 1
BDAG_PATH="${BDAG_PATH%/}"  # Remove trailing slash
echo -e "${GREEN}✅ Path validated successfully${NC}"
echo ""

# Validate path exists
if ! $SUDO_PREFIX test -d "$BDAG_PATH"; then
    show_error "Invalid Path" \
        "Directory does not exist or is not accessible: $BDAG_PATH" \
        "Please check the path and try again"
    exit 1
fi

echo -e "${GREEN}✅ BdagChain directory found: $BDAG_PATH${NC}"
echo ""

# --- Step 4: Select Check Mode ---
echo -e "${BLUE}${BOLD}Step 4: Select Integrity Check Mode${NC}"
echo ""
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║          🔍 SELECT INTEGRITY CHECK MODE 🔍                ║${NC}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${WHITE}  1️⃣  FULL CHECK${NC}"
echo -e "${CYAN}      ├─ Scans all .sst files in directory${NC}"
echo -e "${CYAN}      ├─ Most comprehensive integrity verification${NC}"
echo -e "${YELLOW}      └─ ⚠️  May take hours for large databases${NC}"
echo ""
echo -e "${WHITE}  2️⃣  RECENT FILES CHECK${NC}"
echo -e "${CYAN}      ├─ Checks 10 most recently modified .sst files${NC}"
echo -e "${CYAN}      ├─ Quick verification of latest data${NC}"
echo -e "${GREEN}      └─ ⚡ Recommended for routine checks${NC}"
echo ""
echo -e "${WHITE}  3️⃣  SPECIFIC FILE CHECK${NC}"
echo -e "${CYAN}      ├─ Check a single specific .sst file${NC}"
echo -e "${CYAN}      ├─ Useful for investigating known issues${NC}"
echo -e "${GREEN}      └─ ⚡ Fastest option${NC}"
echo ""
echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
read -p "Enter your choice [1-3]: " MODE
echo ""

FILES=()

case $MODE in
    1)
        # Full check selected - show sub-menu
        echo -e "${YELLOW}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}${BOLD}║              ⚠️  FULL CHECK SELECTED                      ║${NC}"
        echo -e "${YELLOW}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${WHITE}This will scan ALL .sst files in your directory.${NC}"
        echo -e "${YELLOW}For large databases, this may take several hours.${NC}"
        echo ""
        echo -e "${CYAN}What would you like to do?${NC}"
        echo ""
        echo -e "${WHITE}  A)${NC} ${CYAN}Check estimated time${NC} ${BLUE}(scans file count)${NC}"
        echo -e "${WHITE}  B)${NC} ${GREEN}Continue without checking ETA${NC}"
        echo -e "${WHITE}  C)${NC} ${YELLOW}Return to main menu${NC}"
        echo ""
        read -p "Enter your choice [A/B/C]: " FULL_CHECK_CHOICE
        echo ""
        
        case $FULL_CHECK_CHOICE in
            [Aa])
                # Check ETA
                echo -e "${CYAN}🔍 Scanning directory for file count...${NC}"
                FILE_COUNT=$($SUDO_PREFIX find "$BDAG_PATH" -maxdepth 1 -type f -name "*.sst" | wc -l)
                
                if [ "$FILE_COUNT" -eq 0 ]; then
                    show_error "No Files Found" \
                        "No .sst files found in directory" \
                        "Please verify the directory contains .sst files"
                    exit 1
                fi
                
                echo -e "${GREEN}📊 Found: $(printf "%'d" $FILE_COUNT) .sst files${NC}"
                
                # Calculate ETA (assuming ~0.5 seconds per file)
                ESTIMATED_SECONDS=$((FILE_COUNT / 2))
                ESTIMATED_HOURS=$((ESTIMATED_SECONDS / 3600))
                ESTIMATED_MINS=$(((ESTIMATED_SECONDS % 3600) / 60))
                
                if [ $ESTIMATED_HOURS -gt 0 ]; then
                    echo -e "${MAGENTA}⏱️  Estimated time: ~${ESTIMATED_HOURS}h ${ESTIMATED_MINS}m (±30min)${NC}"
                elif [ $ESTIMATED_MINS -gt 0 ]; then
                    echo -e "${MAGENTA}⏱️  Estimated time: ~${ESTIMATED_MINS}m (±5min)${NC}"
                else
                    echo -e "${MAGENTA}⏱️  Estimated time: <1 minute${NC}"
                fi
                
                echo -e "${BLUE}💡 Tip: This may vary based on system performance${NC}"
                echo ""
                read -p "Press Enter to continue or Ctrl+C to cancel..."
                echo ""
                echo -e "${BLUE}🔍 Full check selected — scanning all .sst files...${NC}"
                mapfile -t FILES < <($SUDO_PREFIX find "$BDAG_PATH" -maxdepth 1 -type f -name "*.sst" | sort)
                ;;
            [Bb])
                # Continue without ETA
                echo -e "${BLUE}🔍 Full check selected — scanning all .sst files...${NC}"
                mapfile -t FILES < <($SUDO_PREFIX find "$BDAG_PATH" -maxdepth 1 -type f -name "*.sst" | sort)
                ;;
            [Cc])
                # Return to main menu - restart from Step 4
                echo -e "${YELLOW}ℹ️  Returning to main menu...${NC}"
                echo ""
                exec "$0"
                ;;
            *)
                show_error "Invalid Choice" \
                    "Invalid option selected: $FULL_CHECK_CHOICE" \
                    "Please run the script again"
                exit 1
                ;;
        esac
        ;;
    2)
        echo -e "${BLUE}🔍 Checking 10 most recent .sst files...${NC}"
        mapfile -t FILES < <($SUDO_PREFIX find "$BDAG_PATH" -maxdepth 1 -type f -name "*.sst" -printf "%T@ %p\n" | sort -nr | head -n 10 | cut -d' ' -f2-)
        ;;
    3)
        read -p "🧾 Enter the specific .sst file name (e.g., 000802.sst): " FILE_NAME
        FILE_PATH="$BDAG_PATH/$FILE_NAME"
        if ! $SUDO_PREFIX test -f "$FILE_PATH"; then
            show_error "File Not Found" \
                "File does not exist: $FILE_PATH" \
                "Please check the filename and try again"
            exit 1
        fi
        FILES=("$FILE_PATH")
        ;;
    *)
        show_error "Invalid Choice" \
            "Invalid option selected: $MODE" \
            "Please run the script again and choose 1, 2, or 3"
        exit 1
        ;;
esac

# If no files found, abort
if [ ${#FILES[@]} -eq 0 ]; then
    show_error "No Files Found" \
        "No .sst files found in: $BDAG_PATH" \
        "Please verify the directory contains .sst files"
    exit 1
fi

echo ""

# --- Step 5: Display files to be checked ---
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║              🗂️  FILES TO BE CHECKED                      ║${NC}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

for f in "${FILES[@]}"; do
    FILE_SIZE=$(get_file_size "$f")
    echo -e "   ${CYAN}•${NC} $(basename "$f") ${BLUE}($FILE_SIZE)${NC}"
done

echo ""
echo -e "${WHITE}Total files to check: ${GREEN}${#FILES[@]}${NC}"
echo ""

# Confirmation
read -p "✓ Proceed with integrity check? (Y/n): " CONFIRM
CONFIRM=${CONFIRM:-Y}

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}ℹ️  Operation cancelled by user.${NC}"
    exit 0
fi

echo ""

# --- Step 6: Start Integrity Check ---
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║           🔍 INTEGRITY CHECK IN PROGRESS                  ║${NC}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

START_TIME=$(date +%s)
CORRUPTED_FILES=()

# Check each file
for f in "${FILES[@]}"; do
    # Skip if file doesn't exist
    if ! $SUDO_PREFIX test -f "$f"; then
        continue
    fi
    
    FILE_NAME=$(basename "$f")
    FILE_SIZE=$(get_file_size "$f")
    TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
    
    # Show check start
    echo -ne "${CYAN}🧩 Checking ${FILE_NAME} ${BLUE}(${FILE_SIZE})${NC} ... "
    
    # Use proper integrity check with verify + checksum
    CHECK_START=$(date +%s)
    $SUDO_PREFIX sst_dump --file="$f" --command=verify --verify_checksum > /dev/null 2>&1
    CHECK_EXIT=$?
    CHECK_END=$(date +%s)
    CHECK_DURATION=$((CHECK_END - CHECK_START))
    
    if [ $CHECK_EXIT -eq 0 ]; then
        echo -e "${GREEN}✅ OK${NC} ${MAGENTA}(${CHECK_DURATION}s)${NC}"
        TOTAL_HEALTHY=$((TOTAL_HEALTHY + 1))
    else
        echo -e "${RED}❌ CORRUPTED${NC} ${MAGENTA}(${CHECK_DURATION}s)${NC}"
        CORRUPTED_FILES+=("$f")
        TOTAL_CORRUPTED=$((TOTAL_CORRUPTED + 1))
        
        # Calculate size for corrupted file
        SIZE_BYTES=$($SUDO_PREFIX stat -c%s "$f" 2>/dev/null || echo "0")
        TOTAL_SIZE_CORRUPTED=$((TOTAL_SIZE_CORRUPTED + SIZE_BYTES))
    fi
    
    sleep 0.05
done

# Calculate statistics
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))
FORMATTED_DURATION=$(format_duration $TOTAL_DURATION)

# --- Step 7: Display Summary ---
echo ""
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}                  📊 INTEGRITY CHECK COMPLETE${NC}"
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}✅ Files Checked:    ${WHITE}${TOTAL_CHECKED}${NC}"
echo -e "${BLUE}✅ Healthy Files:    ${GREEN}${TOTAL_HEALTHY}${NC}"
echo -e "${BLUE}❌ Corrupted Files:  ${RED}${TOTAL_CORRUPTED}${NC}"
echo -e "${BLUE}⏱️  Total Time:      ${CYAN}${FORMATTED_DURATION}${NC}"
echo ""

# --- Step 8: Handle Corrupted Files ---
if [ ${#CORRUPTED_FILES[@]} -eq 0 ]; then
    echo -e "${GREEN}${BOLD}🎉 All .sst files are HEALTHY! No corruption detected.${NC}"
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo ""
else
    # Show corrupted files list
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
    echo -e "${RED}${BOLD}❌ CORRUPTED FILES DETECTED:${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
    
    FILE_NUM=1
    for f in "${CORRUPTED_FILES[@]}"; do
        FILE_SIZE=$(get_file_size "$f")
        echo -e "   ${YELLOW}${FILE_NUM}.${NC} ${RED}$(basename "$f")${NC} ${BLUE}(${FILE_SIZE})${NC}"
        ((FILE_NUM++))
    done
    
    echo ""
    
    # Calculate total corrupted size
    if [ $TOTAL_SIZE_CORRUPTED -lt $((1024*1024)) ]; then
        CORRUPT_SIZE="$((TOTAL_SIZE_CORRUPTED/1024)) KB"
    elif [ $TOTAL_SIZE_CORRUPTED -lt $((1024*1024*1024)) ]; then
        CORRUPT_SIZE="$((TOTAL_SIZE_CORRUPTED/1024/1024)) MB"
    else
        CORRUPT_SIZE=$(echo "scale=2; $TOTAL_SIZE_CORRUPTED/1024/1024/1024" | bc 2>/dev/null || echo "$((TOTAL_SIZE_CORRUPTED/1024/1024/1024)) GB")
        CORRUPT_SIZE="${CORRUPT_SIZE} GB"
    fi
    
    echo -e "${MAGENTA}💾 Total corrupted size: ${CORRUPT_SIZE}${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  These corrupted files should be moved to prevent node issues.${NC}"
    echo ""
    
    # Ask for backup path
    read -p "📦 Enter backup folder path (where corrupted files will be moved): " BACKUP_PATH_RAW
    echo ""
    
    echo -e "${CYAN}🛡️  Validating backup path...${NC}"
    BACKUP_PATH=$(sanitize_path "$BACKUP_PATH_RAW" "backup folder") || exit 1
    BACKUP_PATH="${BACKUP_PATH%/}"
    echo -e "${GREEN}✅ Backup path validated${NC}"
    echo ""
    
    # Create backup directory if it doesn't exist
    if ! $SUDO_PREFIX test -d "$BACKUP_PATH"; then
        echo -e "${YELLOW}📁 Backup path does not exist. Creating it now...${NC}"
        $SUDO_PREFIX mkdir -p "$BACKUP_PATH"
        
        if [ $? -ne 0 ]; then
            show_error "Directory Creation Failed" \
                "Failed to create backup directory: $BACKUP_PATH" \
                "Please check permissions and try again"
            exit 1
        fi
        echo -e "${GREEN}✅ Backup directory created${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🚚 Moving corrupted files...${NC}"
    echo ""
    
    # Move each corrupted file
    for f in "${CORRUPTED_FILES[@]}"; do
        FILE_NAME=$(basename "$f")
        echo -ne "   ${CYAN}→${NC} Moving ${FILE_NAME} ... "
        
        if $SUDO_PREFIX mv "$f" "$BACKUP_PATH/"; then
            echo -e "${GREEN}✅ Success${NC}"
        else
            echo -e "${RED}❌ Failed${NC}"
        fi
    done
    
    echo ""
    echo -e "${GREEN}${BOLD}✅ Operation complete! Corrupted files safely isolated.${NC}"
    echo ""
    echo -e "${BLUE}📁 Backup location: ${CYAN}$BACKUP_PATH${NC}"
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo ""
fi

# --- Final Message ---
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        💎 Thank you for using this tool! 💎               ║${NC}"
echo -e "${BLUE}║        🔒 Sudo cache cleared automatically                ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
