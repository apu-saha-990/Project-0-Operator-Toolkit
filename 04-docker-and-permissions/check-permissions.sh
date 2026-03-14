#!/bin/bash

# Simple Permission Checker Script
# For BlockDAG Investors Community
# Made By: ArtX

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Welcome banner
clear
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}║         🔐 Permission & Ownership Checker 🔐              ║${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}║         💎 BlockDAG Investors Community 💎                ║${NC}"
echo -e "${CYAN}${BOLD}║                  Made By: ArtX                            ║${NC}"
echo -e "${CYAN}${BOLD}║                                                           ║${NC}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Main loop
while true; do
    # Get path from user
    echo -e "${YELLOW}Enter the path you want to check:${NC}"
    read -p "Path: " TARGET_PATH
    echo ""
    
    # Check if path was provided
    if [ -z "$TARGET_PATH" ]; then
        echo -e "${RED}No path provided. Exiting...${NC}"
        echo ""
        exit 0
    fi
    
    # Expand tilde if present
    TARGET_PATH="${TARGET_PATH/#\~/$HOME}"
    
    # Check if path exists
    if [ ! -e "$TARGET_PATH" ]; then
        echo -e "${RED}❌ Path does not exist: ${TARGET_PATH}${NC}"
        echo ""
        read -p "$(echo -e ${CYAN}Check another path? \(Y/n\): ${NC})" CONTINUE
        CONTINUE=${CONTINUE:-Y}
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${GREEN}Thank you for using the checker!${NC}"
            echo ""
            exit 0
        fi
        echo ""
        continue
    fi
    
    echo -e "${GREEN}✅ Path exists: ${TARGET_PATH}${NC}"
    echo ""
    
    # Get owner and group
    OWNER=$(stat -c '%U' "$TARGET_PATH" 2>/dev/null)
    GROUP=$(stat -c '%G' "$TARGET_PATH" 2>/dev/null)
    CURRENT_USER=$(whoami)
    
    echo -e "${CYAN}${BOLD}Ownership Information:${NC}"
    echo -e "  Owner: ${YELLOW}${OWNER}${NC}"
    echo -e "  Group: ${YELLOW}${GROUP}${NC}"
    echo ""
    
    # Check permissions for current user
    echo -e "${CYAN}${BOLD}Access Check for Current User (${CURRENT_USER}):${NC}"
    
    CAN_READ=false
    CAN_WRITE=false
    CAN_EXECUTE=false
    
    # Test read
    if [ -r "$TARGET_PATH" ]; then
        echo -e "  ${GREEN}✅ Can Read${NC}"
        CAN_READ=true
    else
        echo -e "  ${RED}❌ Cannot Read${NC}"
    fi
    
    # Test write
    if [ -w "$TARGET_PATH" ]; then
        echo -e "  ${GREEN}✅ Can Write${NC}"
        CAN_WRITE=true
    else
        echo -e "  ${RED}❌ Cannot Write${NC}"
    fi
    
    # Test execute
    if [ -x "$TARGET_PATH" ]; then
        echo -e "  ${GREEN}✅ Can Execute${NC}"
        CAN_EXECUTE=true
    else
        echo -e "  ${RED}❌ Cannot Execute${NC}"
    fi
    
    echo ""
    
    # Summary message
    if [ "$OWNER" = "$CURRENT_USER" ]; then
        if $CAN_READ && $CAN_WRITE && $CAN_EXECUTE; then
            echo -e "${GREEN}${BOLD}✅ This folder is owned by you (${CURRENT_USER}) and you have full access!${NC}"
        elif $CAN_READ && $CAN_WRITE; then
            echo -e "${YELLOW}${BOLD}⚠️  This folder is owned by you (${CURRENT_USER}) but you cannot execute/enter it.${NC}"
        else
            echo -e "${YELLOW}${BOLD}⚠️  This folder is owned by you (${CURRENT_USER}) but has limited access.${NC}"
        fi
    elif [ "$OWNER" = "root" ]; then
        echo -e "${RED}${BOLD}⚠️  This folder is owned by ROOT.${NC}"
        echo -e "${YELLOW}You may need to use 'sudo' for full access.${NC}"
    else
        echo -e "${YELLOW}${BOLD}⚠️  This folder is owned by a different user (${OWNER}).${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Ask to check another path
    read -p "$(echo -e ${CYAN}Check another path? \(Y/n\): ${NC})" CONTINUE
    CONTINUE=${CONTINUE:-Y}
    
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${GREEN}${BOLD}Thank you for using the checker!${NC}"
        echo ""
        exit 0
    fi
    
    echo ""
done
