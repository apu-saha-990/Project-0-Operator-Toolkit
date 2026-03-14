#!/bin/bash

#============================================================
# Node Restart Manager v1.0
# For BlockDAG Investors Community
# Created By: ArtX
#
# Multi-node restart orchestration with Discord notifications
# Supports both Interactive and Cron modes
#============================================================

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

# Script directory
SCRIPT_DIR="$HOME/Node-Restart-Manager"
CONFIG_FILE="$SCRIPT_DIR/config.json"
STATE_FILE="$SCRIPT_DIR/.restart-state.json"
LOG_FILE="$SCRIPT_DIR/restart-manager.log"
CRON_LOG="$SCRIPT_DIR/cron.log"
README_FILE="$SCRIPT_DIR/README.txt"

# Mode detection
IS_CRON=false
IS_INTERACTIVE=true

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --cron)
            IS_CRON=true
            IS_INTERACTIVE=false
            ;;
        --setup)
            SETUP_MODE=true
            ;;
        --rebuild-config)
            REBUILD_CONFIG=true
            ;;
        --test-discord)
            TEST_DISCORD=true
            ;;
        --status)
            SHOW_STATUS=true
            ;;
        --setup-cron)
            SETUP_CRON_DIRECT=true
            ;;
        --show-cron)
            SHOW_CRON_DIRECT=true
            ;;
        --remove-cron)
            REMOVE_CRON_DIRECT=true
            ;;
        --run)
            RUN_NOW=true
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
    esac
done

#============================================================
# LOGGING FUNCTIONS
#============================================================

log() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
    if [ "$IS_INTERACTIVE" = true ]; then
        echo -e "$message"
    fi
}

log_cron() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$CRON_LOG"
}

#============================================================
# DISCORD FUNCTIONS
#============================================================

