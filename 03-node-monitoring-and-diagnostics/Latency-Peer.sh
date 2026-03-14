#!/bin/bash

# ============================================================================
# BlockDAG Node Ping Status Checker v3.2
# Enhanced: Geographic peer analysis with latency and recommendations
# Fixed: Health score bug (all nodes now get Section 1 check)
# Fixed: Millisecond timestamp parsing, BDAG TCP latency, blocks/second
# Created By: ArtX
# For: BlockDAG Investors Community
# ============================================================================

set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Sudo management
SUDO_CACHED=false
SUDO_KEEPALIVE_PID=""

# Your location (Melbourne, Australia)
MY_LAT="-37.8136"
MY_LON="144.9631"
MY_LOCATION="Melbourne, Australia"

cleanup_sudo() {
    if [ "$SUDO_CACHED" = true ]; then
        if [ -n "$SUDO_KEEPALIVE_PID" ]; then
            kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
        fi
        sudo -k 2>/dev/null
        SUDO_CACHED=false
    fi
}

trap 'cleanup_sudo; exit 130' INT TERM
trap 'cleanup_sudo' EXIT

cache_sudo() {
    if [ "$SUDO_CACHED" = false ]; then
        if sudo -v 2>/dev/null; then
            SUDO_CACHED=true
            (while true; do sudo -n true 2>/dev/null; sleep 50; done) &
            SUDO_KEEPALIVE_PID=$!
            return 0
        else
            return 1
        fi
    fi
    return 0
}

# Detect Docker
DOCKER_CMD="docker"
if ! docker ps &>/dev/null 2>&1; then
    if sudo -n docker ps &>/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
        cache_sudo
    elif sudo docker ps &>/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
        echo -e "${CYAN}🔐 Docker requires sudo access...${NC}"
        cache_sudo || {
            echo -e "${RED}❌ Cannot access Docker${NC}"
            exit 1
        }
    else
        echo -e "${RED}❌ Cannot access Docker${NC}"
        exit 1
    fi
fi

# Port check command
if command -v ss &>/dev/null; then
    PORT_CMD="ss -tuln"
elif command -v netstat &>/dev/null; then
    PORT_CMD="netstat -tuln"
else
    PORT_CMD=""
fi

