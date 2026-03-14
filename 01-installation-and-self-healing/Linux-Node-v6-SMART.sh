#!/bin/bash

# BlockDAG Node One-Line Installer - SMART Multi-Node Version (v6)
# Awakening Branch Edition
# Usage: bash Linux-Node-v6-SMART.sh

# Note: We don't use 'set -e' globally to prevent terminal from closing on errors
# Errors are handled explicitly throughout the script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Global variables for sudo management
SUDO_CACHED=false
SUDO_KEEPALIVE_PID=""

# Function to clear sudo cache on exit
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

# Set trap to clear sudo cache on exit
trap cleanup_sudo EXIT INT TERM

# Function to cache sudo credentials
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

# Function for better error messages
show_error() {
    local title="$1"
    local problem="$2"
    local solution="$3"
    
    echo -e "\n${RED}${BOLD}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║  ⚠️  ERROR: $title${NC}"
    echo -e "${RED}${BOLD}╚════════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}Problem:${NC} $problem"
    echo -e "${YELLOW}Solution:${NC} $solution"
    echo -e "${BLUE}Need help? Join our Discord: https://discord.com/invite/sAvyJ89PNm${NC}"
    echo -e "${RED}${BOLD}════════════════════════════════════════════════════${NC}\n"
}

# Function to extract port from compose file
extract_port() {
    local file=$1
    local pattern=$2
    
    if [ -f "$file" ]; then
        grep "$pattern" "$file" | sed 's/.*"\([0-9]*\):.*/\1/' | head -1
    else
        echo ""
    fi
}

# Clear screen and show welcome
clear
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║                                                    ║${NC}"
echo -e "${GREEN}${BOLD}║    🚀 BlockDAG Node Installer v6 SMART 🚀         ║${NC}"
echo -e "${GREEN}${BOLD}║         📦 Awakening Branch Edition 📦            ║${NC}"
echo -e "${GREEN}${BOLD}║                                                    ║${NC}"
echo -e "${GREEN}${BOLD}╠════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}${BOLD}║                                                    ║${NC}"
echo -e "${GREEN}${BOLD}║       💎 BlockDAG Investors Group 💎              ║${NC}"
echo -e "${GREEN}${BOLD}║              Made By: ArtX                         ║${NC}"
echo -e "${GREEN}${BOLD}║                                                    ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════╝${NC}\n"

# Step 1: Request sudo password and cache it
echo -e "${BLUE}${BOLD}Step 1: Sudo Authentication${NC}"
echo -e "${YELLOW}→ This script requires sudo access for some operations${NC}"
echo -e "${YELLOW}→ Please enter your sudo password (it will be cached for this session)${NC}"

# Request sudo access
if ! sudo -v; then
    show_error "Sudo Authentication Failed" \
        "Unable to obtain sudo access" \
        "Please ensure you have sudo privileges and try again"
    exit 1
fi

echo -e "${GREEN}✅ Sudo access granted${NC}\n"

# Step 2: Check Docker Installation
echo -e "${BLUE}${BOLD}Step 2: Checking Docker Installation${NC}"
echo -e "${YELLOW}→ Verifying Docker is installed...${NC}"

if ! command -v docker &> /dev/null; then
    show_error "Docker Not Found" \
        "Docker is not installed on this system" \
        "Please install Docker first:\n\n   Ubuntu/Debian: sudo apt install docker.io\n   Or visit: https://docs.docker.com/engine/install/"
    exit 1
fi

echo -e "${GREEN}✅ Docker detected: $(docker --version)${NC}"

# Check Docker Compose
if ! docker compose version &> /dev/null 2>&1; then
    if ! docker-compose --version &> /dev/null 2>&1; then
        show_error "Docker Compose Not Found" \
            "Docker Compose is not available" \
            "Please install Docker Compose:\n   https://docs.docker.com/compose/install/"
        exit 1
    fi
    DOCKER_COMPOSE_CMD="docker-compose"
    echo -e "${GREEN}✅ Docker Compose detected: $(docker-compose --version)${NC}\n"
else
    DOCKER_COMPOSE_CMD="docker compose"
    echo -e "${GREEN}✅ Docker Compose detected: $(docker compose version)${NC}\n"