send_discord() {
    local message="$1"
    local webhook_url=$(jq -r '.discord.webhook_url' "$CONFIG_FILE" 2>/dev/null)
    local enabled=$(jq -r '.discord.enabled' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$enabled" != "true" ] || [ -z "$webhook_url" ] || [ "$webhook_url" = "null" ]; then
        log "Discord disabled or webhook not configured"
        return
    fi
    
    # Escape message for JSON using jq
    local json_message=$(echo -n "$message" | jq -Rs .)
    
    # Create JSON payload
    local payload=$(jq -n --arg content "$message" '{content: $content}')
    
    # Send to Discord with error handling
    local response=$(curl -H "Content-Type: application/json" \
         -X POST \
         -d "$payload" \
         "$webhook_url" \
         -s -w "\n%{http_code}" \
         -o /tmp/discord_response.txt 2>&1)
    
    local http_code=$(echo "$response" | tail -1)
    
    if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
        log "Discord notification sent successfully (HTTP $http_code)"
    else
        log "Discord notification failed (HTTP $http_code)"
        if [ -f /tmp/discord_response.txt ]; then
            log "Response: $(cat /tmp/discord_response.txt)"
        fi
    fi
    
    rm -f /tmp/discord_response.txt
}

send_discord_code_block() {
    local message="$1"
    local webhook_url=$(jq -r '.discord.webhook_url' "$CONFIG_FILE" 2>/dev/null)
    local enabled=$(jq -r '.discord.enabled' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$enabled" != "true" ] || [ -z "$webhook_url" ] || [ "$webhook_url" = "null" ]; then
        return
    fi
    
    # Create JSON payload using jq for proper escaping
    local payload=$(jq -n --arg content "$message" '{content: $content}')
    
    # Send to Discord with error handling
    local response=$(curl -H "Content-Type: application/json" \
         -X POST \
         -d "$payload" \
         "$webhook_url" \
         -s -w "\n%{http_code}" \
         -o /tmp/discord_response.txt 2>&1)
    
    local http_code=$(echo "$response" | tail -1)
    
    if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
        log "Discord code block sent successfully (HTTP $http_code)"
    else
        log "Discord code block failed (HTTP $http_code)"
    fi
    
    rm -f /tmp/discord_response.txt
}

#============================================================
# UTILITY FUNCTIONS
#============================================================

show_help() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║         Node Restart Manager v1.0                         ║
║         For BlockDAG Investors Community                  ║
║         Created By: ArtX                                  ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

Usage: ./Node-Restart-Manager.sh [OPTIONS]

OPTIONS:
  (no args)         Show main menu (default)
  --run             Run restart now (interactive mode)
  --cron            Run in cron mode (silent, logs to file)
  --setup           First-time setup wizard
  --rebuild-config  Rebuild configuration from nodes
  --test-discord    Test Discord webhook
  --status          Show last run status
  --setup-cron      Setup cron schedule
  --show-cron       Show current cron schedule
  --remove-cron     Remove cron schedule
  --help, -h        Show this help message

EXAMPLES:
  ./Node-Restart-Manager.sh
  ./Node-Restart-Manager.sh --run
  ./Node-Restart-Manager.sh --cron

FILES:
  ~/Node-Restart-Manager/config.json          - Configuration
  ~/Node-Restart-Manager/restart-manager.log  - General log
  ~/Node-Restart-Manager/cron.log             - Cron execution log

EOF
}

countdown_timer() {
    local duration=$1
    local message="$2"
    local allow_skip=${3:-true}
    
    if [ "$IS_CRON" = true ]; then
        log_cron "Waiting $duration seconds: $message"
        sleep "$duration"
        return
    fi
    
    local remaining=$duration
    
    while [ $remaining -gt 0 ]; do
        local minutes=$((remaining / 60))
        local seconds=$((remaining % 60))
        
        if [ "$allow_skip" = true ]; then
            echo -ne "\r${CYAN}$message ${WHITE}${minutes}m ${seconds}s${NC} ${YELLOW}[Press Enter to skip]${NC}   "
        else
            echo -ne "\r${CYAN}$message ${WHITE}${minutes}m ${seconds}s${NC}   "
        fi
        
        if [ "$allow_skip" = true ]; then
            read -t 1 -n 1 key
            if [ $? -eq 0 ]; then
                echo -e "\n${GREEN}⚡ Skipped by user${NC}"
                return
            fi
        else
            sleep 1
        fi
        
        remaining=$((remaining - 1))
    done
    
    echo -e "\r${GREEN}✅ Wait complete${NC}                                              "
}

#============================================================
# DIRECTORY SETUP
#============================================================

setup_directory() {
    # Create directory if it doesn't exist
    if [ ! -d "$SCRIPT_DIR" ]; then
        echo -e "${CYAN}📁 Creating Node-Restart-Manager directory...${NC}"
        mkdir -p "$SCRIPT_DIR"
        echo -e "${GREEN}✅ Created: $SCRIPT_DIR${NC}"
        echo ""
    fi
    
    # Check if script is in the proper location
    CURRENT_SCRIPT="$(readlink -f "$0")"
    TARGET_SCRIPT="$SCRIPT_DIR/Node-Restart-Manager.sh"
    
    # If script is NOT in the target location and target doesn't exist, offer to copy
    if [ "$CURRENT_SCRIPT" != "$TARGET_SCRIPT" ] && [ ! -f "$TARGET_SCRIPT" ]; then
        echo -e "${YELLOW}⚠️  Script is not in the Node-Restart-Manager directory${NC}"
        echo -e "${CYAN}Current location: ${WHITE}$CURRENT_SCRIPT${NC}"
        echo -e "${CYAN}Target location:  ${WHITE}$TARGET_SCRIPT${NC}"
        echo ""
        echo "Would you like to:"
        echo "  1) Copy script to Node-Restart-Manager directory (recommended)"
        echo "  2) Continue running from current location"
        echo ""
        read -p "Enter choice [1-2]: " location_choice
        
        if [ "$location_choice" = "1" ]; then
            cp "$CURRENT_SCRIPT" "$TARGET_SCRIPT"
            chmod +x "$TARGET_SCRIPT"
            echo ""
            echo -e "${GREEN}✅ Script copied to: $TARGET_SCRIPT${NC}"
            echo ""
            echo -e "${CYAN}You can now run the script from either location:${NC}"
            echo -e "  ${WHITE}$TARGET_SCRIPT${NC}"
            echo -e "  ${WHITE}$CURRENT_SCRIPT${NC}"
            echo ""
            read -p "Press Enter to continue..."
        else
            echo -e "${GREEN}✅ Continuing from current location${NC}"
            echo ""
        fi
    fi
    
    # Create README if it doesn't exist
    if [ ! -f "$README_FILE" ]; then
        cat > "$README_FILE" << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║         Node Restart Manager v1.0                         ║
║         For BlockDAG Investors Community                  ║
║         Created By: ArtX                                  ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

QUICK START:
1. Run: ./Node-Restart-Manager.sh
2. Follow setup wizard for first-time configuration
3. Configure Discord webhook (optional)
4. Setup cron schedule for automatic restarts

FEATURES:
- Multi-node sequential restart
- Discord notifications for each step
- Interactive mode with countdown timers
- Cron mode for automatic scheduled restarts
- Skips nodes that were stopped before run
- Collects last 10 logs from running containers

CONFIGURATION:
Edit config.json to customize:
- Wait times (stop, verify, logs)
- Discord webhook URL
- Per-node settings

LOGS:
- restart-manager.log  - General operations
- cron.log             - Cron execution history

SUPPORT:
BlockDAG Investors Community Discord
Created By: ArtX
EOF
    fi
}

#============================================================
# CONFIG PARSING & DETECTION
#============================================================

parse_commands_file() {
    local node_path="$1"
    local node_num="$2"
    local commands_file="$node_path/node${node_num}-commands.txt"
    
    if [ ! -f "$commands_file" ]; then
        echo "null"
        return
    fi
    
    # Extract install path
    local install_path=$(grep -A 1 "Installation Path:" "$commands_file" | tail -1 | sed 's/^[[:space:]]*cd //' | xargs)
    
    # Extract wallet
    local wallet=$(grep "Wallet:" "$commands_file" | sed 's/.*Wallet:[[:space:]]*//' | xargs)
    
    # Extract start commands (look for the actual command lines)
    local start_miner=$(grep "blockdag${node_num}.sh miner" "$commands_file" | head -1 | sed 's/^[[:space:]]*//' | sed 's/#.*//' | xargs)
    local start_full=$(grep "blockdag${node_num}.sh full" "$commands_file" | head -1 | sed 's/^[[:space:]]*//' | sed 's/#.*//' | xargs)
    local start_relay=$(grep "blockdag${node_num}.sh relay" "$commands_file" | head -1 | sed 's/^[[:space:]]*//' | sed 's/#.*//' | xargs)
    
    # Extract stop command (escape for JSON)
    local stop_cmd=$(grep -A 1 "STOP NODE${node_num}:" "$commands_file" | tail -1 | sed 's/^[[:space:]]*//' | xargs)
    
    # Extract container names
    local container_miner=$(grep "Miner:" "$commands_file" | tail -1 | sed 's/.*Miner:[[:space:]]*//' | xargs)
    local container_full=$(grep "Full:" "$commands_file" | tail -1 | sed 's/.*Full:[[:space:]]*//' | xargs)
    local container_relay=$(grep "Relay:" "$commands_file" | tail -1 | sed 's/.*Relay:[[:space:]]*//' | xargs)
    
    # Escape strings for JSON using jq
    install_path=$(echo -n "$install_path" | jq -Rs .)
    wallet=$(echo -n "$wallet" | jq -Rs .)
    start_miner=$(echo -n "$start_miner" | jq -Rs .)
    start_full=$(echo -n "$start_full" | jq -Rs .)
    start_relay=$(echo -n "$start_relay" | jq -Rs .)
    stop_cmd=$(echo -n "$stop_cmd" | jq -Rs .)
    container_miner=$(echo -n "$container_miner" | jq -Rs .)
    container_full=$(echo -n "$container_full" | jq -Rs .)
    container_relay=$(echo -n "$container_relay" | jq -Rs .)
    
    # Build JSON object with properly escaped strings
    cat << EOF
{
  "node_number": $node_num,
  "install_path": $install_path,
  "wallet_address": $wallet,
  "commands": {
    "start": {
      "miner": $start_miner,
      "full": $start_full,
      "relay": $start_relay
    },
    "stop": $stop_cmd
  },
  "container_names": {
    "miner": $container_miner,
    "full": $container_full,
    "relay": $container_relay
  }
}
EOF
}

detect_nodes() {
    local nodes=()
    
    for node_dir in $HOME/Node*; do
        if [ -d "$node_dir" ]; then
            local node_name=$(basename "$node_dir")
            if [[ $node_name =~ Node([0-9]+) ]]; then
                local node_num=${BASH_REMATCH[1]}
                
                # Check for commands file
                if [ -f "$node_dir/node${node_num}-commands.txt" ]; then
                    nodes+=("$node_num")
                fi
            fi
        fi
    done
    
    echo "${nodes[@]}"
}

#============================================================
# CONFIGURATION SETUP
#============================================================

setup_config() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║         Node Restart Manager Setup                        ║"
    echo "║         For BlockDAG Investors Community                  ║"
    echo "║         Created By: ArtX                                  ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Ask if using ArtX installer
    read -p "Did you install nodes using ArtX Node Installer (v7+)? (Y/n): " artx_installer
    
    if [[ "$artx_installer" =~ ^[Yy]$ ]] || [[ -z "$artx_installer" ]]; then
        # Auto-detect nodes
        echo -e "${CYAN}🔍 Scanning for BlockDAG nodes...${NC}"
        echo ""
        
        local detected_nodes=($(detect_nodes))
        
        if [ ${#detected_nodes[@]} -eq 0 ]; then
            echo -e "${RED}❌ No nodes found with ArtX installer structure${NC}"
            echo -e "${YELLOW}Please ensure nodes are installed in ~/Node1, ~/Node2, etc.${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✅ Found ${#detected_nodes[@]} node(s):${NC}"
        echo ""
        
        local nodes_json="["
        local first=true
        
        for node_num in "${detected_nodes[@]}"; do
            local node_path="$HOME/Node${node_num}"
            local node_data=$(parse_commands_file "$node_path" "$node_num")
            
            if [ "$node_data" != "null" ]; then
                # Display node info
                local install_path=$(echo "$node_data" | jq -r '.install_path')
                local wallet=$(echo "$node_data" | jq -r '.wallet_address')
                local container_miner=$(echo "$node_data" | jq -r '.container_names.miner')
                
                echo -e "${CYAN}Node${node_num}:${NC} $install_path"
                echo -e "  Wallet: ${wallet:0:10}...${wallet: -8}"
                echo -e "  Container: $container_miner"
                echo ""
                
                # Add to JSON array
                if [ "$first" = true ]; then
                    first=false
                else
                    nodes_json+=","
                fi
                nodes_json+="$node_data"
            fi
        done
        
        nodes_json+="]"
        
        echo ""
        read -p "Is this information correct? (Y/n): " confirm
        
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Setup cancelled${NC}"
            exit 0
        fi
        
        # Discord webhook setup
        echo ""
        echo -e "${CYAN}📢 Discord Webhook Configuration${NC}"
        echo ""
        read -p "Enable Discord notifications? (Y/n): " enable_discord
        
        local webhook_url=""
        local discord_enabled="false"
        
        if [[ "$enable_discord" =~ ^[Yy]$ ]] || [[ -z "$enable_discord" ]]; then
            discord_enabled="true"
            echo ""
            echo -e "${YELLOW}To get your Discord webhook URL:${NC}"
            echo -e "  1. Open Discord Server Settings"
            echo -e "  2. Go to Integrations > Webhooks"
            echo -e "  3. Create New Webhook"
            echo -e "  4. Copy Webhook URL"
            echo ""
            read -p "Enter Discord Webhook URL: " webhook_url
        fi
        
        # Create config file
        cat > "$CONFIG_FILE" << EOF
{
  "version": "1.0",
  "created": "$(date '+%Y-%m-%d %H:%M:%S')",
  
  "discord": {
    "webhook_url": "$webhook_url",
    "enabled": $discord_enabled
  },
  
  "timing": {
    "stop_to_start_wait_minutes": 5,
    "start_verification_wait_minutes": 3,
    "final_logs_wait_minutes": 15,
    "minimum_skip_wait_seconds": 30
  },
  
  "nodes": $nodes_json
}
EOF
        
        echo ""
        echo -e "${GREEN}✅ Configuration created successfully!${NC}"
        echo -e "${BLUE}Config saved to: $CONFIG_FILE${NC}"
        echo ""
        
    else
        # Manual setup
        manual_setup
    fi
}

manual_setup() {
    echo ""
    echo -e "${CYAN}Manual Node Configuration${NC}"
    echo ""
    
    read -p "How many nodes do you have? " node_count
    
    local nodes_json="["
    
    for ((i=1; i<=node_count; i++)); do
        echo ""
        echo -e "${YELLOW}═══ Node${i} Configuration ═══${NC}"
        
        read -p "Install path (e.g., /home/user/Node${i}/blockdag-scripts): " install_path
        read -p "Wallet address: " wallet
        read -p "Start command (miner): " start_miner
        read -p "Start command (full): " start_full
        read -p "Start command (relay): " start_relay
        read -p "Stop command: " stop_cmd
        read -p "Container name (miner): " container_miner
        read -p "Container name (full): " container_full
        read -p "Container name (relay): " container_relay
        
        if [ $i -gt 1 ]; then
            nodes_json+=","
        fi
        
        nodes_json+=$(cat << EOF
{
  "node_number": $i,
  "install_path": "$install_path",
  "wallet_address": "$wallet",
  "commands": {
    "start": {
      "miner": "$start_miner",
      "full": "$start_full",
      "relay": "$start_relay"
    },
    "stop": "$stop_cmd"
  },
  "container_names": {
    "miner": "$container_miner",
    "full": "$container_full",
    "relay": "$container_relay"
  }
}
EOF
)
    done
    
    nodes_json+="]"
    
    # Discord setup
    echo ""
    read -p "Enable Discord notifications? (Y/n): " enable_discord
    
    local webhook_url=""
    local discord_enabled="false"
    
    if [[ "$enable_discord" =~ ^[Yy]$ ]] || [[ -z "$enable_discord" ]]; then
        discord_enabled="true"
        read -p "Discord Webhook URL: " webhook_url
    fi
    
    # Create config
    cat > "$CONFIG_FILE" << EOF
{
  "version": "1.0",
  "created": "$(date '+%Y-%m-%d %H:%M:%S')",
  
  "discord": {
    "webhook_url": "$webhook_url",
    "enabled": $discord_enabled
  },
  
  "timing": {
    "stop_to_start_wait_minutes": 5,
    "start_verification_wait_minutes": 3,
    "final_logs_wait_minutes": 15,
    "minimum_skip_wait_seconds": 30
  },
  
  "nodes": $nodes_json
}
EOF
    
    echo ""
    echo -e "${GREEN}✅ Configuration created successfully!${NC}"
}

#============================================================
# CRON MANAGEMENT
#============================================================

setup_cron_schedule() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║              ⚙️  Setup Cron Schedule                      ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Check if cron already exists
    if crontab -l 2>/dev/null | grep -q "Node-Restart-Manager.sh"; then
        echo -e "${YELLOW}⚠️  Cron schedule already exists!${NC}"
        echo ""
        read -p "Replace existing schedule? (y/N): " replace
        if [[ ! "$replace" =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    echo -e "${CYAN}How often should nodes restart automatically?${NC}"
    echo ""
    echo -e "${WHITE}Common Options:${NC}"
    echo "  1) Every 2 hours  (12 restarts per day)"
    echo "  2) Every 4 hours  (6 restarts per day)"
    echo "  3) Every 6 hours  (4 restarts per day)"
    echo "  4) Every 8 hours  (3 restarts per day)"
    echo "  5) Every 12 hours (2 restarts per day)"
    echo "  6) Every 24 hours (1 restart per day)"
    echo "  7) Custom interval"
    echo ""
    
    read -p "Enter choice [1-7]: " choice
    
    local cron_expr=""
    local description=""
    
    case $choice in
        1)
            cron_expr="0 */2 * * *"
            description="Every 2 hours"
            ;;
        2)
            cron_expr="0 */4 * * *"
            description="Every 4 hours"
            ;;
        3)
            cron_expr="0 */6 * * *"
            description="Every 6 hours"
            ;;
        4)
            cron_expr="0 */8 * * *"
            description="Every 8 hours"
            ;;
        5)
            cron_expr="0 */12 * * *"
            description="Every 12 hours"
            ;;
        6)
            cron_expr="0 0 * * *"
            description="Every 24 hours"
            ;;
        7)
            read -p "Enter custom interval in hours (1-24): " custom_hours
            cron_expr="0 */${custom_hours} * * *"
            description="Every ${custom_hours} hours"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            return
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}✅ Selected: $description${NC}"
    echo -e "${BLUE}Cron Expression: $cron_expr${NC}"
    echo ""
    
    # Offer test run
    echo -e "${YELLOW}Before installing cron schedule:${NC}"
    echo ""
    echo "  1) Test restart now (recommended)"
    echo "  2) Skip test and install cron immediately"
    echo ""
    
    read -p "Enter choice [1-2]: " test_choice
    
    if [ "$test_choice" = "1" ]; then
        echo ""
        echo -e "${CYAN}🧪 Running test restart...${NC}"
        echo ""
        read -p "Press Enter to start test run..."
        
        perform_restart
        
        echo ""
        read -p "Test successful. Continue with cron installation? (Y/n): " continue_cron
        
        if [[ "$continue_cron" =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Cron installation cancelled${NC}"
            return
        fi
    fi
    
    # Install cron
    echo ""
    echo -e "${CYAN}📝 Installing cron job...${NC}"
    
    # Remove old cron if exists
    crontab -l 2>/dev/null | grep -v "Node-Restart-Manager.sh" | crontab -
    
    # Add new cron
    (crontab -l 2>/dev/null; echo "$cron_expr $SCRIPT_DIR/Node-Restart-Manager.sh --cron >> $CRON_LOG 2>&1") | crontab -
    
    echo -e "${GREEN}✅ Cron job installed successfully!${NC}"
    echo ""
    echo -e "${CYAN}Current Schedule:${NC}"
    echo -e "  $cron_expr $SCRIPT_DIR/Node-Restart-Manager.sh --cron"
    echo ""
    echo -e "${BLUE}System Timezone: $(date +%Z)${NC}"
    echo ""
    
    read -p "Press Enter to return to menu..."
}

show_cron_schedule() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║           📋 Current Cron Schedule                        ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    local cron_line=$(crontab -l 2>/dev/null | grep "Node-Restart-Manager.sh")
    
    if [ -z "$cron_line" ]; then
        echo -e "${YELLOW}Status: ⚪ No cron schedule configured${NC}"
        echo ""
        echo "Use option 2 from main menu to setup cron schedule."
    else
        echo -e "${GREEN}Status: ✅ Active${NC}"
        echo ""
        
        # Extract cron expression
        local cron_expr=$(echo "$cron_line" | awk '{print $1" "$2" "$3" "$4" "$5}')
        
        echo -e "${CYAN}Cron Expression:${NC} $cron_expr"
        echo -e "${CYAN}Command:${NC} $SCRIPT_DIR/Node-Restart-Manager.sh --cron"
        echo ""
        
        # Determine schedule description
        local schedule_desc=""
        case "$cron_expr" in
            "0 */2 * * *") schedule_desc="Every 2 hours" ;;
            "0 */4 * * *") schedule_desc="Every 4 hours" ;;
            "0 */6 * * *") schedule_desc="Every 6 hours" ;;
            "0 */8 * * *") schedule_desc="Every 8 hours" ;;
            "0 */12 * * *") schedule_desc="Every 12 hours" ;;
            "0 0 * * *") schedule_desc="Every 24 hours" ;;
            *) schedule_desc="Custom schedule" ;;
        esac
        
        echo -e "${CYAN}Schedule:${NC} $schedule_desc"
        echo -e "${BLUE}Timezone:${NC} $(date +%Z)"
        echo ""
        
        # Show last run
        if [ -f "$STATE_FILE" ]; then
            local last_run=$(jq -r '.start_time' "$STATE_FILE" 2>/dev/null)
            local last_status=$(jq -r '.final_status' "$STATE_FILE" 2>/dev/null)
            
            if [ "$last_run" != "null" ]; then
                echo -e "${CYAN}Last Run:${NC} $last_run"
                if [ "$last_status" = "success" ]; then
                    echo -e "${CYAN}Status:${NC} ${GREEN}✅ Success${NC}"
                else
                    echo -e "${CYAN}Status:${NC} ${RED}❌ Failed${NC}"
                fi
            fi
        fi
    fi
    
    echo ""
    read -p "Press Enter to return to menu..."
}