# Utility functions
hex_to_dec() {
    local hex=$1
    echo $((16#${hex#0x}))
}

format_number() {
    printf "%'d" "$1" 2>/dev/null || echo "$1"
}

calculate_eta() {
    local remaining=$1
    local speed=$2
    
    if [ "$speed" -eq 0 ]; then
        echo "Unknown"
        return
    fi
    
    local hours=$((remaining / speed))
    local days=$((hours / 24))
    local remaining_hours=$((hours % 24))
    
    if [ "$days" -gt 0 ]; then
        echo "~${days} days ${remaining_hours} hours"
    elif [ "$hours" -gt 0 ]; then
        echo "~${hours} hours"
    else
        local minutes=$((remaining * 60 / speed))
        echo "~${minutes} minutes"
    fi
}

get_future_date() {
    local days=$1
    if date --version &>/dev/null 2>&1; then
        date -d "+${days} days" "+%b %d, %Y" 2>/dev/null || echo "Unknown"
    else
        date -v+${days}d "+%b %d, %Y" 2>/dev/null || echo "Unknown"
    fi
}

# TCP latency test function
test_tcp_latency() {
    local host=$1
    local port=$2
    
    if ! command -v nc &>/dev/null; then
        echo "-1"
        return
    fi
    
    local start_ms=$(date +%s%3N 2>/dev/null || echo "0")
    if [ "$start_ms" = "0" ]; then
        echo "-1"
        return
    fi
    
    if timeout 3 nc -z -w2 "$host" "$port" 2>/dev/null; then
        local end_ms=$(date +%s%3N 2>/dev/null || echo "0")
        if [ "$end_ms" = "0" ]; then
            echo "-1"
            return
        fi
        local latency=$((end_ms - start_ms))
        echo "$latency"
    else
        echo "-1"
    fi
}

# Ping latency test function
test_ping_latency() {
    local ip=$1
    local latency=$(ping -c 2 -W 2 "$ip" 2>/dev/null | grep "rtt min/avg/max" | cut -d'/' -f5 | cut -d'.' -f1)
    if [ -z "$latency" ]; then
        echo "999"
    else
        echo "$latency"
    fi
}

# Get geolocation for IP
get_geolocation() {
    local ip=$1
    local response=$(curl -s --max-time 3 "http://ip-api.com/json/${ip}?fields=country,city,lat,lon,status" 2>/dev/null)
    
    if [ -z "$response" ] || ! echo "$response" | grep -q '"status":"success"'; then
        echo "Unknown|Unknown|0|0"
        return
    fi
    
    local country=$(echo "$response" | grep -oP '"country":"\K[^"]+' || echo "Unknown")
    local city=$(echo "$response" | grep -oP '"city":"\K[^"]+' || echo "Unknown")
    local lat=$(echo "$response" | grep -oP '"lat":\K[0-9.-]+' || echo "0")
    local lon=$(echo "$response" | grep -oP '"lon":\K[0-9.-]+' || echo "0")
    
    echo "${country}|${city}|${lat}|${lon}"
}

# Calculate distance using Haversine formula
calculate_distance() {
    local lat1=$1
    local lon1=$2
    local lat2=$3
    local lon2=$4
    
    # Use bc if available, otherwise approximate
    if command -v bc &>/dev/null; then
        local dlat=$(echo "$lat2 - $lat1" | bc 2>/dev/null || echo "0")
        local dlon=$(echo "$lon2 - $lon1" | bc 2>/dev/null || echo "0")
        
        # Rough approximation: 111km per degree
        local dist=$(echo "sqrt(($dlat * 111)^2 + ($dlon * 111)^2)" | bc 2>/dev/null || echo "0")
        echo "$dist" | cut -d'.' -f1
    else
        # Fallback: rough calculation without bc
        local dlat_int=${lat2%.*}
        local dlon_int=${lon2%.*}
        local lat1_int=${lat1%.*}
        local lon1_int=${lon1%.*}
        
        dlat_int=$((dlat_int - lat1_int))
        dlon_int=$((dlon_int - lon1_int))
        
        # Absolute values
        dlat_int=${dlat_int#-}
        dlon_int=${dlon_int#-}
        
        echo $((dlat_int * 111 + dlon_int * 111))
    fi
}

# Classify region based on country
classify_region() {
    local country=$1
    
    case "$country" in
        Australia|New\ Zealand|Singapore|Hong\ Kong|Japan|South\ Korea|China|Taiwan|Thailand|Vietnam|Malaysia|Indonesia|Philippines|India)
            echo "Asia-Pacific"
            ;;
        Germany|France|United\ Kingdom|UK|Netherlands|Italy|Spain|Poland|Sweden|Norway|Denmark|Finland|Belgium|Austria|Switzerland|Ireland|Portugal)
            echo "Europe"
            ;;
        South\ Africa|Nigeria|Kenya|Egypt|Morocco|Ghana|Ethiopia)
            echo "Africa"
            ;;
        United\ States|USA|Canada|Brazil|Mexico|Argentina|Chile|Colombia)
            echo "Americas"
            ;;
        *)
            echo "Other"
            ;;
    esac
}

clear
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}║      🌐 BlockDAG Node Ping Status Checker v3.2 🌐        ║${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}║         💎 BlockDAG Investors Community 💎                ║${NC}"
echo -e "${CYAN}${BOLD}║                  Created By: ArtX                         ║${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}🔍 Detecting BlockDAG nodes...${NC}"
CONTAINERS=$($DOCKER_CMD ps --filter "name=blockdag" --format "{{.Names}}")

if [ -z "$CONTAINERS" ]; then
    echo -e "${RED}❌ No BlockDAG containers found running!${NC}"
    echo -e "${YELLOW}Start your nodes first, then run this script.${NC}"
    echo ""
    exit 1
fi

CONTAINER_COUNT=$(echo "$CONTAINERS" | wc -l)
echo -e "${GREEN}✅ Found ${BOLD}$CONTAINER_COUNT${NC}${GREEN} BlockDAG node(s) running${NC}"
echo ""

TOTAL_NODES=$CONTAINER_COUNT
HEALTHY_NODES=0
SYNCING_NODES=0
ERROR_NODES=0

