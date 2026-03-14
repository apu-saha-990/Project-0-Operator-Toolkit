#!/bin/bash

#============================================================
# CHUNK 1: Script Header & Initial Setup
#============================================================

#############################################################
#                                                           #
#          BlockDAG Wolverine Installer v7.3               #
#          Self-Healing Multi-Node Architecture            #
#                                                           #
#          For BlockDAG Investors Community                #
#          Created By: ArtX                                #
#                                                           #
#############################################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

#############################################################
# GITHUB CONFIGURATION
#############################################################
GITHUB_URL="https://github.com/BlockdagNetworkLabs/blockdag-scripts/archive/refs/heads/develop.zip"
ORIGINAL_PATH="$HOME/Github-Original-Node-Files"

# Sudo management - cache credentials early
echo -e "${CYAN}🔐 Requesting sudo access...${NC}"
if ! sudo -v; then
    echo -e "${RED}❌ Sudo access required. Exiting.${NC}"
    exit 1
fi

# Keep sudo alive in background
(
    while true; do
        sudo -v
        sleep 50
    done
) &
SUDO_KEEPER_PID=$!

# Cleanup function to kill sudo keeper on exit
cleanup_sudo() {
    if [ ! -z "$SUDO_KEEPER_PID" ]; then
        kill "$SUDO_KEEPER_PID" 2>/dev/null
        wait "$SUDO_KEEPER_PID" 2>/dev/null
    fi
    sudo -k
}

# Register cleanup on script exit
trap cleanup_sudo EXIT INT TERM

# Clear screen and show banner
clear
echo -e "${GREEN}${BOLD}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║            BlockDAG Wolverine Installer v7.3                  ║"
echo "║            Self-Healing Multi-Node Architecture               ║"
echo "║                                                               ║"
echo "║            For BlockDAG Investors Community                   ║"
echo "║            Created By: ArtX                                   ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

#============================================================
# CHUNK 2: Dependency Checks
#============================================================

#############################################################
# DEPENDENCY CHECKS
#############################################################

echo -e "${CYAN}🔍 Checking system dependencies...${NC}"
echo ""

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo -e "${YELLOW}Please install Docker first${NC}"
    exit 1
fi

# Check Docker Compose (v1 or v2)
COMPOSE_CMD=""
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "v2")
    echo -e "${GREEN}✅ Docker Compose V2 detected: ${COMPOSE_VERSION}${NC}"
elif docker-compose version &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    COMPOSE_VERSION=$(docker-compose version --short 2>/dev/null || echo "v1")
    echo -e "${GREEN}✅ Docker Compose V1 detected: ${COMPOSE_VERSION}${NC}"
else
    echo -e "${RED}❌ Docker Compose not found${NC}"
    echo -e "${YELLOW}Please install Docker Compose${NC}"
    exit 1
fi

# Check Docker group membership
if ! groups | grep -q docker; then
    echo -e "${YELLOW}⚠️  Your user is not in the docker group${NC}"
    echo -e "${CYAN}Adding user to docker group...${NC}"
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✅ Added to docker group${NC}"
    echo -e "${YELLOW}⚠️  Please log out and log back in for changes to take effect${NC}"
    echo -e "${YELLOW}Then run this script again${NC}"
    exit 0
fi

echo -e "${GREEN}✅ Docker is properly configured${NC}"
echo ""

# Check for unzip
if ! command -v unzip &> /dev/null; then
    echo -e "${YELLOW}⚠️  unzip utility not found${NC}"
    read -p "Install unzip now? (Y/n): " INSTALL_UNZIP
    if [[ "$INSTALL_UNZIP" =~ ^[Yy]$ ]] || [[ -z "$INSTALL_UNZIP" ]]; then
        echo -e "${CYAN}Installing unzip...${NC}"
        sudo apt-get update -qq && sudo apt-get install -y unzip -qq
        echo -e "${GREEN}✅ unzip installed${NC}"
    else
        echo -e "${RED}❌ unzip is required. Exiting.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ All dependencies satisfied${NC}"
echo ""

#============================================================
# CHUNK 3: Github-Original-Node-Files Management with Self-Healing
#============================================================

#############################################################
# Github-Original-Node-Files MANAGEMENT
#############################################################

echo -e "${CYAN}📦 Checking Github-Original-Node-Files...${NC}"
echo ""