fi

# Check if user is in docker group
CURRENT_USER=$(whoami)
if ! groups $CURRENT_USER | grep -q docker; then
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║     ⚠️  WARNING: Docker Group Membership         ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}You are not in the 'docker' group.${NC}"
    echo -e "${YELLOW}You may need to use 'sudo' with Docker commands.${NC}\n"
    echo -e "${BLUE}To fix this (optional):${NC}"
    echo -e "  ${GREEN}sudo usermod -aG docker $CURRENT_USER${NC}"
    echo -e "  ${YELLOW}Then logout and login again${NC}\n"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════╝${NC}\n"
    sleep 3
fi

# Step 3: Check Unzip Availability
echo -e "${BLUE}${BOLD}Step 3: Checking Required Tools${NC}"
echo -e "${YELLOW}→ Verifying unzip is installed...${NC}"

if ! command -v unzip &> /dev/null; then
    echo -e "${RED}❌ unzip is not installed${NC}"
    echo ""
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║        📦 Unzip Installation Required            ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Unzip is required to extract the GitHub Awakening files.${NC}"
    echo ""
    read -p "Would you like to install unzip now? (Y/n): " INSTALL_UNZIP
    echo ""
    
    if [[ $INSTALL_UNZIP =~ ^[Yy]$ ]] || [[ -z $INSTALL_UNZIP ]]; then
        echo -e "${CYAN}📥 Installing unzip...${NC}"
        
        # Cache sudo for installation
        cache_sudo || exit 1
        
        sudo apt-get update -qq
        sudo apt-get install -y unzip
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ unzip installed successfully!${NC}\n"
        else
            show_error "Installation Failed" \
                "Failed to install unzip" \
                "Please install manually:\n   sudo apt-get install unzip\n\nThen re-run this script."
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠️  Installation cancelled by user${NC}"
        echo ""
        echo -e "${BLUE}Please install unzip manually:${NC}"
        echo -e "   ${GREEN}sudo apt-get install unzip${NC}"
        echo ""
        echo -e "${BLUE}Then re-run this script.${NC}"
        exit 0
    fi
else
    echo -e "${GREEN}✅ unzip detected${NC}\n"
fi

# Step 4: Check if first node
echo -e "${BLUE}${BOLD}Step 4: Node Configuration Check${NC}"
read -p "Is this your first BlockDAG node on this PC? (Y/n): " FIRST_NODE
FIRST_NODE=${FIRST_NODE:-Y}

