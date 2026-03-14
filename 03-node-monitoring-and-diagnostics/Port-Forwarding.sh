#!/bin/bash

# BlockDAG Port Checker & Configuration Guide
# For Blockdag Investors Group
# Created By ArtX

# Trap to clear sudo cache on exit
trap cleanup EXIT INT TERM

cleanup() {
    # Clear sudo timestamp cache
    sudo -k 2>/dev/null
}

# Cache sudo credentials at the start
cache_sudo() {
    echo "This script requires sudo privileges for system checks."
    echo ""
    if ! sudo -v; then
        echo -e "${RED}❌ Sudo access required. Exiting...${NC}"
        exit 1
    fi
    echo ""
}

# Keep sudo alive in background
keep_sudo_alive() {
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" 2>/dev/null || exit
    done 2>/dev/null &
}

# Check for demo mode
DEMO_MODE=false
if [ "$1" == "--demo" ] || [ "$1" == "-d" ]; then
    DEMO_MODE=true
fi

clear
echo "=========================================="
echo "  BlockDAG Port Checker & Setup Guide"
echo "  For Blockdag Investors Group"
echo "  Created By ArtX"
echo "=========================================="
echo ""

if [ "$DEMO_MODE" = true ]; then
    echo -e "\033[1;33m[DEMO MODE - Simulating Results]\033[0m"
    echo ""
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Cache sudo credentials if not in demo mode
if [ "$DEMO_MODE" = false ]; then
    cache_sudo
    keep_sudo_alive
fi

# Show why port forwarding matters
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Why Port Forwarding Matters${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}🌐 Become a Full Network Participant${NC}"
echo "   Without port forwarding, your node can only reach out to others,"
echo "   but other nodes cannot connect to you. This makes you rely entirely"
echo "   on other nodes' generosity without giving back."
echo ""
echo -e "${GREEN}⚡ Faster Sync & Better Performance${NC}"
echo "   Proper port forwarding allows bidirectional connections, giving you"
echo "   more stable peers and significantly faster blockchain sync speeds."
echo ""
echo -e "${GREEN}🤝 Strengthen the BlockDAG Network${NC}"
echo "   By accepting incoming connections, you help new nodes join and sync."
echo "   Every properly configured node makes the entire network stronger"
echo "   and more decentralized."
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -p "Press Enter to begin port checking..."
echo ""

# Function to detect BlockDAG containers
detect_containers() {
    echo -e "${BLUE}[1/5] Detecting BlockDAG Nodes...${NC}"
    
    if [ "$DEMO_MODE" = true ]; then
        CONTAINERS="bdag-miner-node1
bdag-full-node2"
        echo -e "${GREEN}✓ Found running nodes (demo):${NC}"
        for container in $CONTAINERS; do
            echo "  • $container"
        done
        echo ""
        return
    fi
    
    # Show all running containers first
    echo "Running Docker containers:"
    ALL_CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null)
    
    if [ -z "$ALL_CONTAINERS" ]; then
        echo -e "${RED}❌ No Docker containers running at all${NC}"
        echo ""
        echo "Please start your BlockDAG node first, then run this script again."
        echo ""
        echo -e "${YELLOW}💡 Tip: Run with --demo flag to see sample output:${NC}"
        echo "   bash Check-Ports.sh --demo"
        echo ""
        exit 1
    fi
    
    echo "$ALL_CONTAINERS" | while read container; do
        echo "  • $container"
    done
    echo ""
    
    # Try to detect BlockDAG containers with multiple patterns
    CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null | grep -iE "bdag|blockdag|kaspa")
    
    if [ -z "$CONTAINERS" ]; then
        echo -e "${YELLOW}⚠ Could not auto-detect BlockDAG containers from the list above${NC}"
        echo ""
        echo -e "${BLUE}Which container(s) are your BlockDAG nodes?${NC}"
        echo "Enter container name (or press Enter to exit):"
        read -r USER_CONTAINER
        
        if [ -z "$USER_CONTAINER" ]; then
            echo "Exiting..."
            exit 1
        fi
        
        # Verify the user's container exists
        if echo "$ALL_CONTAINERS" | grep -q "^${USER_CONTAINER}$"; then
            CONTAINERS="$USER_CONTAINER"
            echo -e "${GREEN}✓ Using container: $CONTAINERS${NC}"
            echo ""
        else
            echo -e "${RED}❌ Container '$USER_CONTAINER' not found in running containers${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Auto-detected BlockDAG nodes:${NC}"
        for container in $CONTAINERS; do
            echo "  • $container"
        done
        echo ""
    fi
}