if [ -d "$ORIGINAL_PATH/blockdag-scripts" ]; then
    echo -e "${GREEN}✅ Github-Original-Node-Files already exists${NC}"
    
    if [ -f "$ORIGINAL_PATH/blockdag-scripts/.download-date" ]; then
        DOWNLOAD_DATE=$(cat "$ORIGINAL_PATH/blockdag-scripts/.download-date")
        echo -e "${BLUE}📅 Downloaded: ${DOWNLOAD_DATE}${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}🔍 Checking for updates...${NC}"
    
    # Create temporary directory for comparison download
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Download with retry loop (same as v7.2)
    DOWNLOAD_SUCCESS=false
    RETRY_COUNT=0
    MAX_RETRIES=2
    
    while [ $RETRY_COUNT -le $MAX_RETRIES ] && [ "$DOWNLOAD_SUCCESS" = false ]; do
        if [ $RETRY_COUNT -gt 0 ]; then
            echo -e "${YELLOW}Retry attempt $RETRY_COUNT of $MAX_RETRIES...${NC}"
        fi
        
        if wget -q --show-progress "$GITHUB_URL" -O test-blockdag-scripts.zip 2>/dev/null; then
            DOWNLOAD_SUCCESS=true
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -le $MAX_RETRIES ]; then
                echo -e "${RED}❌ Download failed${NC}"
                sleep 2
            fi
        fi
    done
    
    # Handle download failure
    if [ "$DOWNLOAD_SUCCESS" = false ]; then
        echo ""
        echo -e "${RED}❌ Download failed after $MAX_RETRIES attempts${NC}"
        echo ""
        
        read -p "📥 Download link not found. Want to provide new download URL? (Y/n): " PROVIDE_NEW_URL
        
        if [[ "$PROVIDE_NEW_URL" =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Continuing with existing Github-Original-Node-Files${NC}"
            cd "$HOME"
            rm -rf "$TEST_DIR"
            REFERENCE_WAS_UPDATED=false
        else
            # Self-healing process (copied from v7.2)
            echo ""
            echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║         🔧 Self-Healing Download Link Update             ║${NC}"
            echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${YELLOW}🔗 Provide new GitHub download URL${NC}"
            echo -e "${BLUE}Expected format: https://github.com/USER/REPO/archive/refs/heads/BRANCH.zip${NC}"
            echo ""
            read -p "Enter new URL (or Ctrl+C to exit): " NEW_URL
            
            # Validate URL format
            if [[ ! "$NEW_URL" =~ ^https://github\.com/.*/archive/refs/heads/.*\.zip$ ]]; then
                echo -e "${RED}❌ Invalid URL format${NC}"
                echo -e "${YELLOW}Must be a GitHub archive link ending in .zip${NC}"
                cd "$HOME"
                rm -rf "$TEST_DIR"
                exit 1
            fi
            
            # Extract branch name from URL
            BRANCH_NAME=$(echo "$NEW_URL" | sed -n 's|.*/heads/\([^/]*\)\.zip|\1|p')
            echo ""
            echo -e "${CYAN}🔍 Detected branch: ${WHITE}${BRANCH_NAME}${NC}"
            echo ""
            
            # Test new URL
            echo -e "${CYAN}🔍 Testing new download URL...${NC}"
            
            if wget -q --show-progress "$NEW_URL" -O test-new-blockdag-scripts.zip 2>/dev/null; then
                echo -e "${GREEN}✅ Download successful!${NC}"
                
                # Extract and verify
                echo -e "${CYAN}📦 Extracting to verify contents...${NC}"
                unzip -q test-new-blockdag-scripts.zip
                
                # Find extracted folder (dynamic detection)
                EXTRACTED_FOLDER=$(ls -d blockdag-scripts-* 2>/dev/null | head -1)
                
                if [ -z "$EXTRACTED_FOLDER" ]; then
                    echo -e "${RED}❌ No blockdag-scripts folder found after extraction${NC}"
                    echo -e "${YELLOW}Available folders:${NC}"
                    ls -la
                    cd "$HOME"
                    rm -rf "$TEST_DIR"
                    exit 1
                fi
                
                # Verify essential files
                cd "$EXTRACTED_FOLDER"
                
                REQUIRED_FILES=(
                    "docker-compose.yml"
                    "docker-compose.full.yml"
                    "docker-compose.relay.yml"
                    "blockdag.sh"
                    "node.sh"
                    "restart.sh"
                    "restartWithCleanup.sh"
                )
                
                MISSING_FILES=()
                for FILE in "${REQUIRED_FILES[@]}"; do
                    if [ ! -f "$FILE" ]; then
                        MISSING_FILES+=("$FILE")
                    fi
                done
                
                if [ ${#MISSING_FILES[@]} -gt 0 ]; then
                    echo -e "${RED}❌ Missing required files:${NC}"
                    for FILE in "${MISSING_FILES[@]}"; do
                        echo -e "  ${RED}• $FILE${NC}"
                    done
                    cd "$HOME"
                    rm -rf "$TEST_DIR"
                    exit 1
                fi
                
                echo -e "${GREEN}✅ All required files present!${NC}"
                echo ""
                
                # Show what will be updated
                OLD_URL="$GITHUB_URL"
                echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
                echo -e "${CYAN}║              📋 Update Summary                            ║${NC}"
                echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "${YELLOW}Old URL:${NC}"
                echo -e "  ${RED}$OLD_URL${NC}"
                echo ""
                echo -e "${YELLOW}New URL:${NC}"
                echo -e "  ${GREEN}$NEW_URL${NC}"
                echo ""
                echo -e "${YELLOW}Detected folder:${NC} ${WHITE}$EXTRACTED_FOLDER${NC}"
                echo -e "${YELLOW}Branch name:${NC} ${WHITE}$BRANCH_NAME${NC}"
                echo ""
                
                # Cleanup test directory
                cd "$HOME"
                rm -rf "$TEST_DIR"
                
                # Confirm update
                read -p "Press Enter to update script with new URL (or Ctrl+C to cancel)... "
                
                # Self-modify the installer script
                echo ""
                echo -e "${CYAN}⚙️  Updating installer script...${NC}"
                
                SCRIPT_PATH="$0"
                BACKUP_PATH="${SCRIPT_PATH}.backup"
                
                # Create backup
                cp "$SCRIPT_PATH" "$BACKUP_PATH"
                echo -e "${GREEN}✅ Backup created: ${BACKUP_PATH}${NC}"
                
                # Update GITHUB_URL (escape special characters for sed)
                ESCAPED_NEW_URL=$(echo "$NEW_URL" | sed 's/[&/\]/\\&/g')
                sed -i "s|^GITHUB_URL=.*|GITHUB_URL=\"${NEW_URL}\"|" "$SCRIPT_PATH"
                
                echo -e "${GREEN}✅ Script updated with new URL${NC}"
                echo ""
                
                # Show completion message
                echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}${BOLD}║          ✅ Self-Healing Complete!                        ║${NC}"
                echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "${CYAN}🔄 Please rerun the script to continue:${NC}"
                echo -e "   ${WHITE}./Wolverine.sh${NC}"
                echo ""
                echo -e "${BLUE}💾 Original script backed up to:${NC}"
                echo -e "   ${WHITE}${BACKUP_PATH}${NC}"
                echo ""
                
                exit 0
                
            else
                echo -e "${RED}❌ Test download failed with new URL${NC}"
                echo -e "${YELLOW}Please verify the URL is correct and accessible${NC}"
                cd "$HOME"
                rm -rf "$TEST_DIR"
                exit 1
            fi
        fi
    else
        # Download succeeded, proceed with comparison
        echo -e "${GREEN}✅ Download complete${NC}"
        echo -e "${CYAN}📦 Extracting for comparison...${NC}"
        unzip -q test-blockdag-scripts.zip
        
        # Find extracted folder (dynamic detection)
        EXTRACTED_FOLDER=$(ls -d blockdag-scripts-* 2>/dev/null | head -1)
        
        if [ -z "$EXTRACTED_FOLDER" ]; then
            echo -e "${RED}❌ No blockdag-scripts folder found after extraction${NC}"
            cd "$HOME"
            rm -rf "$TEST_DIR"
            REFERENCE_WAS_UPDATED=false
        else
            cd "$EXTRACTED_FOLDER"
            
            # Compare file counts and content
            echo -e "${CYAN}🔍 Comparing files...${NC}"
            
            GITHUB_FILES=($(ls *.sh *.yml 2>/dev/null | sort))
            LOCAL_FILES=($(ls "$ORIGINAL_PATH/blockdag-scripts"/*.sh "$ORIGINAL_PATH/blockdag-scripts"/*.yml 2>/dev/null | xargs -n1 basename | sort))
            
            CHANGES_FOUND=false
            CHANGE_LIST=()
            
            # Check for new files
            for FILE in "${GITHUB_FILES[@]}"; do
                if [ ! -f "$ORIGINAL_PATH/blockdag-scripts/$FILE" ]; then
                    CHANGES_FOUND=true
                    CHANGE_LIST+=("  ${GREEN}+ NEW:${NC}     ${WHITE}$FILE${NC}")
                fi
            done
            
            # Check for modified files (basic comparison by size)
            for FILE in "${GITHUB_FILES[@]}"; do
                if [ -f "$ORIGINAL_PATH/blockdag-scripts/$FILE" ]; then
                    GITHUB_SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE" 2>/dev/null)
                    LOCAL_SIZE=$(stat -f%z "$ORIGINAL_PATH/blockdag-scripts/$FILE" 2>/dev/null || stat -c%s "$ORIGINAL_PATH/blockdag-scripts/$FILE" 2>/dev/null)
                    
                    if [ "$GITHUB_SIZE" != "$LOCAL_SIZE" ]; then
                        CHANGES_FOUND=true
                        CHANGE_LIST+=("  ${YELLOW}≈ CHANGED:${NC} ${WHITE}$FILE${NC}")
                    fi
                fi
            done
            
            # Check for deleted files
            for FILE in "${LOCAL_FILES[@]}"; do
                if [ ! -f "$FILE" ]; then
                    CHANGES_FOUND=true
                    CHANGE_LIST+=("  ${RED}- REMOVED:${NC} ${WHITE}$FILE${NC}")
                fi
            done
            
            cd "$HOME"
            
            if [ "$CHANGES_FOUND" = true ]; then
                echo ""
                echo -e "${YELLOW}⚠️  Changes detected:${NC}"
                for CHANGE in "${CHANGE_LIST[@]}"; do
                    echo -e "$CHANGE"
                done
                echo ""
                
                read -p "Update Github-Original-Node-Files? (Y/n): " UPDATE_REFERENCE
                
                if [[ "$UPDATE_REFERENCE" =~ ^[Nn]$ ]]; then
                    echo -e "${YELLOW}Keeping existing Github-Original-Node-Files${NC}"
                    rm -rf "$TEST_DIR"
                    REFERENCE_WAS_UPDATED=false
                else
                    echo -e "${CYAN}📥 Updating Github-Original-Node-Files...${NC}"
                    
                    # Backup current reference
                    if [ -d "$ORIGINAL_PATH/blockdag-scripts" ]; then
                        BACKUP_NAME="blockdag-scripts-backup-$(date +%Y%m%d-%H%M%S)"
                        mv "$ORIGINAL_PATH/blockdag-scripts" "$ORIGINAL_PATH/$BACKUP_NAME"
                        echo -e "${GREEN}✅ Backup created: ${BACKUP_NAME}${NC}"
                    fi
                    
                    # Copy new files
                    cp -r "$TEST_DIR/$EXTRACTED_FOLDER" "$ORIGINAL_PATH/blockdag-scripts"
                    
                    # Save metadata
                    date "+%Y-%m-%d %H:%M:%S" > "$ORIGINAL_PATH/blockdag-scripts/.download-date"
                    BRANCH_NAME=$(echo "$EXTRACTED_FOLDER" | sed 's/blockdag-scripts-//')
                    echo "$BRANCH_NAME" > "$ORIGINAL_PATH/blockdag-scripts/.branch-name"
                    
                    rm -rf "$TEST_DIR"
                    
                    echo -e "${GREEN}✅ Github-Original-Node-Files updated!${NC}"
                    REFERENCE_WAS_UPDATED=true
                fi
            else
                echo -e "${GREEN}✅ Github-Original-Node-Files is up to date${NC}"
                rm -rf "$TEST_DIR"
                REFERENCE_WAS_UPDATED=false
            fi
        fi
    fi
    
else
    echo -e "${YELLOW}📥 Github-Original-Node-Files not found${NC}"
    mkdir -p "$ORIGINAL_PATH"
    NEED_DOWNLOAD=true
    
    echo ""
    echo -e "${CYAN}📥 Downloading pristine GitHub files...${NC}"
    cd "$ORIGINAL_PATH"
    
    DOWNLOAD_SUCCESS=false
    RETRY_COUNT=0
    MAX_RETRIES=2
    
    # Retry loop
    while [ $RETRY_COUNT -le $MAX_RETRIES ] && [ "$DOWNLOAD_SUCCESS" = false ]; do
        if [ $RETRY_COUNT -gt 0 ]; then
            echo -e "${YELLOW}Retry attempt $RETRY_COUNT of $MAX_RETRIES...${NC}"
        fi
        
        if wget -q --show-progress "$GITHUB_URL" -O blockdag-scripts.zip 2>/dev/null; then
            echo -e "${GREEN}✅ Download complete${NC}"
            DOWNLOAD_SUCCESS=true
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -le $MAX_RETRIES ]; then
                echo -e "${RED}❌ Download failed${NC}"
                sleep 2
            fi
        fi
    done
    
    # If all retries failed, offer self-healing
    if [ "$DOWNLOAD_SUCCESS" = false ]; then
        echo ""
        echo -e "${RED}❌ Download failed after $MAX_RETRIES attempts${NC}"
        echo ""
        
        read -p "📥 Download link not found. Want to provide new download URL? (Y/n): " PROVIDE_NEW_URL
        
        if [[ "$PROVIDE_NEW_URL" =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Installation cancelled${NC}"
            cd "$HOME"
            exit 1
        fi
        
        # Self-healing process
        echo ""
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║         🔧 Self-Healing Download Link Update             ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}🔗 Provide new GitHub download URL${NC}"
        echo -e "${BLUE}Expected format: https://github.com/USER/REPO/archive/refs/heads/BRANCH.zip${NC}"
        echo ""
        read -p "Enter new URL (or Ctrl+C to exit): " NEW_URL
        
        # Validate URL format
        if [[ ! "$NEW_URL" =~ ^https://github\.com/.*/archive/refs/heads/.*\.zip$ ]]; then
            echo -e "${RED}❌ Invalid URL format${NC}"
            echo -e "${YELLOW}Must be a GitHub archive link ending in .zip${NC}"
            exit 1
        fi
        
        # Extract branch name from URL
        BRANCH_NAME=$(echo "$NEW_URL" | sed -n 's|.*/heads/\([^/]*\)\.zip|\1|p')
        echo ""
        echo -e "${CYAN}🔍 Detected branch: ${WHITE}${BRANCH_NAME}${NC}"
        echo ""
        
        # Test new URL
        echo -e "${CYAN}🔍 Testing new download URL...${NC}"
        
        # Create temporary test directory
        TEST_DIR=$(mktemp -d)
        cd "$TEST_DIR"
        
        if wget -q --show-progress "$NEW_URL" -O test-blockdag-scripts.zip 2>/dev/null; then
            echo -e "${GREEN}✅ Download successful!${NC}"
            
            # Extract and verify
            echo -e "${CYAN}📦 Extracting to verify contents...${NC}"
            unzip -q test-blockdag-scripts.zip
            
            # Find extracted folder (dynamic detection)
            EXTRACTED_FOLDER=$(ls -d blockdag-scripts-* 2>/dev/null | head -1)
            
            if [ -z "$EXTRACTED_FOLDER" ]; then
                echo -e "${RED}❌ No blockdag-scripts folder found after extraction${NC}"
                echo -e "${YELLOW}Available folders:${NC}"
                ls -la
                rm -rf "$TEST_DIR"
                exit 1
            fi
            
            # Verify essential files
            cd "$EXTRACTED_FOLDER"
            
            REQUIRED_FILES=(
                "docker-compose.yml"
                "docker-compose.full.yml"
                "docker-compose.relay.yml"
                "blockdag.sh"
                "node.sh"
                "restart.sh"
                "restartWithCleanup.sh"
            )
            
            MISSING_FILES=()
            for FILE in "${REQUIRED_FILES[@]}"; do
                if [ ! -f "$FILE" ]; then
                    MISSING_FILES+=("$FILE")
                fi
            done
            
            if [ ${#MISSING_FILES[@]} -gt 0 ]; then
                echo -e "${RED}❌ Missing required files:${NC}"
                for FILE in "${MISSING_FILES[@]}"; do
                    echo -e "  ${RED}• $FILE${NC}"
                done
                rm -rf "$TEST_DIR"
                exit 1
            fi
            
            echo -e "${GREEN}✅ All required files present!${NC}"
            echo ""
            
            # Show what will be updated
            OLD_URL="$GITHUB_URL"
            echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║              📋 Update Summary                            ║${NC}"
            echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${YELLOW}Old URL:${NC}"
            echo -e "  ${RED}$OLD_URL${NC}"
            echo ""
            echo -e "${YELLOW}New URL:${NC}"
            echo -e "  ${GREEN}$NEW_URL${NC}"
            echo ""
            echo -e "${YELLOW}Detected folder:${NC} ${WHITE}$EXTRACTED_FOLDER${NC}"
            echo -e "${YELLOW}Branch name:${NC} ${WHITE}$BRANCH_NAME${NC}"
            echo ""
            
            # Cleanup test directory
            cd "$HOME"
            rm -rf "$TEST_DIR"
            
            # Confirm update
            read -p "Press Enter to update script with new URL (or Ctrl+C to cancel)... "
            
            # Self-modify the installer script
            echo ""
            echo -e "${CYAN}⚙️  Updating installer script...${NC}"
            
            SCRIPT_PATH="$0"
            BACKUP_PATH="${SCRIPT_PATH}.backup"
            
            # Create backup
            cp "$SCRIPT_PATH" "$BACKUP_PATH"
            echo -e "${GREEN}✅ Backup created: ${BACKUP_PATH}${NC}"
            
            # Update GITHUB_URL (escape special characters for sed)
            ESCAPED_NEW_URL=$(echo "$NEW_URL" | sed 's/[&/\]/\\&/g')
            sed -i "s|^GITHUB_URL=.*|GITHUB_URL=\"${NEW_URL}\"|" "$SCRIPT_PATH"
            
            echo -e "${GREEN}✅ Script updated with new URL${NC}"
            echo ""
            
            # Show completion message
            echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}${BOLD}║          ✅ Self-Healing Complete!                        ║${NC}"
            echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${CYAN}🔄 Please rerun the script to continue installation:${NC}"
            echo -e "   ${WHITE}./installer-v7.3.sh${NC}"
            echo ""
            echo -e "${BLUE}💾 Original script backed up to:${NC}"
            echo -e "   ${WHITE}${BACKUP_PATH}${NC}"
            echo ""
            
            exit 0
            
        else
            echo -e "${RED}❌ Test download failed with new URL${NC}"
            echo -e "${YELLOW}Please verify the URL is correct and accessible${NC}"
            rm -rf "$TEST_DIR"
            exit 1
        fi
    fi
    
    # Original download was successful, proceed with extraction
    echo -e "${CYAN}📂 Extracting files...${NC}"
    unzip -q blockdag-scripts.zip
    
    # Dynamic folder detection (works with any branch name)
    EXTRACTED_FOLDER=$(ls -d blockdag-scripts-* 2>/dev/null | head -1)
    
    if [ -z "$EXTRACTED_FOLDER" ]; then
        echo -e "${RED}❌ No blockdag-scripts folder found after extraction${NC}"
        echo -e "${YELLOW}Available folders:${NC}"
        ls -la
        exit 1
    fi
    
    # Rename to standard name
    mv "$EXTRACTED_FOLDER" blockdag-scripts
    
    # Extract branch name from folder for metadata
    BRANCH_NAME=$(echo "$EXTRACTED_FOLDER" | sed 's/blockdag-scripts-//')
    
    rm blockdag-scripts.zip
    
    # Save metadata
    date "+%Y-%m-%d %H:%M:%S" > blockdag-scripts/.download-date
    echo "$BRANCH_NAME" > blockdag-scripts/.branch-name
    
    echo -e "${GREEN}✅ Original files ready (branch: ${BRANCH_NAME})${NC}"
    
    REFERENCE_WAS_UPDATED=true
fi

echo ""

#============================================================
# CHUNK 3.5: Existing Node Detection
#============================================================

#############################################################
# EXISTING NODE DETECTION
#############################################################

echo -e "${CYAN}🔍 Scanning for existing nodes...${NC}"
echo ""

# Find existing nodes
EXISTING_NODES=($(ls -d $HOME/Node[0-9]* 2>/dev/null | grep -E '/Node[0-9]+$' | sort -V))

UPDATE_MODE=false
STRONGLY_SUGGEST_REBUILD=false

if [ ${#EXISTING_NODES[@]} -gt 0 ]; then
    UPDATE_MODE=true
    
    echo -e "${GREEN}Found ${#EXISTING_NODES[@]} existing node(s):${NC}"
    echo ""
    
    # Show each node with status
    for NODE_PATH in "${EXISTING_NODES[@]}"; do
        NODE_NAME=$(basename "$NODE_PATH")
        
        # Extract node number
        if [[ $NODE_NAME =~ Node([0-9]+) ]]; then
            NODE_NUM=${BASH_REMATCH[1]}
        else
            NODE_NUM="?"
        fi
        
        # Check if node is running
        RUNNING_CONTAINER=$(docker ps -q --filter "name=blockdag-node-${NODE_NUM}-" 2>/dev/null)
        
        if [ ! -z "$RUNNING_CONTAINER" ]; then
            # Get container name to determine mode
            CONTAINER_NAME=$(docker ps --filter "name=blockdag-node-${NODE_NUM}-" --format "{{.Names}}" 2>/dev/null | head -1)
            
            if [[ "$CONTAINER_NAME" == *"-miner"* ]]; then
                MODE="miner"
            elif [[ "$CONTAINER_NAME" == *"-full"* ]]; then
                MODE="full"
            elif [[ "$CONTAINER_NAME" == *"-relay"* ]]; then
                MODE="relay"
            else
                MODE="unknown"
            fi
            
            echo -e "  ${GREEN}🟢 ${NODE_NAME}${NC} - Running (${MODE})"
        else
            echo -e "  ${WHITE}⚪ ${NODE_NAME}${NC} - Stopped"
        fi
    done
    
    echo ""
    
    # If reference was just updated, strongly suggest rebuild
    if [ "$REFERENCE_WAS_UPDATED" = true ]; then
        STRONGLY_SUGGEST_REBUILD=true
    fi
    
else
    echo -e "${YELLOW}No existing nodes found${NC}"
    echo -e "${GREEN}Proceeding to new node installation...${NC}"
    echo ""
    UPDATE_MODE=false
fi

#============================================================
# CHUNK 11: Update Manager Main Menu
#============================================================

#############################################################
# UPDATE MANAGER
#############################################################

if [ "$UPDATE_MODE" = true ]; then
    
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║              🔄 Update Manager                            ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ "$STRONGLY_SUGGEST_REBUILD" = true ]; then
        echo -e "${YELLOW}💡 Github-Original-Node-Files was just updated!${NC}"
        echo -e "${YELLOW}Your existing nodes are running older versions.${NC}"
        echo ""
        echo -e "${WHITE}Recommended: Rebuild nodes to get latest updates${NC}"
        echo ""
        
        read -p "Rebuild nodes with updated files? (Y/n): " REBUILD_RESPONSE
        
        if [[ "$REBUILD_RESPONSE" =~ ^[Nn]$ ]]; then
            PROCEED_TO_REBUILD=false
            SKIP_TO_INSTALL_MENU=true
        else
            PROCEED_TO_REBUILD=true
            SKIP_TO_INSTALL_MENU=false
        fi
        
    else
        echo -e "${WHITE}What would you like to do?${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} Check for updates and rebuild if needed"
        echo -e "  ${CYAN}2)${NC} Install new node (Node$((${#EXISTING_NODES[@]} + 1)))"
        echo -e "  ${CYAN}3)${NC} Exit"
        echo ""
        
        read -p "Enter choice (1-3): " CHOICE
        
        case $CHOICE in
            1)
                # Already checked in CHUNK 3, just show status
                echo ""
                echo -e "${GREEN}✅ Github-Original-Node-Files is up to date${NC}"
                echo ""
                
                read -p "Rebuild nodes anyway? (y/N): " REBUILD_ANYWAY
                
                if [[ "$REBUILD_ANYWAY" =~ ^[Yy]$ ]]; then
                    PROCEED_TO_REBUILD=true
                    SKIP_TO_INSTALL_MENU=false
                else
                    PROCEED_TO_REBUILD=false
                    SKIP_TO_INSTALL_MENU=true
                fi
                ;;
            2)
                PROCEED_TO_REBUILD=false
                SKIP_TO_INSTALL_MENU=false
                ;;
            3)
                echo -e "${YELLOW}Exiting...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Exiting.${NC}"
                exit 1
                ;;
        esac
    fi
    
    # If user chose to skip to install menu, jump to CHUNK 4
    if [ "$SKIP_TO_INSTALL_MENU" = true ]; then
        echo ""
        echo -e "${CYAN}Proceeding to new node installation...${NC}"
        echo ""
        # Continue to CHUNK 4
    fi
    
fi

#============================================================
# CHUNK 14: Interactive Node Rebuild
#============================================================

#############################################################
# INTERACTIVE NODE REBUILD
#############################################################

if [ "$UPDATE_MODE" = true ] && [ "$PROCEED_TO_REBUILD" = true ]; then
    
    echo ""
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║              🔨 Interactive Node Rebuild                  ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    SKIP_ALL=false
    REBUILT_COUNT=0
    SKIPPED_COUNT=0
    
    for NODE_PATH in "${EXISTING_NODES[@]}"; do
        
        if [ "$SKIP_ALL" = true ]; then
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
        fi
        
        NODE_NAME=$(basename "$NODE_PATH")
        
        # Extract node number
        if [[ $NODE_NAME =~ Node([0-9]+) ]]; then
            NODE_NUM=${BASH_REMATCH[1]}
        else
            echo -e "${RED}❌ Invalid node name: $NODE_NAME${NC}"
            continue
        fi
        
        # Read current configuration
        ENV_FILE="$NODE_PATH/blockdag-scripts/.env"
        
        if [ -f "$ENV_FILE" ]; then
            CURRENT_WALLET=$(grep "PUB_ETH_ADDR=" "$ENV_FILE" | cut -d'=' -f2)
        else
            CURRENT_WALLET="Unknown"
        fi
        
        # Check running status
        RUNNING_CONTAINER=$(docker ps -q --filter "name=blockdag-node-${NODE_NUM}-" 2>/dev/null)
        
        if [ ! -z "$RUNNING_CONTAINER" ]; then
            CONTAINER_NAME=$(docker ps --filter "name=blockdag-node-${NODE_NUM}-" --format "{{.Names}}" 2>/dev/null | head -1)
            
            if [[ "$CONTAINER_NAME" == *"-miner"* ]]; then
                CURRENT_MODE="miner"
            elif [[ "$CONTAINER_NAME" == *"-full"* ]]; then
                CURRENT_MODE="full"
            elif [[ "$CONTAINER_NAME" == *"-relay"* ]]; then
                CURRENT_MODE="relay"
            else
                CURRENT_MODE="unknown"
            fi
            
            STATUS="${GREEN}🟢 Running${NC} (${CURRENT_MODE})"
        else
            STATUS="${WHITE}⚪ Stopped${NC}"
        fi
        
        # Extract current ports
        COMPOSE_FILE="$NODE_PATH/blockdag-scripts/docker-compose.yml"
        if [ -f "$COMPOSE_FILE" ]; then
            CURRENT_RPC=$(grep -oP '"\K[0-9]+(?=:38131")' "$COMPOSE_FILE" | head -1)
            CURRENT_JSON=$(grep -oP '"\K[0-9]+(?=:18545")' "$COMPOSE_FILE" | head -1)
            CURRENT_WS=$(grep -oP '"\K[0-9]+(?=:18546")' "$COMPOSE_FILE" | head -1)
            CURRENT_P2P=$(grep -oP '"\K[0-9]+(?=:18150")' "$COMPOSE_FILE" | head -1)
        fi
        
        # Show node info
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}${BOLD}${NODE_NAME}${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${BLUE}Status:${NC}       $STATUS"
        echo -e "  ${BLUE}Wallet:${NC}       ${CURRENT_WALLET:0:10}...${CURRENT_WALLET: -8}"
        echo -e "  ${BLUE}Ports:${NC}        RPC:$CURRENT_RPC | JSON:$CURRENT_JSON | WS:$CURRENT_WS | P2P:$CURRENT_P2P"
        echo ""
        
        read -p "Rebuild ${NODE_NAME}? (Y/n/a=skip all): " REBUILD_RESPONSE
        
        if [[ "$REBUILD_RESPONSE" =~ ^[Aa]$ ]]; then
            echo -e "${YELLOW}Skipping all remaining nodes${NC}"
            SKIP_ALL=true
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
        fi
        
        if [[ "$REBUILD_RESPONSE" =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Skipping ${NODE_NAME}${NC}"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
        fi
        
        # Proceed with rebuild
        echo ""
        echo -e "${CYAN}🔨 Rebuilding ${NODE_NAME}...${NC}"
        echo ""
        
        # Step 1: Backup warning message
echo ""
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  ⚠️  IMPORTANT: Manual Backup Recommendation              ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Before rebuilding, you may want to backup:${NC}"
echo -e "  ${BLUE}•${NC} Wallet file: ${WHITE}${NODE_PATH}/blockdag-scripts/.env${NC}"
echo -e "  ${BLUE}•${NC} Commands file: ${WHITE}${NODE_PATH}/node${NODE_NUM}-commands.txt${NC}"
echo ""
echo -e "${GREEN}✅ Blockchain data will be preserved${NC}"
echo -e "   ${WHITE}(Docker volume bdag_bin${NODE_NUM} is NOT deleted)${NC}"
echo ""
read -p "Press Enter to continue with rebuild... "
        
        # Step 2: Stop running container if any
        if [ ! -z "$RUNNING_CONTAINER" ]; then
            echo ""
            read -p "⚠️  ${NODE_NAME} is running. Stop it before rebuild? (Y/n): " STOP_RESPONSE
            
            if [[ "$STOP_RESPONSE" =~ ^[Yy]$ ]] || [[ -z "$STOP_RESPONSE" ]]; then
                echo -e "${CYAN}⏸️  Stopping ${NODE_NAME}...${NC}"
                docker rm -f $(docker ps -aq --filter "name=blockdag-node-${NODE_NUM}-") 2>/dev/null
                echo -e "${GREEN}✅ Container stopped${NC}"
            fi
        fi
        
        # Step 3: Remove old scripts and YML files
        echo ""
        echo -e "${CYAN}🗑️  Removing old scripts...${NC}"
        cd "$NODE_PATH/blockdag-scripts"
        rm -f *.sh *.yml
        echo -e "${GREEN}✅ Old scripts removed${NC}"
        
        # Step 4: Copy fresh files from Github-Original-Node-Files
        echo -e "${CYAN}📋 Copying fresh files...${NC}"
        cp "$ORIGINAL_PATH/blockdag-scripts"/*.sh .
        cp "$ORIGINAL_PATH/blockdag-scripts"/*.yml .
        echo -e "${GREEN}✅ Fresh files copied${NC}"
        
        # Step 5: Modify YML files (CHUNK 7 logic)
        echo -e "${CYAN}⚙️  Modifying Docker Compose files...${NC}"
        
        COMPOSE_FILES=(
    	    "docker-compose.yml"
            "docker-compose.full.yml"     # WITH DOT
            "docker-compose.relay.yml"    # WITH DOT
        )
        
        for COMPOSE_FILE in "${COMPOSE_FILES[@]}"; do
            if [ -f "$COMPOSE_FILE" ]; then
                # Remove version line
                sed -i '1d' "$COMPOSE_FILE"
                
                # Update container names
                sed -i "s/container_name: blockdag-miner-testnet/container_name: blockdag-node-${NODE_NUM}-miner/" "$COMPOSE_FILE"
                sed -i "s/container_name: blockdag-full-testnet/container_name: blockdag-node-${NODE_NUM}-full/" "$COMPOSE_FILE"
                sed -i "s/container_name: blockdag-relay-testnet/container_name: blockdag-node-${NODE_NUM}-relay/" "$COMPOSE_FILE"
                
                # Update volume names
                sed -i "s/- bdag_bin:/- bdag_bin${NODE_NUM}:/" "$COMPOSE_FILE"
                sed -i "s/^  bdag_bin: {}/  bdag_bin${NODE_NUM}: {}/" "$COMPOSE_FILE"
                
                # Update ports (preserve current ports)
                sed -i "s/\"38131:38131\"/\"${CURRENT_RPC}:38131\"/" "$COMPOSE_FILE"
                sed -i "s/\"18545:18545\"/\"${CURRENT_JSON}:18545\"/" "$COMPOSE_FILE"
                sed -i "s/\"18546:18546\"/\"${CURRENT_WS}:18546\"/" "$COMPOSE_FILE"
                sed -i "s/\"18150:18150\"/\"${CURRENT_P2P}:18150\"/" "$COMPOSE_FILE"
            fi
        done
        
        echo -e "${GREEN}✅ Docker Compose files updated${NC}"
        
        # Step 6: Create numbered scripts (CHUNK 8 logic - DYNAMIC!)
        echo -e "${CYAN}⚙️  Creating numbered scripts...${NC}"
        
        # Get list of ALL scripts (dynamic detection)
        SCRIPT_LIST=($(ls *.sh 2>/dev/null | grep -v "^docker" | grep -v "^install"))
        
        echo -e "${BLUE}  Found ${#SCRIPT_LIST[@]} script(s) to process${NC}"
        echo ""
        
        for SCRIPT_FILE in "${SCRIPT_LIST[@]}"; do
            BASENAME="${SCRIPT_FILE%.sh}"
            
            echo -e "${BLUE}  Processing $SCRIPT_FILE...${NC}"
            
            # Special handling for known scripts
            if [ "$SCRIPT_FILE" = "blockdag.sh" ]; then
                # Create blockdagN.sh with node.sh reference update
                sed 's|"\$SCRIPT_DIR"/node\.sh|"\$SCRIPT_DIR"/node'${NODE_NUM}'.sh|' blockdag.sh > blockdag${NODE_NUM}.sh
                
                # Add auto-cleanup
                sed -i '/"$SCRIPT_DIR"\/node/i\
# Auto-cleanup: Remove other mode containers to enable mode switching\
docker rm -f blockdag-node-'${NODE_NUM}'-miner 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUM}'-full 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUM}'-relay 2>/dev/null || true\
' blockdag${NODE_NUM}.sh
                
                chmod +x blockdag${NODE_NUM}.sh
                echo -e "${GREEN}    ✓ blockdag${NODE_NUM}.sh${NC}"
                
            elif [ "$SCRIPT_FILE" = "node.sh" ]; then
                # Create nodeN.sh with project names
                cp node.sh node${NODE_NUM}.sh
                
                sed -i "s/docker compose version/docker compose -p blockdag-node-${NODE_NUM} version/" node${NODE_NUM}.sh
                sed -i "s/compose_cmd=(docker compose)/compose_cmd=(docker compose -p blockdag-node-${NODE_NUM})/" node${NODE_NUM}.sh
                sed -i "s/compose_cmd=(docker-compose)/compose_cmd=(docker-compose -p blockdag-node-${NODE_NUM})/" node${NODE_NUM}.sh
                sed -i "s/docker compose -f/docker compose -p blockdag-node-${NODE_NUM} -f/" node${NODE_NUM}.sh
                sed -i "s/docker-compose -f/docker-compose -p blockdag-node-${NODE_NUM} -f/" node${NODE_NUM}.sh
                
                chmod +x node${NODE_NUM}.sh
                echo -e "${GREEN}    ✓ node${NODE_NUM}.sh${NC}"
                
            elif [ "$SCRIPT_FILE" = "restart.sh" ] || [ "$SCRIPT_FILE" = "restartWithCleanup.sh" ]; then
                # Create restartN.sh or restartWithCleanupN.sh
                sed 's|"\$SCRIPT_DIR"/node\.sh|"\$SCRIPT_DIR"/node'${NODE_NUM}'.sh|g' "$SCRIPT_FILE" > "${BASENAME}${NODE_NUM}.sh"
                
                # Add project names
                sed -i "s/docker compose version/docker compose -p blockdag-node-${NODE_NUM} version/" "${BASENAME}${NODE_NUM}.sh"
                sed -i "s/compose_cmd=(docker compose)/compose_cmd=(docker compose -p blockdag-node-${NODE_NUM})/" "${BASENAME}${NODE_NUM}.sh"
                sed -i "s/compose_cmd=(docker-compose)/compose_cmd=(docker-compose -p blockdag-node-${NODE_NUM})/" "${BASENAME}${NODE_NUM}.sh"
                sed -i 's/"\${compose_cmd\[@\]}" -f/"${compose_cmd[@]}" -p blockdag-node-'${NODE_NUM}' -f/' "${BASENAME}${NODE_NUM}.sh"
                
                # Add auto-cleanup
                sed -i '/"$SCRIPT_DIR"\/node/i\
# Auto-cleanup: Remove other mode containers before restart\
docker rm -f blockdag-node-'${NODE_NUM}'-miner 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUM}'-full 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUM}'-relay 2>/dev/null || true\
' "${BASENAME}${NODE_NUM}.sh"
                
                chmod +x "${BASENAME}${NODE_NUM}.sh"
                echo -e "${GREEN}    ✓ ${BASENAME}${NODE_NUM}.sh${NC}"
                
            elif [ "$SCRIPT_FILE" = "stop.sh" ]; then
                # Create stopN.sh
                sed 's|"\$SCRIPT_DIR"/node\.sh|"\$SCRIPT_DIR"/node'${NODE_NUM}'.sh|g' stop.sh > stop${NODE_NUM}.sh
                
                # Add project names if script uses docker compose
                if grep -q "docker compose\|docker-compose" stop${NODE_NUM}.sh; then
                    sed -i "s/docker compose version/docker compose -p blockdag-node-${NODE_NUM} version/" stop${NODE_NUM}.sh
                    sed -i "s/compose_cmd=(docker compose)/compose_cmd=(docker compose -p blockdag-node-${NODE_NUM})/" stop${NODE_NUM}.sh
                    sed -i "s/compose_cmd=(docker-compose)/compose_cmd=(docker-compose -p blockdag-node-${NODE_NUM})/" stop${NODE_NUM}.sh
                    sed -i "s/docker compose -f/docker compose -p blockdag-node-${NODE_NUM} -f/" stop${NODE_NUM}.sh
                    sed -i "s/docker-compose -f/docker-compose -p blockdag-node-${NODE_NUM} -f/" stop${NODE_NUM}.sh
                fi
                
                chmod +x stop${NODE_NUM}.sh
                echo -e "${GREEN}    ✓ stop${NODE_NUM}.sh${NC}"
                
            else
                # Unknown script - smart default handler
                echo -e "${YELLOW}    ⚠️  Unknown script: $SCRIPT_FILE (applying smart defaults)${NC}"
                
                # Copy and update node.sh reference
                sed 's|"\$SCRIPT_DIR"/node\.sh|"\$SCRIPT_DIR"/node'${NODE_NUM}'.sh|g' "$SCRIPT_FILE" > "${BASENAME}${NODE_NUM}.sh"
                
                # Check if script uses docker compose
                if grep -q "docker compose\|docker-compose" "${BASENAME}${NODE_NUM}.sh"; then
                    echo -e "${YELLOW}      → Detected docker compose usage - adding isolation${NC}"
                    
                    sed -i "s/docker compose version/docker compose -p blockdag-node-${NODE_NUM} version/" "${BASENAME}${NODE_NUM}.sh"
                    sed -i "s/compose_cmd=(docker compose)/compose_cmd=(docker compose -p blockdag-node-${NODE_NUM})/" "${BASENAME}${NODE_NUM}.sh"
                    sed -i "s/compose_cmd=(docker-compose)/compose_cmd=(docker-compose -p blockdag-node-${NODE_NUM})/" "${BASENAME}${NODE_NUM}.sh"
                    sed -i "s/docker compose -f/docker compose -p blockdag-node-${NODE_NUM} -f/" "${BASENAME}${NODE_NUM}.sh"
                    sed -i "s/docker-compose -f/docker-compose -p blockdag-node-${NODE_NUM} -f/" "${BASENAME}${NODE_NUM}.sh"
                fi
                
                # Check if script starts containers
                if grep -q "docker compose.*up -d\|docker-compose.*up -d" "${BASENAME}${NODE_NUM}.sh"; then
                    echo -e "${YELLOW}      → Detected container startup - adding auto-cleanup${NC}"
                    
                    sed -i '/docker compose.*up -d/i\
docker rm -f blockdag-node-'${NODE_NUM}'-miner 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUM}'-full 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUM}'-relay 2>/dev/null || true\
' "${BASENAME}${NODE_NUM}.sh"
                fi
                
                chmod +x "${BASENAME}${NODE_NUM}.sh"
                echo -e "${GREEN}    ✓ ${BASENAME}${NODE_NUM}.sh${NC}"
            fi
        done
        
        echo ""
        
        # UPDATE 12: Universal Reference Updater
        echo -e "${CYAN}🔗 Updating script cross-references...${NC}"
        
        # Get list of all numbered scripts we just created
        NUMBERED_SCRIPTS=($(ls *${NODE_NUM}.sh 2>/dev/null))
        
        # Extract base names for reference updating
        SCRIPT_BASENAMES=()
        for NUMBERED_SCRIPT in "${NUMBERED_SCRIPTS[@]}"; do
            # Extract base name (blockdag1.sh → blockdag)
            SCRIPT_BASE="${NUMBERED_SCRIPT%${NODE_NUM}.sh}"
            SCRIPT_BASENAMES+=("$SCRIPT_BASE")
        done
        
        # Remove duplicates
        SCRIPT_BASENAMES=($(echo "${SCRIPT_BASENAMES[@]}" | tr ' ' '\n' | sort -u))
        
        # Update ALL cross-references in ALL numbered scripts
        for BASENAME in "${SCRIPT_BASENAMES[@]}"; do
            # Update references: "$SCRIPT_DIR"/basename.sh → "$SCRIPT_DIR"/basenameN.sh
            for NUMBERED_SCRIPT in "${NUMBERED_SCRIPTS[@]}"; do
                sed -i 's|"\$SCRIPT_DIR"/'${BASENAME}'\.sh|"\$SCRIPT_DIR"/'${BASENAME}${NODE_NUM}'.sh|g' "$NUMBERED_SCRIPT"
            done
        done
        
        echo -e "${GREEN}✅ All cross-references updated${NC}"
        
        # Remove original unnumbered scripts
        echo -e "${CYAN}🗑️  Cleaning up original scripts...${NC}"
        for SCRIPT_FILE in "${SCRIPT_LIST[@]}"; do
            rm -f "$SCRIPT_FILE"
        done
        echo -e "${GREEN}✅ Original scripts removed${NC}"
        
        # Step 7: Generate commands file (CHUNK 9 logic - DYNAMIC!)
        echo -e "${CYAN}📋 Generating commands file...${NC}"
        
        COMMANDS_FILE="$NODE_PATH/node${NODE_NUM}-commands.txt"
        GENERATION_TIME=$(date "+%Y-%m-%d %H:%M:%S %Z")
        
        # Detect which scripts exist
        HAS_START=false
        HAS_STOP=false
        HAS_RESTART=false
        HAS_CLEANUP=false
        
        [ -f "blockdag${NODE_NUM}.sh" ] && HAS_START=true
        [ -f "stop${NODE_NUM}.sh" ] && HAS_STOP=true
        [ -f "restart${NODE_NUM}.sh" ] && HAS_RESTART=true
        [ -f "restartWithCleanup${NODE_NUM}.sh" ] && HAS_CLEANUP=true
        
        # Generate commands file
        cat > "$COMMANDS_FILE" << 'COMMANDS_EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
COMMANDS_EOF

        echo "║              Node${NODE_NUM} Management Commands                        ║" >> "$COMMANDS_FILE"
        
        cat >> "$COMMANDS_FILE" << 'COMMANDS_EOF'
║              For BlockDAG Investors Community                 ║
║              Created By: ArtX                                 ║
║                                                               ║
COMMANDS_EOF

        echo "║              Generated: ${GENERATION_TIME}              ║" >> "$COMMANDS_FILE"
        
        cat >> "$COMMANDS_FILE" << 'COMMANDS_EOF'
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

📂 Installation Path:
COMMANDS_EOF

        echo "   cd $NODE_PATH/blockdag-scripts" >> "$COMMANDS_FILE"
        
        cat >> "$COMMANDS_FILE" << 'COMMANDS_EOF'

─────────────────────────────────────────────────────────────────

COMMANDS_EOF

        # START section (always present)
        if [ "$HAS_START" = true ]; then
            cat >> "$COMMANDS_FILE" << COMMANDS_EOF
🚀 START NODE${NODE_NUM}:
   Choose one of the following modes:

   ./blockdag${NODE_NUM}.sh miner     # Start as Miner (mining rewards)
   ./blockdag${NODE_NUM}.sh full      # Start as Full (validation only)
   ./blockdag${NODE_NUM}.sh relay     # Start as Relay (gateway/routing)

─────────────────────────────────────────────────────────────────

COMMANDS_EOF
        fi
        
        # STOP section (if stop.sh exists)
        if [ "$HAS_STOP" = true ]; then
            cat >> "$COMMANDS_FILE" << COMMANDS_EOF
🛑 STOP NODE${NODE_NUM}:
   ./stop${NODE_NUM}.sh all        # Stop all modes (recommended)
   ./stop${NODE_NUM}.sh miner      # Stop miner mode only
   ./stop${NODE_NUM}.sh full       # Stop full mode only
   ./stop${NODE_NUM}.sh relay      # Stop relay mode only

─────────────────────────────────────────────────────────────────

⚠️ EMERGENCY FORCE STOP (Not Recommended):
   docker rm -f \$(docker ps -aq --filter "name=blockdag-node-${NODE_NUM}-")
   
   ⚠️ WARNING: This forcefully removes containers.
   Only use if ./stop${NODE_NUM}.sh fails.

─────────────────────────────────────────────────────────────────

COMMANDS_EOF
        else
            # No stop.sh - show emergency only
            cat >> "$COMMANDS_FILE" << COMMANDS_EOF
🛑 STOP NODE${NODE_NUM}:
   docker rm -f \$(docker ps -aq --filter "name=blockdag-node-${NODE_NUM}-")

─────────────────────────────────────────────────────────────────

COMMANDS_EOF
        fi
        
        # LOGS section (always present)
        cat >> "$COMMANDS_FILE" << COMMANDS_EOF
📊 VIEW LOGS:
   docker logs -f \$(docker ps -q --filter "name=blockdag-node-${NODE_NUM}-")

─────────────────────────────────────────────────────────────────

COMMANDS_EOF
        
        # RESTART section (if restart.sh exists)
        if [ "$HAS_RESTART" = true ]; then
            cat >> "$COMMANDS_FILE" << COMMANDS_EOF
🔄 RESTART NODE${NODE_NUM} (Not for Swapping Mode):
   
   ./restart${NODE_NUM}.sh miner      # Restart as Miner
   ./restart${NODE_NUM}.sh full       # Restart as Full
   ./restart${NODE_NUM}.sh relay      # Restart as Relay

─────────────────────────────────────────────────────────────────

COMMANDS_EOF
        fi
        
        # RESTART WITH CLEANUP section (if exists)
        if [ "$HAS_CLEANUP" = true ]; then
            cat >> "$COMMANDS_FILE" << COMMANDS_EOF
🧹 RESTART WITH CLEANUP (Sync From Genesis):

   ./restartWithCleanup${NODE_NUM}.sh miner
   ./restartWithCleanup${NODE_NUM}.sh full
   ./restartWithCleanup${NODE_NUM}.sh relay

─────────────────────────────────────────────────────────────────

COMMANDS_EOF
        fi
        
        # TIP box
        cat >> "$COMMANDS_FILE" << COMMANDS_EOF
╔═══════════════════════════════════════════════════════════════╗
║  💡 TIP: Permission Errors                                    ║
╟───────────────────────────────────────────────────────────────╢
║  If any command fails with permission error, add 'sudo'       ║
║  before the command.                                          ║
║                                                               ║
COMMANDS_EOF
        
        echo "║  Example: sudo ./blockdag${NODE_NUM}.sh miner                           ║" >> "$COMMANDS_FILE"
        
        cat >> "$COMMANDS_FILE" << 'COMMANDS_EOF'
╚═══════════════════════════════════════════════════════════════╝

─────────────────────────────────────────────────────────────────

🗑️ COMPLETE NODE REMOVAL:

╔═══════════════════════════════════════════════════════════════╗
║  ⚠️  DANGER ZONE - Permanent Deletion                         ║
╚═══════════════════════════════════════════════════════════════╝

If you want to completely remove this node:

COMMANDS_EOF

        cat >> "$COMMANDS_FILE" << COMMANDS_EOF
  sudo docker compose -p blockdag-node-${NODE_NUM} down -v && \\
  sudo docker volume rm bdag_bin${NODE_NUM} 2>/dev/null ; \\
  sudo docker network prune -f && \\
  sudo rm -rf $NODE_PATH

⚠️ WARNING: This permanently deletes:
  • All containers for Node${NODE_NUM} (miner/full/relay)
  • Volume: bdag_bin${NODE_NUM} (all blockchain data)
  • Folder: $NODE_PATH

Use only if you want to completely remove this node!

─────────────────────────────────────────────────────────────────

📊 CONFIGURATION:
   Wallet:       $CURRENT_WALLET
   
   Ports:
   - RPC:        $CURRENT_RPC
   - JSON-RPC:   $CURRENT_JSON
   - WS-RPC:     $CURRENT_WS
   - P2P:        $CURRENT_P2P

─────────────────────────────────────────────────────────────────

📋 CONTAINER NAMES:
   Miner:  blockdag-node-${NODE_NUM}-miner
   Full:   blockdag-node-${NODE_NUM}-full
   Relay:  blockdag-node-${NODE_NUM}-relay

─────────────────────────────────────────────────────────────────
COMMANDS_EOF

        echo -e "${GREEN}✅ Commands file generated${NC}"
        
        # Step 8: Success message
        echo ""
        echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}${BOLD}║          ✅ ${NODE_NAME} Rebuild Complete!                 ║${NC}"
        echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        REBUILT_COUNT=$((REBUILT_COUNT + 1))
        
        cd "$HOME"
    done
    
    # Show rebuild summary
    echo ""
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║              📊 Rebuild Summary                            ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}✅ Rebuilt:${NC}  ${REBUILT_COUNT} node(s)"
    echo -e "  ${YELLOW}⏭️  Skipped:${NC}  ${SKIPPED_COUNT} node(s)"
    echo ""
    
    # (Remove this entire section - no backups to list)
    
    echo -e "${WHITE}Next steps:${NC}"
    echo -e "  1. Navigate to node directory"
    echo -e "  2. Start your node: ${CYAN}./blockdag1.sh miner${NC}"
    echo -e "  3. View commands: ${CYAN}cat node1-commands.txt${NC}"
    echo ""
    
    # Exit after rebuild
    echo -e "${GREEN}${BOLD}Wolverine rebuild complete! 🎉${NC}"
    echo ""
    exit 0
fi

#============================================================
# CHUNK 4: Node Detection & Port Configuration
#============================================================

#############################################################
# NODE DETECTION & PORT CONFIGURATION
#############################################################

echo -e "${CYAN}🔍 Detecting existing BlockDAG nodes...${NC}"
echo ""

# Find existing nodes (already done in CHUNK 3.5, but repeat for clarity in new install flow)
EXISTING_NODES=($(ls -d $HOME/Node[0-9]* 2>/dev/null | grep -E '/Node[0-9]+$' | sort -V))

if [ ${#EXISTING_NODES[@]} -eq 0 ]; then
    echo -e "${YELLOW}No existing nodes found${NC}"
    echo -e "${GREEN}This will be your first node!${NC}"
    FIRST_NODE=true
    NODE_NUMBER=1
else
    echo -e "${GREEN}Found ${#EXISTING_NODES[@]} existing node(s):${NC}"
    for NODE_PATH in "${EXISTING_NODES[@]}"; do
        NODE_NAME=$(basename "$NODE_PATH")
        echo -e "  ${BLUE}• ${NODE_NAME}${NC}"
    done
    echo ""
    
    read -p "Is this your first BlockDAG node? (y/N): " FIRST_NODE_INPUT
    
    if [[ "$FIRST_NODE_INPUT" =~ ^[Yy]$ ]]; then
        FIRST_NODE=true
        NODE_NUMBER=1
        echo -e "${YELLOW}⚠️  Warning: Node1 directory will be created/overwritten${NC}"
    else
        FIRST_NODE=false
        
        # Auto-detect next node number
        HIGHEST_NODE=0
        for NODE_PATH in "${EXISTING_NODES[@]}"; do
            NODE_NAME=$(basename "$NODE_PATH")
            if [[ $NODE_NAME =~ Node([0-9]+) ]]; then
                NUM=${BASH_REMATCH[1]}
                if [ $NUM -gt $HIGHEST_NODE ]; then
                    HIGHEST_NODE=$NUM
                fi
            fi
        done
        
        NODE_NUMBER=$((HIGHEST_NODE + 1))
        echo -e "${GREEN}✅ This will be Node${NODE_NUMBER}${NC}"
    fi
fi

echo ""

# Set install path
INSTALL_PATH="$HOME/Node${NODE_NUMBER}"

# Port configuration
if [ "$FIRST_NODE" = true ]; then
    # Default ports for first node
    RPC_PORT=38131
    JSONRPC_PORT=18545
    WSRPC_PORT=18546
    P2P_PORT=18150
    
    echo -e "${CYAN}📊 Default Port Configuration:${NC}"
else
    # Extract ports from existing nodes and increment
    echo -e "${CYAN}🔍 Scanning existing node ports...${NC}"
    
    HIGHEST_RPC=38130
    HIGHEST_JSONRPC=18544
    HIGHEST_WSRPC=18545
    HIGHEST_P2P=18149
    
    for NODE_PATH in "${EXISTING_NODES[@]}"; do
        # Check all possible compose files (miner, full, relay)
        for COMPOSE_FILE in "$NODE_PATH/blockdag-scripts/docker-compose.yml" \
                            "$NODE_PATH/blockdag-scripts/docker-compose.full.yml" \
                            "$NODE_PATH/blockdag-scripts/docker-compose.relay.yml"; do
            
            if [ -f "$COMPOSE_FILE" ]; then
                # Extract RPC port
                FOUND_RPC=$(grep -oP '"\K[0-9]+(?=:38131")' "$COMPOSE_FILE" | head -1)
                [ ! -z "$FOUND_RPC" ] && [ $FOUND_RPC -gt $HIGHEST_RPC ] && HIGHEST_RPC=$FOUND_RPC
                
                # Extract JSONRPC port
                FOUND_JSON=$(grep -oP '"\K[0-9]+(?=:18545")' "$COMPOSE_FILE" | head -1)
                [ ! -z "$FOUND_JSON" ] && [ $FOUND_JSON -gt $HIGHEST_JSONRPC ] && HIGHEST_JSONRPC=$FOUND_JSON
                
                # Extract WSRPC port
                FOUND_WS=$(grep -oP '"\K[0-9]+(?=:18546")' "$COMPOSE_FILE" | head -1)
                [ ! -z "$FOUND_WS" ] && [ $FOUND_WS -gt $HIGHEST_WSRPC ] && HIGHEST_WSRPC=$FOUND_WS
                
                # Extract P2P port
                FOUND_P2P=$(grep -oP '"\K[0-9]+(?=:18150")' "$COMPOSE_FILE" | head -1)
                [ ! -z "$FOUND_P2P" ] && [ $FOUND_P2P -gt $HIGHEST_P2P ] && HIGHEST_P2P=$FOUND_P2P
            fi
        done
    done
    
    # Increment to next available ports
    RPC_PORT=$((HIGHEST_RPC + 1))
    JSONRPC_PORT=$((HIGHEST_JSONRPC + 2))
    WSRPC_PORT=$((HIGHEST_WSRPC + 2))
    P2P_PORT=$((HIGHEST_P2P + 1))
    
    echo -e "${GREEN}✅ Port scan complete${NC}"
    echo ""
    echo -e "${CYAN}📊 Auto-configured Port Assignment:${NC}"
fi

echo -e "  ${BLUE}RPC Port:     ${WHITE}${RPC_PORT}${NC}"
echo -e "  ${BLUE}JSON-RPC:     ${WHITE}${JSONRPC_PORT}${NC}"
echo -e "  ${BLUE}WS-RPC:       ${WHITE}${WSRPC_PORT}${NC}"
echo -e "  ${BLUE}P2P Port:     ${WHITE}${P2P_PORT}${NC}"
echo ""

#============================================================
# CHUNK 5: Wallet Configuration
#============================================================

#############################################################
# WALLET CONFIGURATION
#############################################################

echo -e "${CYAN}💰 Wallet Configuration${NC}"
echo ""

# Wallet address input
while true; do
    read -p "Enter your EVM wallet address: " WALLET_ADDRESS
    
    # Basic validation
    if [[ $WALLET_ADDRESS =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo -e "${GREEN}✅ Valid wallet address${NC}"
        break
    else
        echo -e "${RED}❌ Invalid wallet address format${NC}"
        echo -e "${YELLOW}Expected format: 0x followed by 40 hexadecimal characters${NC}"
        echo ""
    fi
done

echo ""

# Installation summary
echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║                  Installation Summary                     ║${NC}"
echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Node Number:${NC}      ${WHITE}Node${NODE_NUMBER}${NC}"
echo -e "  ${CYAN}Install Path:${NC}     ${WHITE}${INSTALL_PATH}${NC}"
echo -e "  ${CYAN}Wallet:${NC}           ${WHITE}${WALLET_ADDRESS:0:10}...${WALLET_ADDRESS: -8}${NC}"
echo ""
echo -e "  ${CYAN}Ports:${NC}"
echo -e "    ${BLUE}RPC:${NC}            ${WHITE}${RPC_PORT}${NC}"
echo -e "    ${BLUE}JSON-RPC:${NC}       ${WHITE}${JSONRPC_PORT}${NC}"
echo -e "    ${BLUE}WS-RPC:${NC}         ${WHITE}${WSRPC_PORT}${NC}"
echo -e "    ${BLUE}P2P:${NC}            ${WHITE}${P2P_PORT}${NC}"
echo ""

read -p "Proceed with installation? (Y/n): " CONFIRM_INSTALL

if [[ "$CONFIRM_INSTALL" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Installation cancelled${NC}"
    exit 0
fi

echo ""

#============================================================
# CHUNK 6: Copy Files from Github-Original-Node-Files
#============================================================

#############################################################
# COPY FILES FROM Github-Original-Node-Files
#############################################################

echo -e "${CYAN}🔧 Setting up Node${NODE_NUMBER} workspace...${NC}"
echo ""

# Create install directory
if [ -d "$INSTALL_PATH" ]; then
    echo -e "${YELLOW}⚠️  Node${NODE_NUMBER} directory already exists${NC}"
    read -p "Remove and reinstall? (Y/n): " REMOVE_EXISTING
    
    if [[ "$REMOVE_EXISTING" =~ ^[Yy]$ ]] || [[ -z "$REMOVE_EXISTING" ]]; then
        echo -e "${CYAN}Removing existing Node${NODE_NUMBER}...${NC}"
        rm -rf "$INSTALL_PATH"
        echo -e "${GREEN}✅ Removed${NC}"
    else
        echo -e "${RED}❌ Installation cancelled${NC}"
        exit 0
    fi
fi

mkdir -p "$INSTALL_PATH"

# Copy from Github-Original-Node-Files to Node directory
echo -e "${CYAN}📋 Copying files from Github-Original-Node-Files...${NC}"

if [ ! -d "$ORIGINAL_PATH/blockdag-scripts" ]; then
    echo -e "${RED}❌ Github-Original-Node-Files not found!${NC}"
    exit 1
fi

cp -r "$ORIGINAL_PATH/blockdag-scripts" "$INSTALL_PATH/"

echo -e "${GREEN}✅ Files copied to ${INSTALL_PATH}${NC}"
echo ""

# Navigate to working directory
cd "$INSTALL_PATH/blockdag-scripts"

# Create .env file
echo -e "${CYAN}🔧 Creating .env configuration...${NC}"

cat > .env << EOF
PUB_ETH_ADDR=${WALLET_ADDRESS}
MINING_ADDRESS=${WALLET_ADDRESS}
EOF

echo -e "${GREEN}✅ .env file created${NC}"
echo ""

#============================================================
# CHUNK 7: Docker Compose Modifications
#============================================================

#############################################################
# DOCKER COMPOSE MODIFICATIONS - ALL NODES
#############################################################

echo -e "${CYAN}⚙️  Applying Docker Compose modifications...${NC}"
echo ""

# Find all docker-compose files (updated naming with underscores)
COMPOSE_FILES=(
    "docker-compose.yml"
    "docker-compose.full.yml"     # WITH DOT
    "docker-compose.relay.yml"    # WITH DOT
)

for COMPOSE_FILE in "${COMPOSE_FILES[@]}"; do
    if [ -f "$COMPOSE_FILE" ]; then
        echo -e "${BLUE}  Modifying ${COMPOSE_FILE}...${NC}"
        
        # Remove version line
        sed -i '1d' "$COMPOSE_FILE"
        
        # Update container names - MODE-SPECIFIC for visibility in docker ps
        sed -i "s/container_name: blockdag-miner-testnet/container_name: blockdag-node-${NODE_NUMBER}-miner/" "$COMPOSE_FILE"
        sed -i "s/container_name: blockdag-full-testnet/container_name: blockdag-node-${NODE_NUMBER}-full/" "$COMPOSE_FILE"
        sed -i "s/container_name: blockdag-relay-testnet/container_name: blockdag-node-${NODE_NUMBER}-relay/" "$COMPOSE_FILE"
        
        # Update volume names for multi-node support
        sed -i "s/- bdag_bin:/- bdag_bin${NODE_NUMBER}:/" "$COMPOSE_FILE"
        sed -i "s/^  bdag_bin: {}/  bdag_bin${NODE_NUMBER}: {}/" "$COMPOSE_FILE"
        
        # Port replacements
        sed -i "s/\"38131:38131\"/\"${RPC_PORT}:38131\"/" "$COMPOSE_FILE"
        sed -i "s/\"18545:18545\"/\"${JSONRPC_PORT}:18545\"/" "$COMPOSE_FILE"
        sed -i "s/\"18546:18546\"/\"${WSRPC_PORT}:18546\"/" "$COMPOSE_FILE"
        sed -i "s/\"18150:18150\"/\"${P2P_PORT}:18150\"/" "$COMPOSE_FILE"
        
        echo -e "${GREEN}    ✅ ${COMPOSE_FILE} updated${NC}"
    fi
done

echo ""

#============================================================
# CHUNK 8: Script Modifications with Dynamic Detection
#============================================================

#############################################################
# SCRIPT MODIFICATIONS - DYNAMIC DETECTION
#############################################################

echo -e "${CYAN}⚙️  Creating numbered management scripts...${NC}"
echo ""

# Get list of ALL scripts (dynamic detection)
SCRIPT_LIST=($(ls *.sh 2>/dev/null | grep -v "^docker" | grep -v "^install"))

echo -e "${BLUE}  Found ${#SCRIPT_LIST[@]} script(s) to process${NC}"
echo ""

for SCRIPT_FILE in "${SCRIPT_LIST[@]}"; do
    BASENAME="${SCRIPT_FILE%.sh}"
    
    echo -e "${BLUE}  Processing $SCRIPT_FILE...${NC}"
    
    # Special handling for known scripts
    if [ "$SCRIPT_FILE" = "blockdag.sh" ]; then
        # Create blockdagN.sh with node.sh reference update
        sed 's|"\$SCRIPT_DIR"/node\.sh|"\$SCRIPT_DIR"/node'${NODE_NUMBER}'.sh|' blockdag.sh > blockdag${NODE_NUMBER}.sh
        
        # Add auto-cleanup for mode switching
        sed -i '/"$SCRIPT_DIR"\/node/i\
# Auto-cleanup: Remove other mode containers to enable mode switching\
docker rm -f blockdag-node-'${NODE_NUMBER}'-miner 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUMBER}'-full 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUMBER}'-relay 2>/dev/null || true\
' blockdag${NODE_NUMBER}.sh
        
        chmod +x blockdag${NODE_NUMBER}.sh
        echo -e "${GREEN}    ✓ blockdag${NODE_NUMBER}.sh${NC}"
        
    elif [ "$SCRIPT_FILE" = "node.sh" ]; then
        # Create nodeN.sh with project names
        cp node.sh node${NODE_NUMBER}.sh
        
        # Add project name to docker compose commands
        sed -i "s/docker compose version/docker compose -p blockdag-node-${NODE_NUMBER} version/" node${NODE_NUMBER}.sh
        sed -i "s/compose_cmd=(docker compose)/compose_cmd=(docker compose -p blockdag-node-${NODE_NUMBER})/" node${NODE_NUMBER}.sh
        sed -i "s/compose_cmd=(docker-compose)/compose_cmd=(docker-compose -p blockdag-node-${NODE_NUMBER})/" node${NODE_NUMBER}.sh
        
        # Add project name to actual docker compose up commands
        sed -i "s/docker compose -f/docker compose -p blockdag-node-${NODE_NUMBER} -f/" node${NODE_NUMBER}.sh
        sed -i "s/docker-compose -f/docker-compose -p blockdag-node-${NODE_NUMBER} -f/" node${NODE_NUMBER}.sh
        
        chmod +x node${NODE_NUMBER}.sh
        echo -e "${GREEN}    ✓ node${NODE_NUMBER}.sh${NC}"
        
    elif [ "$SCRIPT_FILE" = "restart.sh" ] || [ "$SCRIPT_FILE" = "restartWithCleanup.sh" ]; then
        # Create restartN.sh or restartWithCleanupN.sh
        sed 's|"\$SCRIPT_DIR"/node\.sh|"\$SCRIPT_DIR"/node'${NODE_NUMBER}'.sh|g' "$SCRIPT_FILE" > "${BASENAME}${NODE_NUMBER}.sh"
        
        # Add project names to docker compose commands
        sed -i "s/docker compose version/docker compose -p blockdag-node-${NODE_NUMBER} version/" "${BASENAME}${NODE_NUMBER}.sh"
        sed -i "s/compose_cmd=(docker compose)/compose_cmd=(docker compose -p blockdag-node-${NODE_NUMBER})/" "${BASENAME}${NODE_NUMBER}.sh"
        sed -i "s/compose_cmd=(docker-compose)/compose_cmd=(docker-compose -p blockdag-node-${NODE_NUMBER})/" "${BASENAME}${NODE_NUMBER}.sh"
        
        # Add project name to docker compose down command
        sed -i 's/"\${compose_cmd\[@\]}" -f/"${compose_cmd[@]}" -p blockdag-node-'${NODE_NUMBER}' -f/' "${BASENAME}${NODE_NUMBER}.sh"
        
        # Add auto-cleanup before restart
        sed -i '/"$SCRIPT_DIR"\/node/i\
# Auto-cleanup: Remove other mode containers before restart\
docker rm -f blockdag-node-'${NODE_NUMBER}'-miner 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUMBER}'-full 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUMBER}'-relay 2>/dev/null || true\
' "${BASENAME}${NODE_NUMBER}.sh"
        
        chmod +x "${BASENAME}${NODE_NUMBER}.sh"
        echo -e "${GREEN}    ✓ ${BASENAME}${NODE_NUMBER}.sh${NC}"
        
    elif [ "$SCRIPT_FILE" = "stop.sh" ]; then
        # Create stopN.sh
        sed 's|"\$SCRIPT_DIR"/node\.sh|"\$SCRIPT_DIR"/node'${NODE_NUMBER}'.sh|g' stop.sh > stop${NODE_NUMBER}.sh
        
        # Add project names if script uses docker compose
        if grep -q "docker compose\|docker-compose" stop${NODE_NUMBER}.sh; then
            sed -i "s/docker compose version/docker compose -p blockdag-node-${NODE_NUMBER} version/" stop${NODE_NUMBER}.sh
            sed -i "s/compose_cmd=(docker compose)/compose_cmd=(docker compose -p blockdag-node-${NODE_NUMBER})/" stop${NODE_NUMBER}.sh
            sed -i "s/compose_cmd=(docker-compose)/compose_cmd=(docker-compose -p blockdag-node-${NODE_NUMBER})/" stop${NODE_NUMBER}.sh
            sed -i "s/docker compose -f/docker compose -p blockdag-node-${NODE_NUMBER} -f/" stop${NODE_NUMBER}.sh
            sed -i "s/docker-compose -f/docker-compose -p blockdag-node-${NODE_NUMBER} -f/" stop${NODE_NUMBER}.sh
        fi
        
        chmod +x stop${NODE_NUMBER}.sh
        echo -e "${GREEN}    ✓ stop${NODE_NUMBER}.sh${NC}"
        
    else
        # Unknown script - smart default handler
        echo -e "${YELLOW}    ⚠️  Unknown script: $SCRIPT_FILE (applying smart defaults)${NC}"
        
        # Copy and update node.sh reference
        sed 's|"\$SCRIPT_DIR"/node\.sh|"\$SCRIPT_DIR"/node'${NODE_NUMBER}'.sh|g' "$SCRIPT_FILE" > "${BASENAME}${NODE_NUMBER}.sh"
        
        # Check if script uses docker compose
        if grep -q "docker compose\|docker-compose" "${BASENAME}${NODE_NUMBER}.sh"; then
            echo -e "${YELLOW}      → Detected docker compose usage - adding isolation${NC}"
            
            sed -i "s/docker compose version/docker compose -p blockdag-node-${NODE_NUMBER} version/" "${BASENAME}${NODE_NUMBER}.sh"
            sed -i "s/compose_cmd=(docker compose)/compose_cmd=(docker compose -p blockdag-node-${NODE_NUMBER})/" "${BASENAME}${NODE_NUMBER}.sh"
            sed -i "s/compose_cmd=(docker-compose)/compose_cmd=(docker-compose -p blockdag-node-${NODE_NUMBER})/" "${BASENAME}${NODE_NUMBER}.sh"
            sed -i "s/docker compose -f/docker compose -p blockdag-node-${NODE_NUMBER} -f/" "${BASENAME}${NODE_NUMBER}.sh"
            sed -i "s/docker-compose -f/docker-compose -p blockdag-node-${NODE_NUMBER} -f/" "${BASENAME}${NODE_NUMBER}.sh"
        fi
        
        # Check if script starts containers
        if grep -q "docker compose.*up -d\|docker-compose.*up -d" "${BASENAME}${NODE_NUMBER}.sh"; then
            echo -e "${YELLOW}      → Detected container startup - adding auto-cleanup${NC}"
            
            sed -i '/docker compose.*up -d/i\
docker rm -f blockdag-node-'${NODE_NUMBER}'-miner 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUMBER}'-full 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUMBER}'-relay 2>/dev/null || true\
' "${BASENAME}${NODE_NUMBER}.sh"
        fi
        
        chmod +x "${BASENAME}${NODE_NUMBER}.sh"
        echo -e "${GREEN}    ✓ ${BASENAME}${NODE_NUMBER}.sh${NC}"
    fi
done

echo ""

# UPDATE 12: Universal Reference Updater
echo -e "${CYAN}🔗 Updating script cross-references...${NC}"

# Get list of all numbered scripts we just created
NUMBERED_SCRIPTS=($(ls *${NODE_NUMBER}.sh 2>/dev/null))

# Extract base names for reference updating
SCRIPT_BASENAMES=()
for NUMBERED_SCRIPT in "${NUMBERED_SCRIPTS[@]}"; do
    # Extract base name (blockdag1.sh → blockdag)
    SCRIPT_BASE="${NUMBERED_SCRIPT%${NODE_NUMBER}.sh}"
    SCRIPT_BASENAMES+=("$SCRIPT_BASE")
done

# Remove duplicates
SCRIPT_BASENAMES=($(echo "${SCRIPT_BASENAMES[@]}" | tr ' ' '\n' | sort -u))

# Update ALL cross-references in ALL numbered scripts
for BASENAME in "${SCRIPT_BASENAMES[@]}"; do
    # Update references: "$SCRIPT_DIR"/basename.sh → "$SCRIPT_DIR"/basenameN.sh
    for NUMBERED_SCRIPT in "${NUMBERED_SCRIPTS[@]}"; do
        sed -i 's|"\$SCRIPT_DIR"/'${BASENAME}'\.sh|"\$SCRIPT_DIR"/'${BASENAME}${NODE_NUMBER}'.sh|g' "$NUMBERED_SCRIPT"
    done
done

echo -e "${GREEN}✅ All cross-references updated${NC}"

# Delete original unnumbered scripts
echo -e "${YELLOW}  Removing original scripts...${NC}"
for SCRIPT_FILE in "${SCRIPT_LIST[@]}"; do
    rm -f "$SCRIPT_FILE"
done
echo -e "${GREEN}    ✅ Original scripts removed${NC}"

echo ""

#============================================================
# CHUNK 9: Commands File Generation (Dynamic)
#============================================================

#############################################################
# GENERATE COMMANDS FILE
#############################################################

echo -e "${CYAN}📋 Generating commands file...${NC}"
echo ""

COMMANDS_FILE="$INSTALL_PATH/node${NODE_NUMBER}-commands.txt"

# Get current timestamp
GENERATION_TIME=$(date "+%Y-%m-%d %H:%M:%S %Z")

# Detect which scripts exist
HAS_START=false
HAS_STOP=false
HAS_RESTART=false
HAS_CLEANUP=false

[ -f "blockdag${NODE_NUMBER}.sh" ] && HAS_START=true
[ -f "stop${NODE_NUMBER}.sh" ] && HAS_STOP=true
[ -f "restart${NODE_NUMBER}.sh" ] && HAS_RESTART=true
[ -f "restartWithCleanup${NODE_NUMBER}.sh" ] && HAS_CLEANUP=true

# Generate commands file header
cat > "$COMMANDS_FILE" << 'COMMANDS_EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
COMMANDS_EOF

echo "║              Node${NODE_NUMBER} Management Commands                        ║" >> "$COMMANDS_FILE"

cat >> "$COMMANDS_FILE" << 'COMMANDS_EOF'
║              For BlockDAG Investors Community                 ║
║              Created By: ArtX                                 ║
║                                                               ║
COMMANDS_EOF

echo "║              Generated: ${GENERATION_TIME}              ║" >> "$COMMANDS_FILE"

cat >> "$COMMANDS_FILE" << 'COMMANDS_EOF'
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

📂 Installation Path:
COMMANDS_EOF

echo "   cd ${INSTALL_PATH}/blockdag-scripts" >> "$COMMANDS_FILE"

cat >> "$COMMANDS_FILE" << 'COMMANDS_EOF'

─────────────────────────────────────────────────────────────────

COMMANDS_EOF

# START section (always present if blockdag script exists)
if [ "$HAS_START" = true ]; then
    cat >> "$COMMANDS_FILE" << COMMANDS_EOF
🚀 START NODE${NODE_NUMBER}:
   Choose one of the following modes:

   ./blockdag${NODE_NUMBER}.sh miner     # Start as Miner (mining rewards)
   ./blockdag${NODE_NUMBER}.sh full      # Start as Full (validation only)
   ./blockdag${NODE_NUMBER}.sh relay     # Start as Relay (gateway/routing)

─────────────────────────────────────────────────────────────────

COMMANDS_EOF
fi

# STOP section (conditional based on stop.sh existence)
if [ "$HAS_STOP" = true ]; then
    cat >> "$COMMANDS_FILE" << COMMANDS_EOF
🛑 STOP NODE${NODE_NUMBER}:
   ./stop${NODE_NUMBER}.sh all        # Stop all modes (recommended)
   ./stop${NODE_NUMBER}.sh miner      # Stop miner mode only
   ./stop${NODE_NUMBER}.sh full       # Stop full mode only
   ./stop${NODE_NUMBER}.sh relay      # Stop relay mode only

─────────────────────────────────────────────────────────────────

⚠️ EMERGENCY FORCE STOP (Not Recommended):
   docker rm -f \$(docker ps -aq --filter "name=blockdag-node-${NODE_NUMBER}-")
   
   ⚠️ WARNING: This forcefully removes containers.
   Only use if ./stop${NODE_NUMBER}.sh fails.

─────────────────────────────────────────────────────────────────

COMMANDS_EOF
else
    # No stop.sh - show emergency method only
    cat >> "$COMMANDS_FILE" << COMMANDS_EOF
🛑 STOP NODE${NODE_NUMBER}:
   docker rm -f \$(docker ps -aq --filter "name=blockdag-node-${NODE_NUMBER}-")

─────────────────────────────────────────────────────────────────

COMMANDS_EOF
fi

# LOGS section (always present)
cat >> "$COMMANDS_FILE" << COMMANDS_EOF
📊 VIEW LOGS:
   docker logs -f \$(docker ps -q --filter "name=blockdag-node-${NODE_NUMBER}-")

─────────────────────────────────────────────────────────────────

COMMANDS_EOF

# RESTART section (conditional)
if [ "$HAS_RESTART" = true ]; then
    cat >> "$COMMANDS_FILE" << COMMANDS_EOF
🔄 RESTART NODE${NODE_NUMBER} (Not for Swapping Mode):
   
   ./restart${NODE_NUMBER}.sh miner      # Restart as Miner
   ./restart${NODE_NUMBER}.sh full       # Restart as Full
   ./restart${NODE_NUMBER}.sh relay      # Restart as Relay

─────────────────────────────────────────────────────────────────

COMMANDS_EOF
fi

# RESTART WITH CLEANUP section (conditional)
if [ "$HAS_CLEANUP" = true ]; then
    cat >> "$COMMANDS_FILE" << COMMANDS_EOF
🧹 RESTART WITH CLEANUP (Sync From Genesis):

   ./restartWithCleanup${NODE_NUMBER}.sh miner
   ./restartWithCleanup${NODE_NUMBER}.sh full
   ./restartWithCleanup${NODE_NUMBER}.sh relay

─────────────────────────────────────────────────────────────────

COMMANDS_EOF
fi

# TIP box
cat >> "$COMMANDS_FILE" << COMMANDS_EOF
╔═══════════════════════════════════════════════════════════════╗
║  💡 TIP: Permission Errors                                    ║
╟───────────────────────────────────────────────────────────────╢
║  If any command fails with permission error, add 'sudo'       ║
║  before the command.                                          ║
║                                                               ║
COMMANDS_EOF

echo "║  Example: sudo ./blockdag${NODE_NUMBER}.sh miner                           ║" >> "$COMMANDS_FILE"

cat >> "$COMMANDS_FILE" << 'COMMANDS_EOF'
╚═══════════════════════════════════════════════════════════════╝

─────────────────────────────────────────────────────────────────

🗑️ COMPLETE NODE REMOVAL:

╔═══════════════════════════════════════════════════════════════╗
║  ⚠️  DANGER ZONE - Permanent Deletion                         ║
╚═══════════════════════════════════════════════════════════════╝

If you want to completely remove this node:

COMMANDS_EOF

cat >> "$COMMANDS_FILE" << COMMANDS_EOF
  sudo docker compose -p blockdag-node-${NODE_NUMBER} down -v && \\
  sudo docker volume rm bdag_bin${NODE_NUMBER} 2>/dev/null ; \\
  sudo docker network prune -f && \\
  sudo rm -rf ${INSTALL_PATH}

⚠️ WARNING: This permanently deletes:
  • All containers for Node${NODE_NUMBER} (miner/full/relay)
  • Volume: bdag_bin${NODE_NUMBER} (all blockchain data)
  • Folder: ${INSTALL_PATH}

Use only if you want to completely remove this node!

─────────────────────────────────────────────────────────────────

📊 CONFIGURATION:
   Wallet:       ${WALLET_ADDRESS}
   
   Ports:
   - RPC:        ${RPC_PORT}
   - JSON-RPC:   ${JSONRPC_PORT}
   - WS-RPC:     ${WSRPC_PORT}
   - P2P:        ${P2P_PORT}

─────────────────────────────────────────────────────────────────

📋 CONTAINER NAMES:
   Miner:  blockdag-node-${NODE_NUMBER}-miner
   Full:   blockdag-node-${NODE_NUMBER}-full
   Relay:  blockdag-node-${NODE_NUMBER}-relay

─────────────────────────────────────────────────────────────────
COMMANDS_EOF

echo -e "${GREEN}✅ Commands file created: node${NODE_NUMBER}-commands.txt${NC}"
echo ""

#============================================================
# CHUNK 10: Installation Complete & Final Instructions
#============================================================

#############################################################
# INSTALLATION COMPLETE
#############################################################

echo ""
echo -e "${GREEN}${BOLD}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║              ✅ Node${NODE_NUMBER} Installation Complete!                  ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Display summary
echo -e "${CYAN}${BOLD}📋 Installation Summary:${NC}"
echo ""
echo -e "  ${GREEN}✅${NC} Install Path:     ${WHITE}${INSTALL_PATH}${NC}"
echo -e "  ${GREEN}✅${NC} Wallet Address:   ${WHITE}${WALLET_ADDRESS:0:10}...${WALLET_ADDRESS: -8}${NC}"
echo ""
echo -e "  ${CYAN}Port Configuration:${NC}"
echo -e "    ${BLUE}•${NC} RPC Port:        ${WHITE}${RPC_PORT}${NC}"
echo -e "    ${BLUE}•${NC} JSON-RPC Port:   ${WHITE}${JSONRPC_PORT}${NC}"
echo -e "    ${BLUE}•${NC} WS-RPC Port:     ${WHITE}${WSRPC_PORT}${NC}"
echo -e "    ${BLUE}•${NC} P2P Port:        ${WHITE}${P2P_PORT}${NC}"
echo ""

# Next steps
echo -e "${YELLOW}${BOLD}🚀 Next Steps:${NC}"
echo ""
echo -e "${WHITE}1. Navigate to Node Directory:${NC}"
echo -e "   ${CYAN}cd ${INSTALL_PATH}/blockdag-scripts${NC}"
echo ""
echo -e "${WHITE}2. Choose a Mode and Start Your Node:${NC}"
echo -e "   ${CYAN}./blockdag${NODE_NUMBER}.sh miner${NC}      ${BLUE}# Mining mode (earns rewards)${NC}"
echo -e "   ${CYAN}./blockdag${NODE_NUMBER}.sh full${NC}       ${BLUE}# Full validation (no mining)${NC}"
echo -e "   ${CYAN}./blockdag${NODE_NUMBER}.sh relay${NC}      ${BLUE}# Relay gateway (lightweight)${NC}"
echo ""
echo -e "${WHITE}3. View All Commands:${NC}"
echo -e "   ${CYAN}cat ${INSTALL_PATH}/node${NODE_NUMBER}-commands.txt${NC}"
echo ""
echo -e "${WHITE}4. Check Node Status:${NC}"
echo -e "   ${CYAN}docker ps${NC}"
echo ""

# Final message
echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
echo -e "${GREEN}${BOLD}║     For BlockDAG Investors Community | Created By: ArtX       ║${NC}"
echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Return to original directory
cd "$HOME"

# Script complete
exit 0