if [[ "$FIRST_NODE" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}✅ First node detected${NC}"
    NODE_NUMBER=1
    # Use default ports for first node
    RPC_PORT=38131
    HTTP_PORT=18545
    WS_PORT=18546
    PEER_PORT=18150
else
    echo -e "${YELLOW}✅ Additional node detected${NC}"
    read -p "How many BlockDAG nodes are you currently running? (Enter number): " NODE_COUNT
    
    if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]] || [ "$NODE_COUNT" -lt 1 ]; then
        show_error "Invalid Input" \
            "Node count must be a positive number" \
            "Please run the script again and enter a valid number"
        exit 1
    fi
    
    NODE_NUMBER=$((NODE_COUNT + 1))
    echo -e "${GREEN}✅ This will be Node $NODE_NUMBER${NC}\n"
    
    # Collect paths to existing nodes
    echo -e "${BLUE}${BOLD}→ Please provide paths to existing nodes:${NC}"
    echo -e "${YELLOW}  (Example: /home/user/Node1/blockdag-scripts or ~/Node1/blockdag-scripts)${NC}\n"
    
    declare -a NODE_PATHS
    declare -a ALL_RPC_PORTS
    declare -a ALL_HTTP_PORTS
    declare -a ALL_WS_PORTS
    declare -a ALL_PEER_PORTS
    
    for i in $(seq 1 $NODE_COUNT); do
        while true; do
            read -p "Node $i path: " NODE_PATH
            # Expand tilde
            NODE_PATH="${NODE_PATH/#\~/$HOME}"
            
            # Check if path exists
            if [ ! -d "$NODE_PATH" ]; then
                echo -e "${RED}✗ Path does not exist: $NODE_PATH${NC}"
                echo -e "${YELLOW}Please enter a valid path${NC}"
                continue
            fi
            
            # Check if docker-compose.yml exists
            if [ ! -f "$NODE_PATH/docker-compose.yml" ]; then
                echo -e "${RED}✗ docker-compose.yml not found in: $NODE_PATH${NC}"
                echo -e "${YELLOW}Please enter a valid blockdag-scripts directory${NC}"
                continue
            fi
            
            # Extract ports from the compose file
            RPC=$(extract_port "$NODE_PATH/docker-compose.yml" "38[0-9]*:38131")
            HTTP=$(extract_port "$NODE_PATH/docker-compose.yml" "18[0-9]*:18545")
            WS=$(extract_port "$NODE_PATH/docker-compose.yml" "18[0-9]*:18546")
            PEER=$(extract_port "$NODE_PATH/docker-compose.yml" "18[0-9]*:18150")
            
            if [ -z "$RPC" ] || [ -z "$HTTP" ] || [ -z "$WS" ] || [ -z "$PEER" ]; then
                echo -e "${RED}✗ Could not extract ports from: $NODE_PATH/docker-compose.yml${NC}"
                echo -e "${YELLOW}Please ensure the file has valid port mappings${NC}"
                continue
            fi
            
            echo -e "${GREEN}✅ Node $i detected - Ports: RPC=$RPC, HTTP=$HTTP, WS=$WS, PEER=$PEER${NC}"
            
            NODE_PATHS[$i]=$NODE_PATH
            ALL_RPC_PORTS+=($RPC)
            ALL_HTTP_PORTS+=($HTTP)
            ALL_WS_PORTS+=($WS)
            ALL_PEER_PORTS+=($PEER)
            break
        done
    done
    
    # Find highest ports and increment
    MAX_RPC=$(printf '%s\n' "${ALL_RPC_PORTS[@]}" | sort -n | tail -1)
    MAX_HTTP=$(printf '%s\n' "${ALL_HTTP_PORTS[@]}" | sort -n | tail -1)
    MAX_WS=$(printf '%s\n' "${ALL_WS_PORTS[@]}" | sort -n | tail -1)
    MAX_PEER=$(printf '%s\n' "${ALL_PEER_PORTS[@]}" | sort -n | tail -1)
    
    RPC_PORT=$((MAX_RPC + 1))
    HTTP_PORT=$((MAX_HTTP + 2))  # +2 because HTTP and WS are sequential
    WS_PORT=$((MAX_WS + 2))
    PEER_PORT=$((MAX_PEER + 1))
    
    echo -e "\n${GREEN}${BOLD}✅ New Node $NODE_NUMBER will use:${NC}"
    echo -e "${BLUE}  RPC Port:  ${GREEN}$RPC_PORT${NC}"
    echo -e "${BLUE}  HTTP Port: ${GREEN}$HTTP_PORT${NC}"
    echo -e "${BLUE}  WS Port:   ${GREEN}$WS_PORT${NC}"
    echo -e "${BLUE}  PEER Port: ${GREEN}$PEER_PORT${NC}\n"
fi

# Auto-create installation path
INSTALL_PATH="$HOME/Node${NODE_NUMBER}"
echo -e "${BLUE}Installation path: $INSTALL_PATH${NC}"

# Create directory and navigate to it
mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH"
echo -e "${GREEN}✅ Installation directory created${NC}\n"

# Step 5: Download BlockDAG Scripts from GitHub
echo -e "${BLUE}${BOLD}Step 5: Downloading BlockDAG Scripts${NC}"
echo -e "${YELLOW}→ Downloading from GitHub (awakening branch)...${NC}"

if ! wget https://github.com/BlockdagNetworkLabs/blockdag-scripts/archive/refs/heads/awakening.zip -O blockdag-scripts.zip 2>&1 | grep -v "^HTTP"; then
    show_error "Download Failed" \
        "Could not download blockdag-scripts from GitHub" \
        "Possible causes:\n   • No internet connection\n   • GitHub is down\n   • Firewall blocking access\n\nPlease check your connection and try again."
    exit 1
fi

