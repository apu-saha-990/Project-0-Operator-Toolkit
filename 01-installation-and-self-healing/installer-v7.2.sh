#!/bin/bash

#============================================================
# CHUNK 1: Script Header & Initial Setup
#============================================================

#############################################################
#                                                           #
#          BlockDAG Node Installer v7.0                    #
#          Wrapper Architecture with Original Files        #
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

# Sudo management - cache credentials early
echo -e "${CYAN}🔒 Requesting sudo access...${NC}"
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
echo "║            BlockDAG Node Installer v7.0                       ║"
echo "║            Wrapper Architecture Edition                       ║"
echo "║                                                               ║"
echo "║            For BlockDAG Investors Community                   ║"
echo "║            Created By: ArtX                                   ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

#============================================================
# CHUNK 2: Dependency Checks (Docker, Unzip)
#============================================================

#############################################################
# DEPENDENCY CHECKS
#############################################################

echo -e "${CYAN}🔍 Checking system dependencies...${NC}"
echo ""

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo -e "${YELLOW}Please install Docker first using Official-Docker-Installation.sh${NC}"
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

ORIGINAL_PATH="$HOME/Github-Original-Node-Files"
GITHUB_URL="https://github.com/BlockdagNetworkLabs/blockdag-scripts/archive/refs/heads/develop.zip"

echo -e "${CYAN}📦 Checking Github-Original-Node-Files...${NC}"
echo ""