# Function to determine required ports based on node type
get_required_ports() {
    local container=$1
    
    if [[ $container == *"miner"* ]]; then
        echo "18150"
    elif [[ $container == *"full"* ]]; then
        echo "18150"
    elif [[ $container == *"relay"* ]]; then
        echo "38131"
    else
        echo "18150"
    fi
}

# Function to check local port binding
check_local_ports() {
    echo -e "${BLUE}[2/5] Checking Local Port Status...${NC}"
    
    for container in $CONTAINERS; do
        REQUIRED_PORTS=$(get_required_ports "$container")
        
        echo "Container: $container"
        for port in $REQUIRED_PORTS; do
            # Check if port is bound locally
            PORT_CHECK=$(netstat -tuln 2>/dev/null | grep ":$port " || ss -tuln 2>/dev/null | grep ":$port ")
            
            if [ -n "$PORT_CHECK" ]; then
                echo -e "  Port $port: ${GREEN}✓ Listening locally${NC}"
            else
                echo -e "  Port $port: ${RED}✗ Not listening${NC}"
            fi
        done
        echo ""
    done
}

# Function to check and configure firewall
check_firewall() {
    echo -e "${BLUE}[3/5] Checking Firewall Status...${NC}"
    
    # Check if UFW is installed
    if ! command -v ufw &> /dev/null; then
        echo -e "${GREEN}✓ UFW firewall not installed${NC}"
        echo "No firewall blocking ports."
        echo ""
        return
    fi
    
    # Check if UFW is active
    UFW_STATUS=$(sudo ufw status 2>/dev/null | head -n 1)
    
    if echo "$UFW_STATUS" | grep -q "inactive"; then
        echo -e "${GREEN}✓ UFW firewall is inactive${NC}"
        echo "No firewall blocking ports."
        echo ""
        return
    fi
    
    echo -e "${GREEN}✓ UFW firewall is active${NC}"
    
    # Collect all required ports across all containers
    ALL_REQUIRED_PORTS=""
    for container in $CONTAINERS; do
        REQUIRED_PORTS=$(get_required_ports "$container")
        ALL_REQUIRED_PORTS="$ALL_REQUIRED_PORTS $REQUIRED_PORTS"
    done
    
    # Remove duplicates
    ALL_REQUIRED_PORTS=$(echo "$ALL_REQUIRED_PORTS" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    
    # Check which ports need to be opened
    PORTS_TO_OPEN=""
    PORTS_ALREADY_OPEN=""
    
    echo "Checking firewall rules for required ports:"
    for port in $ALL_REQUIRED_PORTS; do
        # Check if port is already allowed in UFW
        UFW_RULE_CHECK=$(sudo ufw status | grep -E "^${port}(/tcp|/udp)?\s+ALLOW" || echo "")
        
        if [ -n "$UFW_RULE_CHECK" ]; then
            echo -e "  Port $port: ${GREEN}✓ Already configured${NC}"
            PORTS_ALREADY_OPEN="$PORTS_ALREADY_OPEN $port"
        else
            echo -e "  Port $port: ${RED}❌ Not configured${NC}"
            PORTS_TO_OPEN="$PORTS_TO_OPEN $port"
        fi
    done
    echo ""
    
    # Only prompt if there are ports that need to be opened
    if [ -n "$PORTS_TO_OPEN" ]; then
        PORT_COUNT=$(echo "$PORTS_TO_OPEN" | wc -w)
        
        echo "╔════════════════════════════════════════════════════╗"
        echo "║  Your firewall is blocking $PORT_COUNT port(s)!               ║"
        echo "║  These ports need to be opened for your nodes.    ║"
        echo "╚════════════════════════════════════════════════════╝"
        echo ""
        echo "The following commands will be executed:"
        for port in $PORTS_TO_OPEN; do
            echo "  sudo ufw allow $port/tcp"
            echo "  sudo ufw allow $port/udp"
        done
        echo ""
        
        read -p "Open these ports in firewall now? (Y/N): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for port in $PORTS_TO_OPEN; do
                echo "Opening port $port..."
                sudo ufw allow $port/tcp >/dev/null 2>&1
                sudo ufw allow $port/udp >/dev/null 2>&1
            done
            echo ""
            echo -e "${GREEN}✓ Firewall rules added successfully!${NC}"
            echo ""
        else
            echo ""
            echo -e "${YELLOW}Firewall ports NOT opened.${NC}"
            echo ""
            echo "To open ports manually later, run these commands:"
            for port in $PORTS_TO_OPEN; do
                echo "  sudo ufw allow $port/tcp"
                echo "  sudo ufw allow $port/udp"
            done
            echo ""
            echo "Run these commands after configuring your router."
            echo ""
        fi
    else
        echo -e "${GREEN}✓ All required ports are already configured in firewall!${NC}"
        echo ""
    fi
}

# Function to get network information
get_network_info() {
    echo -e "${BLUE}[4/5] Getting Network Information...${NC}"
    
    # Get local IP
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    # Get gateway IP
    GATEWAY_IP=$(ip route | grep default | awk '{print $3}')
    
    # Get public IP
    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "Unable to detect")
    
    echo -e "${GREEN}Your Local IP:${NC} $LOCAL_IP"
    echo -e "${GREEN}Your Router IP:${NC} $GATEWAY_IP"
    echo -e "${GREEN}Your Public IP:${NC} $PUBLIC_IP"
    echo ""
    
    # Check for CGNAT
    if [ "$PUBLIC_IP" != "Unable to detect" ]; then
        echo -e "${BLUE}Checking for CGNAT (Carrier-Grade NAT)...${NC}"
        echo ""
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║                    CGNAT DETECTION CHECK                         ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "To verify if you're behind CGNAT:"
        echo ""
        echo "1. Open your router admin panel: http://$GATEWAY_IP"
        echo "2. Look for 'Internet Status', 'WAN', or 'Connection Status'"
        echo "3. Find the 'WAN IP Address' or 'Internet IP Address'"
        echo ""
        echo -e "${YELLOW}Compare your router's WAN IP with your Public IP:${NC}"
        echo "   Your Public IP: $PUBLIC_IP"
        echo ""
        echo "┌──────────────────────────────────────────────────────────────┐"
        echo "│  IF WAN IP = Public IP                                       │"
        echo "│  ✓ NO CGNAT - Port forwarding will work! ✅😊               │"
        echo "│                                                              │"
        echo "│  IF WAN IP ≠ Public IP                                       │"
        echo "│  ✗ CGNAT DETECTED - Port forwarding won't work! ⚠️😞        │"
        echo "└──────────────────────────────────────────────────────────────┘"
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}SOLUTION IF CGNAT DETECTED:${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${GREEN}Contact Your ISP and Request a Static Public IP${NC}"
        echo ""
        echo "What to say:"
        echo '  "I need a static public IP address for running a blockchain'
        echo '   node. I am currently behind CGNAT and need port forwarding'
        echo '   to work. Can you provide a static IP?"'
        echo ""
        echo "Expected cost: \$5-15/month"
        echo ""
        echo "Benefits:"
        echo "  ✓ Gets you out of CGNAT permanently"
        echo "  ✓ Port forwarding works immediately"
        echo "  ✓ No VPN or complex setup needed"
        echo "  ✓ Full network participation"
        echo "  ✓ Better node performance"
        echo ""
        echo -e "${YELLOW}Why this is the best solution:${NC}"
        echo "  • Works for 100% of users"
        echo "  • Simple and permanent"
        echo "  • ISPs commonly offer this service"
        echo "  • Your existing router config will work without changes"
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        read -p "Press Enter to continue..."
        echo ""
    fi
}