echo -e "${GREEN}✅ Download complete!${NC}\n"

# Extract ZIP
echo -e "${YELLOW}→ Extracting files...${NC}"

if ! unzip -q blockdag-scripts.zip; then
    show_error "Extraction Failed" \
        "Could not extract blockdag-scripts.zip" \
        "The ZIP file may be corrupted. Please try again."
    rm -f blockdag-scripts.zip
    exit 1
fi

echo -e "${GREEN}✅ Files extracted successfully!${NC}\n"

# Remove existing folder if present (cleanup)
if [ -d "blockdag-scripts" ]; then
    echo -e "${YELLOW}→ Removing existing blockdag-scripts folder...${NC}"
    rm -rf blockdag-scripts
fi

# Rename extracted folder
echo -e "${YELLOW}→ Renaming folder...${NC}"
mv blockdag-scripts-awakening blockdag-scripts

# Clean up ZIP file
rm -f blockdag-scripts.zip

echo -e "${GREEN}✅ Setup complete!${NC}\n"

# Navigate into folder
cd blockdag-scripts

# Step 6: Configure ETH address
echo -e "${BLUE}${BOLD}Step 6: Configure EVM Wallet Address${NC}"
read -p "Enter your EVM wallet address (0x...): " ETH_ADDRESS

# Validate address format
if [[ ! $ETH_ADDRESS =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    show_error "Invalid Wallet Address" \
        "The address format is incorrect" \
        "Please ensure you enter a valid EVM address starting with 0x followed by 40 hexadecimal characters"
    exit 1
fi

# Create .env file
cat > .env << EOF
PUB_ETH_ADDR=$ETH_ADDRESS
MINING_ADDRESS=$ETH_ADDRESS
EOF

echo -e "${GREEN}✅ EVM address configured: $ETH_ADDRESS${NC}\n"

# Function to modify compose file with precise port replacement
modify_compose_file() {
    local file=$1
    
    if [ -f "$file" ]; then
        echo -e "${YELLOW}→ Modifying $file...${NC}"
        
        # Remove first line only (version: '3')
        sed -i '1d' "$file"
        
        if [ $NODE_NUMBER -ne 1 ]; then
            # Update container name based on file type
            if [[ "$file" == *"full"* ]]; then
                sed -i "s/container_name: blockdag-full-testnet/container_name: blockdag-full-testnet-${NODE_NUMBER}-${NODE_NUMBER}/" "$file"
            elif [[ "$file" == *"relay"* ]]; then
                sed -i "s/container_name: blockdag-relay-testnet/container_name: blockdag-relay-testnet-${NODE_NUMBER}-${NODE_NUMBER}/" "$file"
            else
                sed -i "s/container_name: blockdag-miner-testnet/container_name: blockdag-miner-testnet-${NODE_NUMBER}-${NODE_NUMBER}/" "$file"
            fi
            
            # Update volume names
            sed -i "s/- bdag_bin:/- bdag_bin${NODE_NUMBER}:/" "$file"
            sed -i "s/^  bdag_bin: {}/  bdag_bin${NODE_NUMBER}: {}/" "$file"
            
            # Update ports using sed with specific line matching
            sed -i "s/\"38131:38131\"/\"${RPC_PORT}:38131\"/g" "$file"
            sed -i "s/\"18545:18545\"/\"${HTTP_PORT}:18545\"/g" "$file"
            sed -i "s/\"18546:18546\"/\"${WS_PORT}:18546\"/g" "$file"
            sed -i "s/\"18150:18150\"/\"${PEER_PORT}:18150\"/g" "$file"
        fi
        
        echo -e "${GREEN}✅ $file configured${NC}"
    else
        show_error "Configuration File Missing" \
            "$file not found" \
            "Check your internet connection and try again"
        exit 1
    fi
}

# Step 7: Modify docker-compose files
echo -e "${BLUE}${BOLD}Step 7: Configuring Docker Compose Files${NC}"

# Modify all compose files
modify_compose_file "docker-compose.yml"
modify_compose_file "docker-compose.full.yml"
modify_compose_file "docker-compose.relay.yml"

echo ""

# Step 8: Create numbered scripts for multi-node setup
if [ $NODE_NUMBER -ne 1 ]; then
    echo -e "${BLUE}${BOLD}Step 8: Creating Node-Specific Scripts${NC}"
    echo -e "${YELLOW}→ Creating numbered scripts for Node $NODE_NUMBER...${NC}"
    
    # Create blockdag{N}.sh and update it
    if [ -f "blockdag.sh" ]; then
        cp blockdag.sh "blockdag${NODE_NUMBER}.sh"
        chmod +x "blockdag${NODE_NUMBER}.sh"
        
        # Update to call node{N}.sh
        sed -i "s|\"\$SCRIPT_DIR\"/node.sh|\"\$SCRIPT_DIR\"/node${NODE_NUMBER}.sh|g" "blockdag${NODE_NUMBER}.sh"
        
        echo -e "${GREEN}✅ blockdag${NODE_NUMBER}.sh created${NC}"
    fi
    
    # Create node{N}.sh and add project name
    if [ -f "node.sh" ]; then
        cp node.sh "node${NODE_NUMBER}.sh"
        chmod +x "node${NODE_NUMBER}.sh"
        
        # Add project name to docker compose commands
        sed -i "s|docker compose -f|docker compose -p blockdag-node-${NODE_NUMBER} -f|g" "node${NODE_NUMBER}.sh"
        sed -i "s|docker-compose -f|docker-compose -p blockdag-node-${NODE_NUMBER} -f|g" "node${NODE_NUMBER}.sh"
        
        echo -e "${GREEN}✅ node${NODE_NUMBER}.sh created with project name${NC}"
    fi
    
    # Create restart{N}.sh and update it
    if [ -f "restart.sh" ]; then
        cp restart.sh "restart${NODE_NUMBER}.sh"
        chmod +x "restart${NODE_NUMBER}.sh"
        
        # Update to call node{N}.sh
        sed -i "s|\"\$SCRIPT_DIR\"/node.sh|\"\$SCRIPT_DIR\"/node${NODE_NUMBER}.sh|g" "restart${NODE_NUMBER}.sh"
        
        # Add project name to ALL docker compose commands (including down)
        sed -i "s|\"\${compose_cmd\[@\]}\" -f|\"\${compose_cmd[@]}\" -p blockdag-node-${NODE_NUMBER} -f|g" "restart${NODE_NUMBER}.sh"
        
        echo -e "${GREEN}✅ restart${NODE_NUMBER}.sh created${NC}"
    fi
    
    # Create restartWithCleanup{N}.sh and update it
    if [ -f "restartWithCleanup.sh" ]; then
        cp restartWithCleanup.sh "restartWithCleanup${NODE_NUMBER}.sh"
        chmod +x "restartWithCleanup${NODE_NUMBER}.sh"
        
        # Update to call node{N}.sh
        sed -i "s|\"\$SCRIPT_DIR\"/node.sh|\"\$SCRIPT_DIR\"/node${NODE_NUMBER}.sh|g" "restartWithCleanup${NODE_NUMBER}.sh"
        
        # Add project name to ALL docker compose commands (including down)
        sed -i "s|\"\${compose_cmd\[@\]}\" -f|\"\${compose_cmd[@]}\" -p blockdag-node-${NODE_NUMBER} -f|g" "restartWithCleanup${NODE_NUMBER}.sh"
        
        echo -e "${GREEN}✅ restartWithCleanup${NODE_NUMBER}.sh created${NC}"
    fi
    
    # Delete original unnumbered scripts to avoid confusion
    echo -e "${YELLOW}→ Removing original scripts to prevent conflicts...${NC}"
    rm -f blockdag.sh node.sh restart.sh restartWithCleanup.sh
    echo -e "${GREEN}✅ Original scripts removed${NC}"
    
    echo ""
fi

# Set script names based on node number
if [ $NODE_NUMBER -eq 1 ]; then
    START_COMMAND="./blockdag.sh"
    RESTART_COMMAND="./restart.sh"
    RESTART_CLEANUP_COMMAND="./restartWithCleanup.sh"
else
    START_COMMAND="./blockdag${NODE_NUMBER}.sh"
    RESTART_COMMAND="./restart${NODE_NUMBER}.sh"
    RESTART_CLEANUP_COMMAND="./restartWithCleanup${NODE_NUMBER}.sh"
fi

# Step 9: Create command reference file
STEP_NUM=9
if [ $NODE_NUMBER -ne 1 ]; then
    STEP_NUM=9
fi

echo -e "${BLUE}${BOLD}Step $STEP_NUM: Creating Command Reference File${NC}"
COMMAND_FILE="$INSTALL_PATH/blockdag-scripts/node${NODE_NUMBER}-commands.txt"

# Set container names based on node number
if [ $NODE_NUMBER -eq 1 ]; then
    MINER_CONTAINER_NAME="blockdag-miner-testnet"
    FULL_CONTAINER_NAME="blockdag-full-testnet"
    RELAY_CONTAINER_NAME="blockdag-relay-testnet"
    STOP_COMMAND="docker stop \$(docker ps -q --filter \"name=blockdag-.*-testnet\")"
    LOGS_COMMAND="docker logs -f \$(docker ps -q --filter \"name=blockdag-.*-testnet\")"
else
    MINER_CONTAINER_NAME="blockdag-miner-testnet-${NODE_NUMBER}-${NODE_NUMBER}"
    FULL_CONTAINER_NAME="blockdag-full-testnet-${NODE_NUMBER}-${NODE_NUMBER}"
    RELAY_CONTAINER_NAME="blockdag-relay-testnet-${NODE_NUMBER}-${NODE_NUMBER}"
    STOP_COMMAND="docker stop \$(docker ps -q --filter \"name=blockdag-.*-testnet-${NODE_NUMBER}-${NODE_NUMBER}\")"
    LOGS_COMMAND="docker logs -f \$(docker ps -q --filter \"name=blockdag-.*-testnet-${NODE_NUMBER}-${NODE_NUMBER}\")"
fi

cat > "$COMMAND_FILE" << EOF
╔═══════════════════════════════════════════════════════════╗
║     BlockDAG Node $NODE_NUMBER - Quick Reference Commands           ║
╚═══════════════════════════════════════════════════════════╝

📂 INSTALLATION PATH:
─────────────────────────────────────────────────────────────
Navigate to Node Directory:
  cd $INSTALL_PATH/blockdag-scripts


🚀 START NODE:
─────────────────────────────────────────────────────────────
Choose one of the following modes:

  $START_COMMAND          # Miner mode (earns rewards)
  $START_COMMAND full     # Full validation (no mining)
  $START_COMMAND relay    # Gateway relay (no mining)

💡 If permission error: Add 'sudo' before the command


🛑 STOP NODE:
─────────────────────────────────────────────────────────────
Stop whichever container is running:

  $STOP_COMMAND

💡 If permission error: Add 'sudo' before the command


📊 VIEW LOGS:
─────────────────────────────────────────────────────────────
View logs for whichever container is running:

  $LOGS_COMMAND

💡 If permission error: Add 'sudo' before the command


🔄 RESTART NODE:
─────────────────────────────────────────────────────────────
⚠️  WARNING: restart accepts mode parameter (miner/full/relay)

Restart as Miner:
  $RESTART_COMMAND
  OR: $RESTART_COMMAND miner

Restart as Full Validator:
  $RESTART_COMMAND full

Restart as Relay:
  $RESTART_COMMAND relay


⚠️  RESTART WITH FULL CLEANUP (DELETES ALL DATA):
─────────────────────────────────────────────────────────────
  $RESTART_CLEANUP_COMMAND
  OR: $RESTART_CLEANUP_COMMAND [miner/full/relay]
  
  WARNING: This deletes all blockchain data!
  Node will re-sync from genesis (starts over from block 0)


🔍 CHECK WHICH MODE IS RUNNING:
─────────────────────────────────────────────────────────────
  docker ps
  
You'll see one of:
  • $MINER_CONTAINER_NAME  (Mining mode)
  • $FULL_CONTAINER_NAME   (Full validation mode)
  • $RELAY_CONTAINER_NAME  (Relay mode)


💡 DOCKER PERMISSIONS TIP:
─────────────────────────────────────────────────────────────
If you keep getting permission errors, add yourself to docker group:
  sudo usermod -aG docker \$USER
Then logout and login again for changes to take effect.

EOF

# Add node removal section
if [ $NODE_NUMBER -eq 1 ]; then
    cat >> "$COMMAND_FILE" << EOF

🗑️ COMPLETE NODE REMOVAL:
─────────────────────────────────────────────────────────────
If you want to completely remove this node:

All-in-one Cleanup Command:
  docker compose down -v ; \\
  docker volume rm bdag_bin 2>/dev/null ; \\
  docker network prune -f ; \\
  rm -rf $INSTALL_PATH

OR (if permission error):
  sudo docker compose down -v ; \\
  sudo docker volume rm bdag_bin 2>/dev/null ; \\
  sudo docker network prune -f ; \\
  sudo rm -rf $INSTALL_PATH

⚠️  WARNING: This permanently deletes:
  - All containers for Node $NODE_NUMBER
  - Volume: bdag_bin (all blockchain data)
  - Folder: $INSTALL_PATH

Use only if you want to completely remove this node!

EOF
else
    cat >> "$COMMAND_FILE" << EOF

🗑️ COMPLETE NODE REMOVAL:
─────────────────────────────────────────────────────────────
If you want to completely remove this node:

All-in-one Cleanup Command:
  docker compose -p blockdag-node-${NODE_NUMBER} down -v ; \\
  docker volume rm bdag_bin${NODE_NUMBER} 2>/dev/null ; \\
  docker network prune -f ; \\
  rm -rf $INSTALL_PATH

OR (if permission error):
  sudo docker compose -p blockdag-node-${NODE_NUMBER} down -v ; \\
  sudo docker volume rm bdag_bin${NODE_NUMBER} 2>/dev/null ; \\
  sudo docker network prune -f ; \\
  sudo rm -rf $INSTALL_PATH

⚠️  WARNING: This permanently deletes:
  - All containers for Node $NODE_NUMBER
  - Volume: bdag_bin${NODE_NUMBER} (all blockchain data)
  - Folder: $INSTALL_PATH

Use only if you want to completely remove this node!

EOF
fi

cat >> "$COMMAND_FILE" << EOF

═══════════════════════════════════════════════════════════
Generated: $(date)
Node Number: $NODE_NUMBER
Ports: RPC=$RPC_PORT | HTTP=$HTTP_PORT | WS=$WS_PORT | PEER=$PEER_PORT
═══════════════════════════════════════════════════════════
EOF

echo -e "${GREEN}📄 Command reference file created!${NC}"
echo -e "${BLUE}Location:${NC} ${GREEN}$COMMAND_FILE${NC}\n"

# Final summary - Display the reference file
echo -e "\n${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}✅ Installation Complete!${NC}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════${NC}\n"

echo -e "${BLUE}${BOLD}📋 Quick Reference Commands:${NC}\n"
cat "$COMMAND_FILE"

echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║      🚀 NEXT STEPS - START YOUR NODE            ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}${BOLD}⚠️  IMPORTANT: Node is NOT started automatically${NC}\n"

echo -e "${BLUE}To start your node:${NC}\n"
echo -e "${YELLOW}1. Open a NEW terminal${NC}"
echo -e "${YELLOW}2. Navigate to the node directory:${NC}"
echo -e "   ${GREEN}cd $INSTALL_PATH/blockdag-scripts${NC}\n"
echo -e "${YELLOW}3. Start your node with one of these commands:${NC}\n"

echo -e "   ${GREEN}$START_COMMAND${NC}          ${BLUE}# Miner mode${NC}"
echo -e "   ${GREEN}$START_COMMAND full${NC}     ${BLUE}# Full validation${NC}"
echo -e "   ${GREEN}$START_COMMAND relay${NC}    ${BLUE}# Gateway relay${NC}\n"

echo -e "${BLUE}💡 Tip:${NC} If you get permission errors, add 'sudo' before the command\n"

echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║       💎 Thank you for using BlockDAG! 💎       ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}\n"

# Pause before exit
echo -e "${YELLOW}Press Enter to exit this installer...${NC}"
read

# Clear sudo cache on exit
cleanup_sudo