change_cron_schedule() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║            🔄 Change Cron Schedule                        ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    local current_cron=$(crontab -l 2>/dev/null | grep "Node-Restart-Manager.sh")
    
    if [ -z "$current_cron" ]; then
        echo -e "${YELLOW}No cron schedule configured${NC}"
        echo ""
        read -p "Setup new schedule? (Y/n): " setup_new
        
        if [[ "$setup_new" =~ ^[Yy]$ ]] || [[ -z "$setup_new" ]]; then
            setup_cron_schedule
        fi
        return
    fi
    
    local current_expr=$(echo "$current_cron" | awk '{print $1" "$2" "$3" "$4" "$5}')
    echo -e "${CYAN}Current Schedule:${NC} $current_expr"
    echo ""
    
    echo -e "${YELLOW}Select new interval:${NC}"
    echo "  1) Every 2 hours"
    echo "  2) Every 4 hours"
    echo "  3) Every 6 hours"
    echo "  4) Every 8 hours"
    echo "  5) Every 12 hours"
    echo "  6) Every 24 hours"
    echo "  7) Custom interval"
    echo "  8) Cancel"
    echo ""
    
    read -p "Enter choice [1-8]: " choice
    
    if [ "$choice" = "8" ]; then
        return
    fi
    
    local new_cron_expr=""
    local new_description=""
    
    case $choice in
        1)
            new_cron_expr="0 */2 * * *"
            new_description="Every 2 hours"
            ;;
        2)
            new_cron_expr="0 */4 * * *"
            new_description="Every 4 hours"
            ;;
        3)
            new_cron_expr="0 */6 * * *"
            new_description="Every 6 hours"
            ;;
        4)
            new_cron_expr="0 */8 * * *"
            new_description="Every 8 hours"
            ;;
        5)
            new_cron_expr="0 */12 * * *"
            new_description="Every 12 hours"
            ;;
        6)
            new_cron_expr="0 0 * * *"
            new_description="Every 24 hours"
            ;;
        7)
            read -p "Enter custom interval in hours (1-24): " custom_hours
            new_cron_expr="0 */${custom_hours} * * *"
            new_description="Every ${custom_hours} hours"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            return
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}✅ Selected: $new_description${NC}"
    echo ""
    echo -e "${YELLOW}This will REPLACE current schedule:${NC}"
    echo -e "  ${RED}Old:${NC} $current_expr"
    echo -e "  ${GREEN}New:${NC} $new_cron_expr"
    echo ""
    
    read -p "Confirm change? (Y/n): " confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Change cancelled${NC}"
        return
    fi
    
    # Update cron
    crontab -l 2>/dev/null | grep -v "Node-Restart-Manager.sh" | crontab -
    (crontab -l 2>/dev/null; echo "$new_cron_expr $SCRIPT_DIR/Node-Restart-Manager.sh --cron >> $CRON_LOG 2>&1") | crontab -
    
    echo ""
    echo -e "${GREEN}✅ Cron schedule updated successfully!${NC}"
    echo ""
    
    read -p "Press Enter to return to menu..."
}