# Function to test external port accessibility
test_external_ports() {
    echo -e "${BLUE}[5/5] Port Forwarding Instructions...${NC}"
    echo ""
    echo "External port testing requires online services."
    echo "After configuring your router, test your ports at:"
    echo -e "🔗 ${CYAN}https://www.yougetsignal.com/tools/open-ports/${NC}"
    echo ""
}

# Function to provide port forwarding instructions
provide_instructions() {
    echo "=========================================="
    echo "  PORT FORWARDING SETUP GUIDE"
    echo "=========================================="
    echo ""
    
    echo -e "${GREEN}Your Configuration Details:${NC}"
    echo "  Local IP Address: $LOCAL_IP"
    echo "  Router Gateway: $GATEWAY_IP"
    echo ""
    
    echo -e "${YELLOW}Required Port Forwards:${NC}"
    for container in $CONTAINERS; do
        REQUIRED_PORTS=$(get_required_ports "$container")
        NODE_TYPE=$(echo "$container" | grep -oP '(miner|full|relay)' || echo "node")
        
        echo ""
        echo "For $container ($NODE_TYPE node):"
        for port in $REQUIRED_PORTS; do
            echo "  External Port: $port → Internal IP: $LOCAL_IP:$port (TCP/UDP)"
        done
    done
    echo ""
    
    echo "=========================================="
    echo -e "${BLUE}MANUAL ROUTER CONFIGURATION:${NC}"
    echo "=========================================="
    echo ""
    echo -e "1. Open your web browser and go to: http://$GATEWAY_IP ${GREEN}${BOLD}(Your Detected Router)${NC}"
    echo ""
    echo "2. Login with your router credentials"
    echo "   (Usually admin/admin or admin/password - check router label)"
    echo ""
    echo "3. Find the Port Forwarding section:"
    echo "   - Common names: 'Port Forwarding', 'NAT', 'Virtual Server'"
    echo "   - Usually under: Advanced → NAT or Firewall settings"
    echo ""
    echo "4. Add port forwarding rules EXACTLY as shown below:"
    echo ""
    
    # Show exact configuration for each container
    local rule_number=1
    for container in $CONTAINERS; do
        REQUIRED_PORTS=$(get_required_ports "$container")
        NODE_TYPE=$(echo "$container" | grep -oP '(miner|full|relay)' || echo "node")
        
        for port in $REQUIRED_PORTS; do
            echo -e "${GREEN}   Rule #$rule_number - $container ($NODE_TYPE):${NC}"
            echo "   ┌─────────────────────────────────────────┐"
            echo "   │ Service Name:    BlockDAG-Port-$port    │"
            echo "   │ External Port:   $port                  │"
            echo "   │ Internal IP:     $LOCAL_IP              │"
            echo "   │ Internal Port:   $port                  │"
            echo "   │ Protocol:        TCP and UDP (Both)     │"
            echo "   └─────────────────────────────────────────┘"
            echo ""
            rule_number=$((rule_number + 1))
        done
    done
    
    echo "5. Save changes and reboot your router"
    echo ""
    echo -e "${YELLOW}📋 Quick Copy Reference:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for container in $CONTAINERS; do
        REQUIRED_PORTS=$(get_required_ports "$container")
        for port in $REQUIRED_PORTS; do
            echo "Port $port → $LOCAL_IP:$port (TCP+UDP)"
        done
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "=========================================="
    echo -e "${BLUE}VERIFICATION:${NC}"
    echo "=========================================="
    echo ""
    echo "After configuring, test your ports at:"
    echo -e "🔗 ${CYAN}https://www.yougetsignal.com/tools/open-ports/${NC}"
    echo ""
    echo "Or run this script again to re-check status."
    echo ""
    
    echo "=========================================="
    echo -e "${GREEN}Common Router Web Interfaces:${NC}"
    echo "=========================================="
    echo "  TP-Link:    http://192.168.0.1 or http://tplinkwifi.net"
    echo "  Netgear:    http://192.168.1.1 or http://routerlogin.net"
    echo "  Linksys:    http://192.168.1.1 or http://myrouter.local"
    echo "  ASUS:       http://192.168.1.1 or http://router.asus.com"
    echo "  D-Link:     http://192.168.0.1"
    echo "=========================================="
    echo ""
    
    # Add motivational message about why port forwarding matters
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│                                                                     │"
    echo "│  $(tput sitm)Why Port Forwarding Matters for BlockDAG:$(tput ritm)                         │"
    echo "│                                                                     │"
    echo "│  $(tput sitm)When you forward your ports, you transform your node from a$(tput ritm)          │"
    echo "│  $(tput sitm)passive observer into an active contributor to the network.$(tput ritm)         │"
    echo "│                                                                     │"
    echo "│  $(tput sitm)Without port forwarding:$(tput ritm)                                            │"
    echo "│  ⬇️ Your node can only receive data (one-way communication)          │"
    echo "│  ❌ Other nodes cannot connect to you                                │"
    echo "│  ⚠️ You rely entirely on others to sync                              │"
    echo "│                                                                     │"
    echo "│  $(tput sitm)With port forwarding:$(tput ritm)                                               │"
    echo "│  🚀 You help new nodes sync faster                                   │"
    echo "│  💪 You strengthen network decentralization                          │"
    echo "│  🤝 You become a trusted peer for others                             │"
    echo "│  📈 You support the BlockDAG ecosystem's growth                      │"
    echo "│                                                                     │"
    echo "│  $(tput sitm)Every properly configured node makes BlockDAG stronger,$(tput ritm)            │"
    echo "│  $(tput sitm)more resilient, and truly decentralized.$(tput ritm)                           │"
    echo "│                                                                     │"
    echo "│  $(tput sitm)Thank you for contributing to the network! 🚀$(tput ritm)                      │"
    echo "│                                                                     │"
    echo "└─────────────────────────────────────────────────────────────────────┘"
    echo ""
}

# Main execution
main() {
    detect_containers
    check_local_ports
    check_firewall
    get_network_info
    test_external_ports
    provide_instructions
}

# Run main function
main