if [ -d "$ORIGINAL_PATH/blockdag-scripts" ]; then
    echo -e "${GREEN}✅ Github-Original-Node-Files already exists${NC}"
    
    if [ -f "$ORIGINAL_PATH/blockdag-scripts/.download-date" ]; then
        DOWNLOAD_DATE=$(cat "$ORIGINAL_PATH/blockdag-scripts/.download-date")
        echo -e "${BLUE}📅 Downloaded: ${DOWNLOAD_DATE}${NC}"
    fi
    
    echo ""
    read -p "Re-download original files from GitHub? (y/N): " REDOWNLOAD
    
    if [[ "$REDOWNLOAD" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🗑️  Removing old Github-Original-Node-Files...${NC}"
        rm -rf "$ORIGINAL_PATH"
        mkdir -p "$ORIGINAL_PATH"
        NEED_DOWNLOAD=true
    else
        echo -e "${GREEN}✅ Using existing Github-Original-Node-Files${NC}"
        NEED_DOWNLOAD=false
    fi
else
    echo -e "${YELLOW}📥 Github-Original-Node-Files not found${NC}"
    mkdir -p "$ORIGINAL_PATH"
    NEED_DOWNLOAD=true
fi

# Download if needed
if [ "$NEED_DOWNLOAD" = true ]; then
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
        echo -e "${YELLOW}📝 Provide new GitHub download URL${NC}"
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
            echo -e "${CYAN}║              📝 Update Summary                            ║${NC}"
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
            echo -e "   ${WHITE}./installer-v7.sh${NC}"
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
fi

echo ""

#============================================================
# CHUNK 4: Node Detection & Port Configuration
#============================================================

#############################################################
# NODE DETECTION & PORT CONFIGURATION
#############################################################

echo -e "${CYAN}🔍 Detecting existing BlockDAG nodes...${NC}"
echo ""

# Find existing nodes
EXISTING_NODES=($(ls -d $HOME/Node* 2>/dev/null | sort -V))

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
echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║                  Installation Summary                         ║${NC}"
echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
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

# Delete unwanted GitHub files
echo -e "${CYAN}🧹 Removing unnecessary files...${NC}"
rm -f install_docker.sh
rm -f README.md
echo -e "${GREEN}✅ Cleanup complete${NC}"
echo ""

# Create .env file
echo -e "${CYAN}🔧 Creating .env configuration...${NC}"

cat > .env << EOF
PUB_ETH_ADDR=${WALLET_ADDRESS}
MINING_ADDRESS=${WALLET_ADDRESS}
EOF

echo -e "${GREEN}✅ .env file created${NC}"
echo ""

#============================================================
# CHUNK 7: Docker Compose Modifications (All Nodes)
#============================================================

#############################################################
# DOCKER COMPOSE MODIFICATIONS - ALL NODES
#############################################################

echo -e "${CYAN}⚙️  Applying Docker Compose modifications...${NC}"
echo ""

# Find all docker-compose files
COMPOSE_FILES=(
    "docker-compose.yml"
    "docker-compose.full.yml"
    "docker-compose.relay.yml"
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
# CHUNK 8: Script Modifications for All Nodes
#============================================================

#############################################################
# SCRIPT MODIFICATIONS - ALL NODES GET NUMBERED SCRIPTS
#############################################################

echo -e "${CYAN}⚙️  Creating numbered management scripts...${NC}"
echo ""

# Create blockdag{N}.sh and update it
if [ -f "blockdag.sh" ]; then
    echo -e "${BLUE}  Creating blockdag${NODE_NUMBER}.sh...${NC}"
    
    # Update reference to node.sh
sed 's|"\$SCRIPT_DIR"/node\.sh|"\$SCRIPT_DIR"/node'${NODE_NUMBER}'.sh|' blockdag.sh > blockdag${NODE_NUMBER}.sh

# Add auto-cleanup for mode switching (remove other mode containers before starting)
sed -i '/"$SCRIPT_DIR"\/node/i\
# Auto-cleanup: Remove other mode containers to enable mode switching\
docker rm -f blockdag-node-'${NODE_NUMBER}'-miner 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUMBER}'-full 2>/dev/null || true\
docker rm -f blockdag-node-'${NODE_NUMBER}'-relay 2>/dev/null || true\
' blockdag${NODE_NUMBER}.sh

chmod +x blockdag${NODE_NUMBER}.sh

echo -e "${GREEN}    ✅ blockdag${NODE_NUMBER}.sh created${NC}"
fi

# Create node{N}.sh and add project name
if [ -f "node.sh" ]; then
    echo -e "${BLUE}  Creating node${NODE_NUMBER}.sh...${NC}"
    
    cp node.sh node${NODE_NUMBER}.sh
    
    # Add project name to docker compose commands
    sed -i "s/docker compose version/docker compose -p blockdag-node-${NODE_NUMBER} version/" node${NODE_NUMBER}.sh
    sed -i "s/compose_cmd=(docker compose)/compose_cmd=(docker compose -p blockdag-node-${NODE_NUMBER})/" node${NODE_NUMBER}.sh
    sed -i "s/compose_cmd=(docker-compose)/compose_cmd=(docker-compose -p blockdag-node-${NODE_NUMBER})/" node${NODE_NUMBER}.sh
    
    # Add project name to actual docker compose up commands
    sed -i "s/docker compose -f/docker compose -p blockdag-node-${NODE_NUMBER} -f/" node${NODE_NUMBER}.sh
    sed -i "s/docker-compose -f/docker-compose -p blockdag-node-${NODE_NUMBER} -f/" node${NODE_NUMBER}.sh
    
    chmod +x node${NODE_NUMBER}.sh
    
    echo -e "${GREEN}    ✅ node${NODE_NUMBER}.sh created${NC}"
fi

# Create restart{N}.sh and update it
if [ -f "restart.sh" ]; then
    echo -e "${BLUE}  Creating restart${NODE_NUMBER}.sh...${NC}"
    
    # Copy and update reference to node.sh
    sed 's|"\$SCRIPT_DIR"/node\.sh|"\$SCRIPT_DIR"/node'${NODE_NUMBER}'.sh|g' restart.sh > restart${NODE_NUMBER}.sh
    
    # Add project name to docker compose commands
sed -i "s/docker compose version/docker compose -p blockdag-node-${NODE_NUMBER} version/" restart${NODE_NUMBER}.sh
sed -i "s/compose_cmd=(docker compose)/compose_cmd=(docker compose -p blockdag-node-${NODE_NUMBER})/" restart${NODE_NUMBER}.sh
sed -i "s/compose_cmd=(docker-compose)/compose_cmd=(docker-compose -p blockdag-node-${NODE_NUMBER})/" restart${NODE_NUMBER}.sh

# Add project name to docker compose down command
sed -i 's/"\${compose_cmd\[@\]}" -f/"${compose_cmd[@]}" -p blockdag-node-'${NODE_NUMBER}' -f/' restart${NODE_NUMBER}.sh

chmod +x restart${NODE_NUMBER}.sh
    
    echo -e "${GREEN}    ✅ restart${NODE_NUMBER}.sh created${NC}"
fi

# Create restartWithCleanup{N}.sh and update it
if [ -f "restartWithCleanup.sh" ]; then
    echo -e "${BLUE}  Creating restartWithCleanup${NODE_NUMBER}.sh...${NC}"
    
    # Copy and update reference to node.sh
    sed 's|"\$SCRIPT_DIR"/node\.sh|"\$SCRIPT_DIR"/node'${NODE_NUMBER}'.sh|g' restartWithCleanup.sh > restartWithCleanup${NODE_NUMBER}.sh
    
    # Add project name to docker compose commands
sed -i "s/docker compose version/docker compose -p blockdag-node-${NODE_NUMBER} version/" restartWithCleanup${NODE_NUMBER}.sh
sed -i "s/compose_cmd=(docker compose)/compose_cmd=(docker compose -p blockdag-node-${NODE_NUMBER})/" restartWithCleanup${NODE_NUMBER}.sh
sed -i "s/compose_cmd=(docker-compose)/compose_cmd=(docker-compose -p blockdag-node-${NODE_NUMBER})/" restartWithCleanup${NODE_NUMBER}.sh

# Add project name to docker compose down command
sed -i 's/"\${compose_cmd\[@\]}" -f/"${compose_cmd[@]}" -p blockdag-node-'${NODE_NUMBER}' -f/' restartWithCleanup${NODE_NUMBER}.sh

chmod +x restartWithCleanup${NODE_NUMBER}.sh
    
    echo -e "${GREEN}    ✅ restartWithCleanup${NODE_NUMBER}.sh created${NC}"
fi

# Delete original unnumbered scripts
echo -e "${YELLOW}  Removing original scripts...${NC}"
rm -f blockdag.sh node.sh restart.sh restartWithCleanup.sh
echo -e "${GREEN}    ✅ Original scripts removed${NC}"

echo ""

#============================================================
# CHUNK 9: Commands File Generation
#============================================================

#############################################################
# GENERATE COMMANDS FILE
#############################################################

echo -e "${CYAN}📋 Generating commands file...${NC}"
echo ""

COMMANDS_FILE="$INSTALL_PATH/node${NODE_NUMBER}-commands.txt"

# Get current timestamp
GENERATION_TIME=$(date "+%Y-%m-%d %H:%M:%S %Z")

cat > "$COMMANDS_FILE" << EOF
╔═══════════════════════════════════════════════════════════════╗
                                                               
              Node${NODE_NUMBER} Management Commands           
              For BlockDAG Investors Community                 
              Created By: ArtX                                 
                                                               
              Generated: ${GENERATION_TIME}              
                                                               
╚═══════════════════════════════════════════════════════════════╝

📂 Installation Path:
   cd ${INSTALL_PATH}/blockdag-scripts

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 START NODE${NODE_NUMBER}:
   Choose one of the following modes:

   ./blockdag${NODE_NUMBER}.sh miner     # Start as Miner (mining rewards)
   ./blockdag${NODE_NUMBER}.sh full      # Start as Full (validation only)
   ./blockdag${NODE_NUMBER}.sh relay     # Start as Relay (gateway/routing)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⛔ STOP NODE${NODE_NUMBER}:
   docker rm -f \$(docker ps -aq --filter "name=blockdag-node-${NODE_NUMBER}-")

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 VIEW LOGS:
   docker logs -f \$(docker ps -q --filter "name=blockdag-node-${NODE_NUMBER}-")

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔄 RESTART NODE${NODE_NUMBER} (Not for Swapping Mode):
   
   ./restart${NODE_NUMBER}.sh miner      # Restart as Miner
   ./restart${NODE_NUMBER}.sh full       # Restart as Full
   ./restart${NODE_NUMBER}.sh relay      # Restart as Relay

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🧹 RESTART WITH CLEANUP (Sync From Genesis):

   ./restartWithCleanup${NODE_NUMBER}.sh miner
   ./restartWithCleanup${NODE_NUMBER}.sh full
   ./restartWithCleanup${NODE_NUMBER}.sh relay

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

╔═══════════════════════════════════════════════════════════════╗
║  💡 TIP: Permission Errors                                    ║
╠═══════════════════════════════════════════════════════════════╣
  If any command fails with permission error, add 'sudo'       
  before the command.                                          
                                                               
  Example: sudo ./blockdag${NODE_NUMBER}.sh miner              
╚═══════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🗑️  COMPLETE NODE REMOVAL:

╔═══════════════════════════════════════════════════════════════╗
║  ⚠️  DANGER ZONE - Permanent Deletion                         ║
╚═══════════════════════════════════════════════════════════════╝

If you want to completely remove this node:

  sudo docker compose -p blockdag-node-${NODE_NUMBER} down -v && \\
  sudo docker volume rm bdag_bin${NODE_NUMBER} 2>/dev/null ; \\
  sudo docker network prune -f && \\
  sudo rm -rf ${INSTALL_PATH}

⚠️  WARNING: This permanently deletes:
  • All containers for Node${NODE_NUMBER} (miner/full/relay)
  • Volume: bdag_bin${NODE_NUMBER} (all blockchain data)
  • Folder: ${INSTALL_PATH}

Use only if you want to completely remove this node!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 CONFIGURATION:
   Wallet:       ${WALLET_ADDRESS}
   
   Ports:
   - RPC:        ${RPC_PORT}
   - JSON-RPC:   ${JSONRPC_PORT}
   - WS-RPC:     ${WSRPC_PORT}
   - P2P:        ${P2P_PORT}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 CONTAINER NAMES:
   Miner:  blockdag-node-${NODE_NUMBER}-miner
   Full:   blockdag-node-${NODE_NUMBER}-full
   Relay:  blockdag-node-${NODE_NUMBER}-relay

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

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
echo "║              ✅ Node${NODE_NUMBER} Installation Complete!     ║"
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