remove_cron_schedule() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║           🗑️  Remove Cron Schedule                        ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    local current_cron=$(crontab -l 2>/dev/null | grep "Node-Restart-Manager.sh")
    
    if [ -z "$current_cron" ]; then
        echo -e "${YELLOW}No cron schedule configured${NC}"
        echo ""
        read -p "Press Enter to return to menu..."
        return
    fi
    
    local current_expr=$(echo "$current_cron" | awk '{print $1" "$2" "$3" "$4" "$5}')
    echo -e "${CYAN}Current Schedule:${NC} $current_expr"
    echo ""
    
    echo -e "${RED}⚠️  WARNING:${NC} This will stop automatic node restarts."
    echo "   You can manually restart nodes using option 1 from the menu."
    echo ""
    
    read -p "Remove cron schedule? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled${NC}"
        return
    fi
    
    # Remove cron
    crontab -l 2>/dev/null | grep -v "Node-Restart-Manager.sh" | crontab -
    
    echo ""
    echo -e "${GREEN}✅ Cron schedule removed successfully!${NC}"
    echo ""
    
    read -p "Press Enter to return to menu..."
}

#============================================================
# NODE RESTART LOGIC
#============================================================

detect_running_mode() {
    local node_num="$1"
    
    # Get container names from config
    local container_miner=$(jq -r ".nodes[] | select(.node_number==$node_num) | .container_names.miner" "$CONFIG_FILE")
    local container_full=$(jq -r ".nodes[] | select(.node_number==$node_num) | .container_names.full" "$CONFIG_FILE")
    local container_relay=$(jq -r ".nodes[] | select(.node_number==$node_num) | .container_names.relay" "$CONFIG_FILE")
    
    # Check which container is running
    if docker ps --format "{{.Names}}" | grep -q "^${container_miner}$"; then
        echo "miner"
    elif docker ps --format "{{.Names}}" | grep -q "^${container_full}$"; then
        echo "full"
    elif docker ps --format "{{.Names}}" | grep -q "^${container_relay}$"; then
        echo "relay"
    else
        echo "stopped"
    fi
}