NODE_NUM=1
for CONTAINER in $CONTAINERS; do
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}📦 Node $NODE_NUM: $CONTAINER${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    NODE_HEALTH_SCORE=0
    
    RPC_PORT=$($DOCKER_CMD port "$CONTAINER" 38131 2>/dev/null | cut -d':' -f2 | head -1)
    HTTP_PORT=$($DOCKER_CMD port "$CONTAINER" 18545 2>/dev/null | cut -d':' -f2 | head -1)
    PEER_PORT=$($DOCKER_CMD port "$CONTAINER" 18150 2>/dev/null | cut -d':' -f2 | head -1)
    
    RPC_PORT=${RPC_PORT:-38131}
    HTTP_PORT=${HTTP_PORT:-18545}
    PEER_PORT=${PEER_PORT:-18150}
    
    # 1. Internet Connectivity & BDAG Latency
    echo -e "${BLUE}${BOLD}1. Network Connectivity${NC}"
    
    # Internet latency (same for all nodes, but check per-node for consistency)
    PING_OUTPUT=$(ping -c 4 -W 2 8.8.8.8 2>&1)
    if echo "$PING_OUTPUT" | grep -q "0% packet loss"; then
        AVG_LATENCY=$(echo "$PING_OUTPUT" | grep "rtt min/avg/max" | cut -d'/' -f5 | cut -d'.' -f1)
        echo -e "   ${GREEN}✅ Internet Connected${NC}"
        echo -e "   ${CYAN}⏱️  Internet latency: ${AVG_LATENCY}ms${NC}"
        ((NODE_HEALTH_SCORE++))
    else
        echo -e "   ${RED}❌ No internet connection${NC}"
    fi
    
    # BDAG peer TCP latency (check for all nodes)
    BDAG_PEER="13.245.135.249"
    BDAG_PORT="18150"
    echo -e "   ${CYAN}🔍 Testing BDAG peer connection...${NC}"
    BDAG_LATENCY=$(test_tcp_latency "$BDAG_PEER" "$BDAG_PORT")
    
    if [ "$BDAG_LATENCY" != "-1" ]; then
        echo -e "   ${GREEN}✅ BDAG Peer Reachable${NC}"
        echo -e "   ${CYAN}🪩 BDAG Node latency: ${BDAG_LATENCY}ms${NC}"
    else
        echo -e "   ${YELLOW}⚠️  BDAG peer latency check unavailable${NC}"
        echo -e "   ${CYAN}   (netcat not installed or connection timeout)${NC}"
    fi
    
    echo ""
    
    # 2. Container Status
    echo -e "${BLUE}${BOLD}2. Container Status${NC}"
    CONTAINER_STATUS=$($DOCKER_CMD inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null)
    CONTAINER_UPTIME=$($DOCKER_CMD inspect -f '{{.State.StartedAt}}' "$CONTAINER" 2>/dev/null | cut -d'T' -f1,2 | tr 'T' ' ' | cut -d'+' -f1)
    if [ "$CONTAINER_STATUS" = "running" ]; then
        echo -e "   ${GREEN}✅ Running${NC}"
        echo -e "   ${CYAN}🕐 Started: $CONTAINER_UPTIME${NC}"
        ((NODE_HEALTH_SCORE++))
    else
        echo -e "   ${RED}❌ Not running (Status: $CONTAINER_STATUS)${NC}"
    fi
    echo ""
    
    # 3. Port Status
    echo -e "${BLUE}${BOLD}3. Port Status${NC}"
    PORTS_OK=0
    
    if [ -n "$PORT_CMD" ]; then
        if $PORT_CMD 2>/dev/null | grep -q ":$PEER_PORT "; then
            echo -e "   ${GREEN}✅ Peer Port ($PEER_PORT): Listening${NC}"
            ((PORTS_OK++))
        else
            echo -e "   ${RED}❌ Peer Port ($PEER_PORT): Not listening${NC}"
        fi
        
        if $PORT_CMD 2>/dev/null | grep -q ":$HTTP_PORT "; then
            echo -e "   ${GREEN}✅ HTTP Port ($HTTP_PORT): Listening${NC}"
            ((PORTS_OK++))
        else
            echo -e "   ${RED}❌ HTTP Port ($HTTP_PORT): Not listening${NC}"
        fi
        
        if $PORT_CMD 2>/dev/null | grep -q ":$RPC_PORT "; then
            echo -e "   ${GREEN}✅ RPC Port ($RPC_PORT): Listening${NC}"
            ((PORTS_OK++))
        else
            echo -e "   ${RED}❌ RPC Port ($RPC_PORT): Not listening${NC}"
        fi
        
        if [ $PORTS_OK -ge 2 ]; then
            ((NODE_HEALTH_SCORE++))
        fi
    else
        echo -e "   ${YELLOW}⚠️  Port check tools not available${NC}"
    fi
    echo ""
    
    # 4. RPC API Status
    echo -e "${BLUE}${BOLD}4. RPC API Status${NC}"
    RPC_RESPONSE=$(curl -s -m 5 -X POST http://localhost:$HTTP_PORT \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null)
    
    CURRENT_BLOCK=""
    if echo "$RPC_RESPONSE" | grep -q "result"; then
        BLOCK_HEX=$(echo "$RPC_RESPONSE" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        CURRENT_BLOCK=$(hex_to_dec "$BLOCK_HEX")
        echo -e "   ${GREEN}✅ API Responding${NC}"
        echo -e "   ${CYAN}📦 Current Block: $(format_number $CURRENT_BLOCK)${NC}"
        ((NODE_HEALTH_SCORE++))
    else
        echo -e "   ${RED}❌ API not responding${NC}"
    fi
    echo ""
    
    # ========================================================================
    # 5. Peer Connections with Geographic Analysis
    # ========================================================================
    echo -e "${BLUE}${BOLD}5. Peer Connections & Geographic Analysis${NC}"
    
    # Get peer count
    PEER_LINE=$($DOCKER_CMD logs "$CONTAINER" 2>&1 | grep "activePeers" | tail -1)
    PEER_COUNT=0
    
    if [ -n "$PEER_LINE" ]; then
        PEER_COUNT=$(echo "$PEER_LINE" | grep -oP 'activePeers:\K[0-9]+' || echo "0")
    fi
    
    if [ "$PEER_COUNT" -gt 0 ]; then
        echo -e "   ${GREEN}✅ Connected to $PEER_COUNT peer(s)${NC}"
        echo -e "   ${CYAN}🌍 Analyzing peer locations and latency...${NC}"
        echo -e "   ${YELLOW}   (This may take 15-30 seconds depending on peer count)${NC}"
        echo ""
        
        # Extract unique peer IPs and peer IDs from logs
        PEER_DATA=$($DOCKER_CMD logs "$CONTAINER" 2>&1 | grep -oP '/ip4/[0-9.]+/tcp/18150/p2p/[A-Za-z0-9]+' | sort -u)
        
        if [ -z "$PEER_DATA" ]; then
            echo -e "   ${YELLOW}⚠️  Could not extract peer information from logs${NC}"
        else
            # Arrays to store peer information
            declare -a PEER_IPS
            declare -a PEER_IDS
            declare -a PEER_COUNTRIES
            declare -a PEER_CITIES
            declare -a PEER_LATS
            declare -a PEER_LONS
            declare -a PEER_DISTANCES
            declare -a PEER_LATENCIES
            declare -a PEER_REGIONS
            
            # Process each peer
            INDEX=0
            while IFS= read -r peer_line; do
                if [ -z "$peer_line" ]; then
                    continue
                fi
                
                # Extract IP and peer ID
                PEER_IP=$(echo "$peer_line" | grep -oP '/ip4/\K[0-9.]+')
                PEER_ID=$(echo "$peer_line" | grep -oP '/p2p/\K[A-Za-z0-9]+')
                
                if [ -z "$PEER_IP" ]; then
                    continue
                fi
                
                # Get geolocation (with rate limiting - small delay)
                sleep 0.15
                GEO_DATA=$(get_geolocation "$PEER_IP")
                
                COUNTRY=$(echo "$GEO_DATA" | cut -d'|' -f1)
                CITY=$(echo "$GEO_DATA" | cut -d'|' -f2)
                LAT=$(echo "$GEO_DATA" | cut -d'|' -f3)
                LON=$(echo "$GEO_DATA" | cut -d'|' -f4)
                
                # Calculate distance from Melbourne
                DISTANCE=$(calculate_distance "$MY_LAT" "$MY_LON" "$LAT" "$LON")
                
                # Test latency
                LATENCY=$(test_ping_latency "$PEER_IP")
                
                # Classify region
                REGION=$(classify_region "$COUNTRY")
                
                # Store data
                PEER_IPS[$INDEX]="$PEER_IP"
                PEER_IDS[$INDEX]="$PEER_ID"
                PEER_COUNTRIES[$INDEX]="$COUNTRY"
                PEER_CITIES[$INDEX]="$CITY"
                PEER_LATS[$INDEX]="$LAT"
                PEER_LONS[$INDEX]="$LON"
                PEER_DISTANCES[$INDEX]="$DISTANCE"
                PEER_LATENCIES[$INDEX]="$LATENCY"
                PEER_REGIONS[$INDEX]="$REGION"
                
                ((INDEX++))
                
                # Limit to 30 peers to avoid excessive API calls
                if [ $INDEX -ge 30 ]; then
                    break
                fi
            done <<< "$PEER_DATA"
            
            TOTAL_ANALYZED=$INDEX
            
            if [ $TOTAL_ANALYZED -gt 0 ]; then
                echo -e "   ${CYAN}📍 Your Location: ${MY_LOCATION}${NC}"
                echo ""
                
                # Calculate regional statistics
                declare -A REGION_COUNTS
                declare -A REGION_LATENCIES
                
                for i in $(seq 0 $((TOTAL_ANALYZED - 1))); do
                    REGION="${PEER_REGIONS[$i]}"
                    LATENCY="${PEER_LATENCIES[$i]}"
                    
                    if [ -z "${REGION_COUNTS[$REGION]}" ]; then
                        REGION_COUNTS[$REGION]=0
                        REGION_LATENCIES[$REGION]=0
                    fi
                    
                    REGION_COUNTS[$REGION]=$((REGION_COUNTS[$REGION] + 1))
                    REGION_LATENCIES[$REGION]=$((REGION_LATENCIES[$REGION] + LATENCY))
                done
                
                # Display regional distribution
                echo -e "   ${CYAN}📊 Geographic Distribution:${NC}"
                for region in "Asia-Pacific" "Europe" "Africa" "Americas" "Other"; do
                    if [ -n "${REGION_COUNTS[$region]}" ] && [ "${REGION_COUNTS[$region]}" -gt 0 ]; then
                        AVG_LAT=$((REGION_LATENCIES[$region] / REGION_COUNTS[$region]))
                        echo -e "   ${CYAN}   • $region: ${REGION_COUNTS[$region]} peers (avg ${AVG_LAT}ms)${NC}"
                    fi
                done
                echo ""
                
                # Sort peers by latency
                declare -a SORTED_INDICES
                for i in $(seq 0 $((TOTAL_ANALYZED - 1))); do
                    SORTED_INDICES[$i]=$i
                done
                
                # Bubble sort by latency
                for i in $(seq 0 $((TOTAL_ANALYZED - 2))); do
                    for j in $(seq $((i + 1)) $((TOTAL_ANALYZED - 1))); do
                        if [ "${PEER_LATENCIES[${SORTED_INDICES[$i]}]}" -gt "${PEER_LATENCIES[${SORTED_INDICES[$j]}]}" ]; then
                            TEMP=${SORTED_INDICES[$i]}
                            SORTED_INDICES[$i]=${SORTED_INDICES[$j]}
                            SORTED_INDICES[$j]=$TEMP
                        fi
                    done
                done
                
                # Show top 5 recommended peers
                echo -e "   ${GREEN}${BOLD}⭐ TOP 5 RECOMMENDED PEERS (Closest to you):${NC}"
                echo ""
                
                DISPLAY_COUNT=5
                if [ $TOTAL_ANALYZED -lt 5 ]; then
                    DISPLAY_COUNT=$TOTAL_ANALYZED
                fi
                
                for rank in $(seq 1 $DISPLAY_COUNT); do
                    idx=${SORTED_INDICES[$((rank - 1))]}
                    IP="${PEER_IPS[$idx]}"
                    PEER_ID="${PEER_IDS[$idx]}"
                    CITY="${PEER_CITIES[$idx]}"
                    COUNTRY="${PEER_COUNTRIES[$idx]}"
                    LATENCY="${PEER_LATENCIES[$idx]}"
                    
                    if [ "$LATENCY" = "999" ]; then
                        LAT_DISPLAY="timeout"
                    else
                        LAT_DISPLAY="${LATENCY}ms"
                    fi
                    
                    echo -e "   ${YELLOW}${rank}.${NC} ${CYAN}${IP}${NC} → ${WHITE}${CITY}, ${COUNTRY}${NC} - ${GREEN}${LAT_DISPLAY}${NC}"
                    echo -e "      ${MAGENTA}Peer ID: ${PEER_ID}${NC}"
                    echo ""
                done
                
                # Generate ready-to-use commands
                echo -e "   ${GREEN}${BOLD}💡 READY-TO-USE COMMANDS FOR YOUR docker-compose.yml:${NC}"
                echo ""
                echo -e "   ${CYAN}Copy these into your NODE_ARGS section:${NC}"
                echo ""
                
                for rank in $(seq 1 $DISPLAY_COUNT); do
                    idx=${SORTED_INDICES[$((rank - 1))]}
                    IP="${PEER_IPS[$idx]}"
                    PEER_ID="${PEER_IDS[$idx]}"
                    LATENCY="${PEER_LATENCIES[$idx]}"
                    
                    # Only show peers with reasonable latency
                    if [ "$LATENCY" != "999" ] && [ "$LATENCY" -lt 500 ]; then
                        echo -e "   ${GREEN}--addpeer=/ip4/${IP}/tcp/18150/p2p/${PEER_ID}${NC}"
                    fi
                done
                
                echo ""
                echo -e "   ${YELLOW}🔄 Then Stop and Start your Node again${NC}"
                echo ""
            else
                echo -e "   ${YELLOW}⚠️  Could not analyze peer locations${NC}"
            fi
        fi
        
        ((NODE_HEALTH_SCORE++))
    else
        echo -e "   ${YELLOW}⚠️  No active peers${NC}"
    fi
    echo ""
    
    # ========================================================================
    # 6. Recent Issues
    # ========================================================================
    echo -e "${BLUE}${BOLD}6. Recent Issues${NC}"
    
    ERROR_COUNT=$(echo "$RECENT_LOGS" | grep -ic "error" || echo "0")
    WARN_COUNT=$(echo "$RECENT_LOGS" | grep -ic "warn" || echo "0")
    
    CRITICAL_ERRORS=$(echo "$RECENT_LOGS" | grep -i "error" | grep -v "liveness probe" | grep -v "no authorization header" | wc -l)
    
    if [ "$CRITICAL_ERRORS" -gt 0 ]; then
        echo -e "   ${YELLOW}⚠️  Found $CRITICAL_ERRORS errors, $WARN_COUNT warnings (in last 500 logs)${NC}"
        
        LAST_ERROR=$(echo "$RECENT_LOGS" | grep -i "error" | grep -v "liveness probe" | grep -v "no authorization header" | tail -1)
        if [ -n "$LAST_ERROR" ]; then
            ERROR_MSG=$(echo "$LAST_ERROR" | cut -c1-80)
            echo -e "   ${CYAN}📝 Last error: $ERROR_MSG...${NC}"
        fi
    else
        echo -e "   ${GREEN}✅ No critical errors in recent logs${NC}"
        ((NODE_HEALTH_SCORE++))
    fi
    echo ""
    
    # Node Summary
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}${BOLD}📋 Node $NODE_NUM Health Score: $NODE_HEALTH_SCORE/6${NC}"
    
    if [ $NODE_HEALTH_SCORE -ge 6 ]; then
        echo -e "${GREEN}${BOLD}✅ Status: HEALTHY${NC}"
        echo -e "${GREEN}   Node is operating normally${NC}"
        ((HEALTHY_NODES++))
    elif [ $NODE_HEALTH_SCORE -ge 4 ]; then
        echo -e "${YELLOW}${BOLD}⚠️  Status: DEGRADED${NC}"
        echo -e "${YELLOW}   Some issues detected, review above${NC}"
    else
        echo -e "${RED}${BOLD}❌ Status: CRITICAL${NC}"
        echo -e "${RED}   Multiple systems failing${NC}"
        ((ERROR_NODES++))
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    ((NODE_NUM++))
done

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}        💎 Check completed successfully! 💎${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
