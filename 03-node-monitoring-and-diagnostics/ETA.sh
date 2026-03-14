#!/bin/bash

# ============================================================================
# BlockDAG Multi-Node Sync ETA Calculator
# Measures block speed by checking RPC twice, calculates ETA
# Auto-detects Docker Compose and standalone Docker nodes
# Works for multiple nodes and community users
# Created By: ArtX (Refactored)
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Format number with commas
format_number() {
    printf "%'d" "$1" 2>/dev/null || echo "$1"
}

# Hex to decimal
hex_to_dec() {
    local hex=$1
    echo $((16#${hex#0x}))
}

# Detect Docker command
DOCKER_CMD="docker"
if ! docker ps &>/dev/null 2>&1; then
    if sudo docker ps &>/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    else
        echo -e "${RED}❌ Cannot access Docker${NC}"
        exit 1
    fi
fi

# Detect all BlockDAG nodes
detect_nodes() {
    # Try Docker Compose
    COMPOSE_SERVICES=$(docker-compose ps --services 2>/dev/null | grep -i blockdag)
    if [[ -n "$COMPOSE_SERVICES" ]]; then
        echo "$COMPOSE_SERVICES"
        return
    fi

    # Fallback: standalone Docker
    docker ps --format "{{.Names}}" | grep -i blockdag
}

NODES=($(detect_nodes))

if [ "${#NODES[@]}" -eq 0 ]; then
    echo -e "${RED}❌ No BlockDAG nodes detected${NC}"
    exit 1
fi

echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${BOLD}        ⏱️  BlockDAG Multi-Node Sync ETA Calculator${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${BOLD}          🔥  BlockDAG Investors Group  🔥${NC}"
echo -e "${CYAN}${BOLD}                 📝 By - ArtX 📝${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Function to get current block from RPC
get_current_block() {
    local container="$1"
    local http_port=$($DOCKER_CMD port "$container" 18545 2>/dev/null | cut -d':' -f2 | head -1)
    http_port=${http_port:-18545}

    local rpc_response=$(curl -s -m 5 -X POST http://localhost:$http_port \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null)

    if echo "$rpc_response" | grep -q "result"; then
        local block_hex=$(echo "$rpc_response" | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
        hex_to_dec "$block_hex"
    else
        echo "0"
    fi
}

# Loop through all detected nodes
for CONTAINER in "${NODES[@]}"; do
    echo -e "${CYAN}🔍 Checking node: $CONTAINER${NC}"

    # Get target block from logs
    TARGET_BLOCK=$($DOCKER_CMD logs "$CONTAINER" 2>&1 | grep "Syncing graph state" | tail -1 | grep -oP 'target=\(\K[0-9,]+' | head -1 | sed 's/,.*//' | tr -d ',')

    if [ -z "$TARGET_BLOCK" ] || [ "$TARGET_BLOCK" -eq 0 ]; then
        echo -e "${RED}❌ Could not find target block for $CONTAINER${NC}"
        continue
    fi

    echo -e "${GREEN}✅ Network Block: $(format_number $TARGET_BLOCK)${NC}"
    echo ""

    # First block reading
    echo -e "${CYAN}📊 Measuring sync speed for $CONTAINER...${NC}"
    echo -e "${YELLOW}   Reading block #1...${NC}"
    BLOCK1=$(get_current_block "$CONTAINER")

    if [ "$BLOCK1" -eq 0 ]; then
        echo -e "${RED}❌ Could not read current block from RPC for $CONTAINER${NC}"
        continue
    fi

    echo -e "${GREEN}   Block: $(format_number $BLOCK1)${NC}"
    echo ""

    # Wait 10 seconds
    echo -e "${YELLOW}   ⏳ Waiting 10 seconds...${NC}"
    for i in {10..1}; do
        echo -ne "\r   ${CYAN}   $i seconds remaining...${NC}"
        sleep 1
    done
    echo -ne "\r${GREEN}   ✅ Done!                    ${NC}\n"
    echo ""

    # Second block reading
    echo -e "${YELLOW}   Reading block #2...${NC}"
    BLOCK2=$(get_current_block "$CONTAINER")

    if [ "$BLOCK2" -eq 0 ]; then
        echo -e "${RED}❌ Could not read current block from RPC for $CONTAINER${NC}"
        continue
    fi

    echo -e "${GREEN}   Block: $(format_number $BLOCK2)${NC}"
    echo ""

    # Calculate speed
    BLOCKS_IN_10_SEC=$((BLOCK2 - BLOCK1))

    if [ "$BLOCKS_IN_10_SEC" -le 0 ]; then
        echo -e "${RED}❌ No blocks synced in last 10 seconds for $CONTAINER${NC}"
        echo -e "${YELLOW}   Your node might be stuck or fully synced${NC}"
        continue
    fi

    BLOCKS_PER_SECOND=$((BLOCKS_IN_10_SEC / 10))
    BLOCKS_PER_MINUTE=$((BLOCKS_IN_10_SEC * 6))
    BLOCKS_PER_HOUR=$((BLOCKS_IN_10_SEC * 360))

    REMAINING=$((TARGET_BLOCK - BLOCK2))

    if [ "$REMAINING" -le 0 ]; then
        echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}${BOLD}        🎉 $CONTAINER FULLY SYNCED! 🎉${NC}"
        echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        continue
    fi

    PROGRESS=$((BLOCK2 * 100 / TARGET_BLOCK))

    # Calculate ETA
    SECONDS_LEFT=$((REMAINING / BLOCKS_PER_SECOND))
    MINUTES_LEFT=$((SECONDS_LEFT / 60))
    HOURS_LEFT=$((MINUTES_LEFT / 60))
    DAYS_LEFT=$((HOURS_LEFT / 24))
    HOURS_REMAINDER=$((HOURS_LEFT % 24))
    MINUTES_REMAINDER=$((MINUTES_LEFT % 60))

    # Display results
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}        📊 SYNC STATUS & ETA for $CONTAINER${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${CYAN}📦 Current Block:  ${BOLD}$(format_number $BLOCK2)${NC}"
    echo -e "${CYAN}🎯 Network Block:  ${BOLD}$(format_number $TARGET_BLOCK)${NC}"
    echo -e "${YELLOW}📊 Blocks Behind:  ${BOLD}$(format_number $REMAINING)${NC}"
    echo -e "${MAGENTA}📈 Progress:       ${BOLD}${PROGRESS}%${NC}"
    echo ""

    echo -e "${GREEN}${BOLD}⚡ SYNC SPEED:${NC}"
    echo -e "${GREEN}   • $(format_number $BLOCKS_IN_10_SEC) blocks in 10 seconds${NC}"
    echo -e "${GREEN}   • ~$(format_number $BLOCKS_PER_SECOND) blocks/second${NC}"
    echo -e "${GREEN}   • ~$(format_number $BLOCKS_PER_MINUTE) blocks/minute${NC}"
    echo -e "${GREEN}   • ~$(format_number $BLOCKS_PER_HOUR) blocks/hour${NC}"
    echo ""

    echo -e "${MAGENTA}${BOLD}⏰ TIME TO FULL SYNC:${NC}"

    if [ "$DAYS_LEFT" -gt 0 ]; then
        echo -e "${MAGENTA}   ${BOLD}~${DAYS_LEFT} days ${HOURS_REMAINDER} hours${NC}"
    elif [ "$HOURS_LEFT" -gt 0 ]; then
        echo -e "${MAGENTA}   ${BOLD}~${HOURS_LEFT} hours ${MINUTES_REMAINDER} minutes${NC}"
    elif [ "$MINUTES_LEFT" -gt 0 ]; then
        echo -e "${MAGENTA}   ${BOLD}~${MINUTES_LEFT} minutes${NC}"
    else
        echo -e "${MAGENTA}   ${BOLD}Less than a minute!${NC}"
    fi

    echo ""
done

echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${BOLD}        ✅ All nodes processed${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