process_node() {
    local node_num="$1"
    
    log "Processing Node${node_num}"
    
    # Get node config
    local node_config=$(jq ".nodes[] | select(.node_number==$node_num)" "$CONFIG_FILE")
    local install_path=$(echo "$node_config" | jq -r '.install_path')
    local wallet=$(echo "$node_config" | jq -r '.wallet_address')
    
    # Detect current mode
    local current_mode=$(detect_running_mode "$node_num")
    
    if [ "$current_mode" = "stopped" ]; then
        log "Node${node_num} is stopped - skipping"
        
        local message="⚪ **[Node${node_num}] Skipped**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 **Node:** Node${node_num}
💤 **Reason:** Container was stopped before script run
ℹ️ Node${node_num} will remain stopped (no action taken)"
        
        send_discord "$message"
        
        return 0
    fi
    
    # Get container name for current mode
    local container_name=$(echo "$node_config" | jq -r ".container_names.${current_mode}")
    local start_command=$(echo "$node_config" | jq -r ".commands.start.${current_mode}")
    local stop_command=$(echo "$node_config" | jq -r ".commands.stop")
    
    log "Node${node_num} is running in ${current_mode} mode"
    log "Container: $container_name"
    
    # Send processing started message
    local message="🔧 **[Node${node_num}] Processing Started**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 **Node:** Node${node_num}
🎯 **Mode:** ${current_mode^}
📦 **Container:** $container_name
⏱️ **Status:** Stopping container..."
    
    send_discord "$message"
    
    # Stop container
    log "Stopping Node${node_num} container"
    cd "$install_path"
    eval "$stop_command" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "Node${node_num} stopped successfully"
        
        message="🛑 **[Node${node_num}] Container Stopped**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Successfully stopped: $container_name
⏳ Waiting 5 minutes before restart..."
        
        send_discord "$message"
    else
        log "ERROR: Failed to stop Node${node_num}"
        
        message="❌ **[Node${node_num}] Stop Failed**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 **Container:** $container_name
🔴 **Error:** Failed to stop container
⏭️ Continuing to next node..."
        
        send_discord "$message"
        return 1
    fi
    
    # Wait period
    local stop_wait=$(jq -r '.timing.stop_to_start_wait_minutes' "$CONFIG_FILE")
    local stop_wait_seconds=$((stop_wait * 60))
    
    countdown_timer "$stop_wait_seconds" "Waiting before restart..."
    
    # Start container
    log "Starting Node${node_num} in ${current_mode} mode"
    
    message="🚀 **[Node${node_num}] Starting Container**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 **Container:** $container_name
🎯 **Mode:** ${current_mode^}
⏱️ **Command:** $start_command
🔄 Starting..."
    
    send_discord "$message"
    
    cd "$install_path"
    eval "$start_command" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to start Node${node_num}"
        
        message="❌ **[Node${node_num}] Start Failed**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 **Container:** $container_name
🔴 **Error:** Container failed to start
⏭️ Continuing to next node..."
        
        send_discord "$message"
        return 1
    fi
    
    # Verification wait
    local verify_wait=$(jq -r '.timing.start_verification_wait_minutes' "$CONFIG_FILE")
    local verify_wait_seconds=$((verify_wait * 60))
    
    countdown_timer "$verify_wait_seconds" "Verifying startup..."
    
    # Verify container is running
    local is_running=$(docker ps --format "{{.Names}}" | grep -c "^${container_name}$")
    
    if [ "$is_running" -gt 0 ]; then
        log "Node${node_num} verified running"
        
        # Get uptime
        local uptime=$(docker ps --filter "name=${container_name}" --format "{{.Status}}")
        
        message="✅ **[Node${node_num}] Startup Verification**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 **Container:** $container_name
🟢 **Status:** Running
⏰ **Uptime:** ${verify_wait} minutes
✅ Node${node_num} successfully restarted!"
        
        send_discord "$message"
        return 0
    else
        log "ERROR: Node${node_num} not running after startup"
        
        message="❌ **[Node${node_num}] Verification Failed**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 **Container:** $container_name
🔴 **Status:** Not running after ${verify_wait} minutes
⚠️ **Action Required:** Manual intervention needed
⏭️ Continuing to next node..."
        
        send_discord "$message"
        return 1
    fi
}

