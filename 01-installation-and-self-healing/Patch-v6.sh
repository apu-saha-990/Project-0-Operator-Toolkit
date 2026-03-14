#!/bin/bash

# ============================================================================
# BlockDAG v6 → v6.1 Stop Command Patch
# Fixes Node 1 stop command to only stop Node 1 (not all nodes)
# For BlockDAG Investors Community
# Created By: ArtX
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}║      🔧 BlockDAG v6 → v6.1 Stop Command Patch 🔧        ║${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}║         💎 BlockDAG Investors Community 💎                ║${NC}"
echo -e "${CYAN}${BOLD}║                  Created By: ArtX                         ║${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}${BOLD}What does this patch fix?${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}In v6, Node 1's stop command stops ALL nodes instead of just Node 1.${NC}"
echo -e "${WHITE}This patch fixes that issue.${NC}"
echo ""
echo -e "${CYAN}📋 Affected: Node 1 only${NC}"
echo -e "${GREEN}✅ Not affected: Node 2, 3, 4+ (already working correctly)${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if Node 1 exists
NODE1_PATH="$HOME/Node1/blockdag-scripts"

if [ ! -d "$NODE1_PATH" ]; then
    echo -e "${YELLOW}⚠️  Node1 directory not found at: $NODE1_PATH${NC}"
    echo ""
    read -p "📂 Enter your Node1 blockdag-scripts path (or press Enter to exit): " CUSTOM_PATH
    echo ""
    
    if [ -z "$CUSTOM_PATH" ]; then
        echo -e "${RED}❌ No path provided. Exiting.${NC}"
        exit 0
    fi
    
    # Expand tilde
    CUSTOM_PATH="${CUSTOM_PATH/#\~/$HOME}"
    
    if [ ! -d "$CUSTOM_PATH" ]; then
        echo -e "${RED}❌ Path does not exist: $CUSTOM_PATH${NC}"
        exit 1
    fi
    
    NODE1_PATH="$CUSTOM_PATH"
fi

COMMAND_FILE="$NODE1_PATH/node1-commands.txt"

# Check if command file exists
if [ ! -f "$COMMAND_FILE" ]; then
    echo -e "${RED}❌ node1-commands.txt not found at: $COMMAND_FILE${NC}"
    echo ""
    echo -e "${YELLOW}This script can only patch Node 1 installed with v6.${NC}"
    echo -e "${BLUE}If you installed Node 1 with an older version, no patch needed.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found Node 1 commands file:${NC}"
echo -e "   ${CYAN}$COMMAND_FILE${NC}"
echo ""

# Check if already patched
if grep -q 'name=\^blockdag-(miner|full|relay)-testnet\$' "$COMMAND_FILE"; then
    echo -e "${GREEN}${BOLD}✅ Node 1 is already patched to v6.1!${NC}"
    echo -e "${BLUE}No action needed. Your stop command is working correctly.${NC}"
    echo ""
    exit 0
fi

# Show current vs new command
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}${BOLD}❌ CURRENT (v6 - BROKEN):${NC}"
echo -e '   docker stop $(docker ps -q --filter "name=blockdag-.*-testnet")'
echo ""
echo -e "${GREEN}${BOLD}✅ NEW (v6.1 - FIXED):${NC}"
echo -e '   docker stop $(docker ps -q --filter "name=^blockdag-(miner|full|relay)-testnet$")'
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "🔧 Apply this patch? (Y/n): " CONFIRM
CONFIRM=${CONFIRM:-Y}

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️  Patch cancelled by user.${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}🔧 Applying patch...${NC}"

# Create backup
BACKUP_FILE="${COMMAND_FILE}.v6-backup-$(date +%Y%m%d_%H%M%S)"
cp "$COMMAND_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup created: $(basename $BACKUP_FILE)${NC}"

# Apply the fix - Fix STOP command
sed -i 's/name=blockdag-\.\*-testnet"/name=^blockdag-(miner|full|relay)-testnet$"/g' "$COMMAND_FILE"

# Also fix LOGS command (same issue)
sed -i 's/name=blockdag-\.\*-testnet"/name=^blockdag-(miner|full|relay)-testnet$"/g' "$COMMAND_FILE"

echo -e "${GREEN}✅ Stop command patched${NC}"
echo -e "${GREEN}✅ Logs command patched${NC}"
echo ""

# Verify the patch
if grep -q 'name=\^blockdag-(miner|full|relay)-testnet\$' "$COMMAND_FILE"; then
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}✅ PATCH APPLIED SUCCESSFULLY!${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}📋 Summary:${NC}"
    echo -e "   ${CYAN}• Node 1 stop command now only stops Node 1${NC}"
    echo -e "   ${CYAN}• Node 1 logs command now only shows Node 1 logs${NC}"
    echo -e "   ${CYAN}• Backup saved: $(basename $BACKUP_FILE)${NC}"
    echo ""
    echo -e "${GREEN}You can now use the stop command safely!${NC}"
    echo ""
    echo -e "${YELLOW}💡 Test it:${NC}"
    echo -e "   ${WHITE}cd $NODE1_PATH${NC}"
    echo -e "   ${WHITE}# Check the updated commands in node1-commands.txt${NC}"
    echo ""
else
    echo -e "${RED}${BOLD}❌ PATCH FAILED!${NC}"
    echo -e "${YELLOW}Restoring from backup...${NC}"
    cp "$BACKUP_FILE" "$COMMAND_FILE"
    echo -e "${GREEN}✅ Restored original file${NC}"
    echo ""
    echo -e "${RED}Please report this issue to ArtX on Discord.${NC}"
    exit 1
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}        💎 Thank you for using BlockDAG Tools! 💎${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