collect_logs() {
    log "Collecting final logs from all running containers"
    
    # Send header message
    local header_message="📋 **Container Logs - Last 10 Lines**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    send_discord "$header_message"
    
    local node_count=$(jq '.nodes | length' "$CONFIG_FILE")
    
    for ((i=0; i<$node_count; i++)); do
        local node_num=$(jq -r ".nodes[$i].node_number" "$CONFIG_FILE")
        local current_mode=$(detect_running_mode "$node_num")
        
        if [ "$current_mode" = "stopped" ]; then
            local skip_message="**⚪ Node${node_num} - Skipped**
Container was stopped - no logs available"
            
            send_discord "$skip_message"
            continue
        fi
        
        local container_name=$(jq -r ".nodes[$i].container_names.${current_mode}" "$CONFIG_FILE")
        
        # Get last 10 logs and limit length
        local node_logs=$(docker logs --tail 10 "$container_name" 2>&1 | head -c 1500)
        
        # Create individual message per node
        local node_message="**🟢 Node${node_num} (${current_mode^}) - $container_name**
\`\`\`
${node_logs}
\`\`\`"
        
        send_discord "$node_message"
    done
    
    # Send footer message
    local footer_message="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💎 **BlockDAG Investors Community**
**Created By:** ArtX"
    
    send_discord "$footer_message"
}

perform_restart() {
    local start_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    log "=== Restart Manager Started ==="
    log "Mode: $([ "$IS_CRON" = true ] && echo "Cron" || echo "Interactive")"
    
    # Count total nodes
    local total_nodes=$(jq '.nodes | length' "$CONFIG_FILE")
    
    # Scan for running nodes
    local running_count=0
    local stopped_count=0
    
    for ((i=0; i<$total_nodes; i++)); do
        local node_num=$(jq -r ".nodes[$i].node_number" "$CONFIG_FILE")
        local mode=$(detect_running_mode "$node_num")
        
        if [ "$mode" = "stopped" ]; then
            stopped_count=$((stopped_count + 1))
        else
            running_count=$((running_count + 1))
        fi
    done
    
    # Send starting message
    local start_message="🔄 **Node Restart Manager Started**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 **Time:** $start_time
🖥️ **Mode:** $([ "$IS_CRON" = true ] && echo "Cron" || echo "Interactive")
📊 **Nodes Found:** $total_nodes total ($running_count running, $stopped_count stopped)

**Nodes to Process:**"
    
    for ((i=0; i<$total_nodes; i++)); do
        local node_num=$(jq -r ".nodes[$i].node_number" "$CONFIG_FILE")
        local mode=$(detect_running_mode "$node_num")
        
        if [ "$mode" = "stopped" ]; then
            start_message+="
⚪ Node${node_num} (${mode^}) - Stopped - Will skip"
        else
            start_message+="
✅ Node${node_num} (${mode^}) - Running"
        fi
    done
    
    start_message+="
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    send_discord "$start_message"
    
    # Process each node
    local success_count=0
    local fail_count=0
    local skip_count=0
    
    for ((i=0; i<$total_nodes; i++)); do
        local node_num=$(jq -r ".nodes[$i].node_number" "$CONFIG_FILE")
        local mode=$(detect_running_mode "$node_num")
        
        if [ "$mode" = "stopped" ]; then
            skip_count=$((skip_count + 1))
            
            local skip_message="⚪ **[Node${node_num}] Skipped**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 **Node:** Node${node_num}
💤 **Reason:** Container was stopped before script run
ℹ️ Node${node_num} will remain stopped (no action taken)"
            
            send_discord "$skip_message"
            continue
        fi
        
        if process_node "$node_num"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
    done
    
    local end_time=$(date '+%Y-%m-%d %H:%M:%S')
    local duration=$(($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s)))
    local duration_minutes=$((duration / 60))
    
    # Send summary
    local summary_message="🎉 **All Nodes Restart Complete!**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏱️ **Total Duration:** ${duration_minutes} minutes
📊 **Summary:**"
    
    for ((i=0; i<$total_nodes; i++)); do
        local node_num=$(jq -r ".nodes[$i].node_number" "$CONFIG_FILE")
        local mode=$(detect_running_mode "$node_num")
        
        if [ "$mode" = "stopped" ]; then
            summary_message+="
  ⚪ Node${node_num} - Skipped (was stopped)"
        else
            summary_message+="
  ✅ Node${node_num} (${mode^}) - Successfully restarted"
        fi
    done
    
    summary_message+="

**Final Status:** $success_count/$running_count running nodes restarted ✅"
    
    if [ $fail_count -gt 0 ]; then
        summary_message+="
⚠️ **Failures:** $fail_count node(s) failed to restart"
    fi
    
    summary_message+="
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    send_discord "$summary_message"
    
    # Wait for logs
    local logs_wait=$(jq -r '.timing.final_logs_wait_minutes' "$CONFIG_FILE")
    local logs_wait_seconds=$((logs_wait * 60))
    
    if [ "$IS_INTERACTIVE" = true ]; then
        echo ""
        echo -e "${CYAN}⏳ Waiting ${logs_wait} minutes before collecting logs...${NC}"
        echo ""
    fi
    
    countdown_timer "$logs_wait_seconds" "Waiting before log collection..."
    
    # Collect and send logs
    collect_logs
    
    # Save state
    cat > "$STATE_FILE" << EOF
{
  "start_time": "$start_time",
  "end_time": "$end_time",
  "duration_minutes": $duration_minutes,
  "total_nodes": $total_nodes,
  "running_nodes": $running_count,
  "stopped_nodes": $stopped_count,
  "successful_restarts": $success_count,
  "failed_restarts": $fail_count,
  "skipped_nodes": $skip_count,
  "final_status": "$([ $fail_count -eq 0 ] && echo "success" || echo "partial")"
}
EOF
    
    log "=== Restart Manager Completed ==="
}

#============================================================
# MAIN MENU
#============================================================

show_main_menu() {
    while true; do
        clear
        echo -e "${GREEN}${BOLD}"
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "║                                                           ║"
        echo "║         Node Restart Manager v1.0                         ║"
        echo "║         For BlockDAG Investors Community                  ║"
        echo "║         Created By: ArtX                                  ║"
        echo "║                                                           ║"
        echo "╚═══════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        
        # Show config status
        if [ -f "$CONFIG_FILE" ]; then
            local node_count=$(jq '.nodes | length' "$CONFIG_FILE" 2>/dev/null)
            echo -e "${GREEN}Configuration Status: ✅ $node_count node(s) configured${NC}"
        else
            echo -e "${YELLOW}Configuration Status: ⚠️  Not configured${NC}"
        fi
        
        echo ""
        echo -e "${CYAN}Please select an option:${NC}"
        echo ""
        echo "  1) 🚀 Run Restart Now (Interactive Mode)"
        echo "  2) ⚙️  Setup Cron Schedule"
        echo "  3) 📋 Show Current Cron Schedule"
        echo "  4) 🔄 Change Cron Schedule"
        echo "  5) 🗑️  Remove Cron Schedule"
        echo "  6) ⚙️  Edit Configuration"
        echo "  7) 🔍 Test Discord Webhook"
        echo "  8) 📊 View Last Run Status"
        echo "  9) ❌ Exit"
        echo ""
        
        read -p "Enter choice [1-9]: " choice
        
        case $choice in
            1)
                if [ ! -f "$CONFIG_FILE" ]; then
                    echo -e "${RED}❌ Configuration not found${NC}"
                    echo -e "${YELLOW}Please run setup first (option 6)${NC}"
                    read -p "Press Enter to continue..."
                    continue
                fi
                perform_restart
                read -p "Press Enter to return to menu..."
                ;;
            2)
                setup_cron_schedule
                ;;
            3)
                show_cron_schedule
                ;;
            4)
                change_cron_schedule
                ;;
            5)
                remove_cron_schedule
                ;;
            6)
                setup_config
                read -p "Press Enter to return to menu..."
                ;;
            7)
                test_discord_webhook
                ;;
            8)
                show_last_status
                ;;
            9)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                sleep 1
                ;;
        esac
    done
}

test_discord_webhook() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║           🔍 Test Discord Webhook                         ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}❌ Configuration not found${NC}"
        read -p "Press Enter to return to menu..."
        return
    fi
    
    local webhook_url=$(jq -r '.discord.webhook_url' "$CONFIG_FILE")
    local enabled=$(jq -r '.discord.enabled' "$CONFIG_FILE")
    
    echo -e "${CYAN}Current Configuration:${NC}"
    echo -e "  Enabled: $([ "$enabled" = "true" ] && echo "${GREEN}Yes${NC}" || echo "${RED}No${NC}")"
    echo -e "  Webhook: $([ -n "$webhook_url" ] && [ "$webhook_url" != "null" ] && echo "${GREEN}Configured${NC}" || echo "${RED}Not set${NC}")"
    echo ""
    
    if [ "$enabled" != "true" ]; then
        echo -e "${YELLOW}Discord notifications are disabled${NC}"
        echo ""
        read -p "Enable Discord? (Y/n): " enable
        
        if [[ "$enable" =~ ^[Yy]$ ]] || [[ -z "$enable" ]]; then
            jq '.discord.enabled = true' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
            mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            echo -e "${GREEN}✅ Discord enabled${NC}"
            enabled="true"
        else
            read -p "Press Enter to return to menu..."
            return
        fi
    fi
    
    if [ -z "$webhook_url" ] || [ "$webhook_url" = "null" ]; then
        echo -e "${YELLOW}No webhook URL configured${NC}"
        echo ""
        read -p "Enter Discord Webhook URL: " new_webhook
        
        jq --arg url "$new_webhook" '.discord.webhook_url = $url' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        
        webhook_url="$new_webhook"
        echo -e "${GREEN}✅ Webhook saved${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Testing webhook: ${WHITE}${webhook_url:0:50}...${NC}"
    echo ""
    echo -e "${CYAN}Sending test message...${NC}"
    
    local test_message="🧪 **Discord Webhook Test**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Webhook is working correctly!
🕐 Test Time: $(date '+%Y-%m-%d %H:%M:%S')

💎 **BlockDAG Investors Community**
**Created By:** ArtX"
    
    # Create JSON payload
    local payload=$(jq -n --arg content "$test_message" '{content: $content}')
    
    echo -e "${BLUE}Payload preview:${NC}"
    echo "$payload" | jq .
    echo ""
    
    # Send with detailed output
    echo -e "${CYAN}Sending to Discord...${NC}"
    local response=$(curl -H "Content-Type: application/json" \
         -X POST \
         -d "$payload" \
         "$webhook_url" \
         -w "\n%{http_code}" \
         -o /tmp/discord_test.txt 2>&1)
    
    local http_code=$(echo "$response" | tail -1)
    
    echo ""
    if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Success! Message sent (HTTP $http_code)${NC}"
        echo -e "${BLUE}Check your Discord channel for the test message${NC}"
    else
        echo -e "${RED}❌ Failed! (HTTP $http_code)${NC}"
        echo ""
        echo -e "${YELLOW}Response:${NC}"
        cat /tmp/discord_test.txt
        echo ""
        echo -e "${YELLOW}Possible issues:${NC}"
        echo "  • Invalid webhook URL"
        echo "  • Webhook was deleted"
        echo "  • Network connectivity issue"
        echo "  • Rate limit exceeded"
    fi
    
    rm -f /tmp/discord_test.txt
    
    echo ""
    read -p "Press Enter to return to menu..."
}

show_last_status() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║           📊 Last Run Status                              ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    if [ ! -f "$STATE_FILE" ]; then
        echo -e "${YELLOW}No previous run data found${NC}"
        echo ""
        read -p "Press Enter to return to menu..."
        return
    fi
    
    local start_time=$(jq -r '.start_time' "$STATE_FILE")
    local end_time=$(jq -r '.end_time' "$STATE_FILE")
    local duration=$(jq -r '.duration_minutes' "$STATE_FILE")
    local total_nodes=$(jq -r '.total_nodes' "$STATE_FILE")
    local running_nodes=$(jq -r '.running_nodes' "$STATE_FILE")
    local stopped_nodes=$(jq -r '.stopped_nodes' "$STATE_FILE")
    local successful=$(jq -r '.successful_restarts' "$STATE_FILE")
    local failed=$(jq -r '.failed_restarts' "$STATE_FILE")
    local skipped=$(jq -r '.skipped_nodes' "$STATE_FILE")
    local status=$(jq -r '.final_status' "$STATE_FILE")
    
    echo -e "${CYAN}Start Time:${NC} $start_time"
    echo -e "${CYAN}End Time:${NC} $end_time"
    echo -e "${CYAN}Duration:${NC} $duration minutes"
    echo ""
    echo -e "${CYAN}Total Nodes:${NC} $total_nodes"
    echo -e "${CYAN}Running:${NC} $running_nodes"
    echo -e "${CYAN}Stopped:${NC} $stopped_nodes"
    echo ""
    echo -e "${CYAN}Successful Restarts:${NC} ${GREEN}$successful${NC}"
    
    if [ "$failed" -gt 0 ]; then
        echo -e "${CYAN}Failed Restarts:${NC} ${RED}$failed${NC}"
    fi
    
    echo -e "${CYAN}Skipped:${NC} $skipped"
    echo ""
    
    if [ "$status" = "success" ]; then
        echo -e "${CYAN}Final Status:${NC} ${GREEN}✅ Success${NC}"
    else
        echo -e "${CYAN}Final Status:${NC} ${YELLOW}⚠️  Partial Success${NC}"
    fi
    
    echo ""
    read -p "Press Enter to return to menu..."
}

#============================================================
# MAIN EXECUTION
#============================================================

# Setup directory structure
setup_directory

# Check for config
if [ ! -f "$CONFIG_FILE" ]; then
    if [ "$IS_CRON" = true ]; then
        log_cron "ERROR: Config file not found, cannot run in cron mode"
        exit 1
    fi
    
    echo -e "${YELLOW}⚠️  Configuration not found${NC}"
    echo ""
    read -p "Run setup wizard now? (Y/n): " run_setup
    
    if [[ "$run_setup" =~ ^[Nn]$ ]]; then
        exit 0
    fi
    
    setup_config
    
    echo ""
    echo -e "${GREEN}✅ Setup complete!${NC}"
    echo ""
    read -p "Press Enter to continue to main menu..."
fi

# Handle direct command flags
if [ "$TEST_DISCORD" = true ]; then
    test_discord_webhook
    exit 0
fi

if [ "$SHOW_STATUS" = true ]; then
    show_last_status
    exit 0
fi

if [ "$SETUP_CRON_DIRECT" = true ]; then
    setup_cron_schedule
    exit 0
fi

if [ "$SHOW_CRON_DIRECT" = true ]; then
    show_cron_schedule
    exit 0
fi

if [ "$REMOVE_CRON_DIRECT" = true ]; then
    remove_cron_schedule
    exit 0
fi

if [ "$REBUILD_CONFIG" = true ]; then
    setup_config
    exit 0
fi

if [ "$RUN_NOW" = true ] || [ "$IS_CRON" = true ]; then
    perform_restart
    exit 0
fi

# Show main menu
show_main_menu
