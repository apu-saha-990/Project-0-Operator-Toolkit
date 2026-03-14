#!/bin/bash

# =========================================================================
# 🔄 BLOCKDAG REVERSE OPTIMIZER v1.1
# =========================================================================
# Made By: ArtX for BlockDAG Investors Group
# Version: 1.1
# Purpose: Restore all original settings before optimization
# Completely reverses all changes made by the optimizer script
#
# Features:
# - Automatically finds OLDEST backup (true original settings)
# - Restores ALL optimizations to original state
# - Deletes all backup directories after successful restore
# - Handles multiple backups intelligently
# =========================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Emoji support
CHECK="✅"
CROSS="❌"
UNDO="🔄"
TRASH="🗑️"
WARNING="⚠️"
INFO="ℹ️"
SAVE="💾"
LOCK="🔒"

# Global variables
BACKUP_DIR=""
RESTORED_COUNT=0
FAILED_COUNT=0

# =========================================================================
# SUDO MANAGEMENT (Modern with auto-cleanup)
# =========================================================================

# Cleanup function
cleanup() {
    # Kill keep-alive process if running
    if [ ! -z "$SUDO_KEEPER_PID" ]; then
        kill $SUDO_KEEPER_PID 2>/dev/null
    fi
    # Clear sudo cache
    sudo -k
    echo ""
    echo -e "${LOCK} ${GREEN}Sudo cache cleared${NC}"
}

# Setup sudo with keep-alive
setup_sudo() {
    # If not root, auto-elevate
    if [ "$EUID" -ne 0 ]; then
        echo -e "${LOCK} ${CYAN}Requesting admin privileges...${NC}"
        sudo "$0" "$@"
        exit $?
    fi
    
    # Start sudo session
    sudo -v
    
    # Background process to keep sudo alive
    while true; do 
        sudo -n true
        sleep 50
        kill -0 "$$" || exit
    done 2>/dev/null &
    SUDO_KEEPER_PID=$!
    
    # Register cleanup on exit (works for normal exit, CTRL+C, errors)
    trap cleanup EXIT
}

# =========================================================================
# HELPER FUNCTIONS
# =========================================================================

print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║         🔄 BLOCKDAG REVERSE OPTIMIZER v1.1                   ║"
    echo "║                                                               ║"
    echo "║       Made By ArtX for BlockDAG Investors Group              ║"
    echo "║                                                               ║"
    echo "║          Restore All Original Settings                       ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_step() {
    echo -e "\n${BLUE}${BOLD}[STEP $1]${NC} ${CYAN}$2${NC}"
    echo "─────────────────────────────────────────────────────────────"
}

print_info() {
    echo -e "${CYAN}${INFO} $1${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

print_error() {
    echo -e "${RED}${CROSS} $1${NC}"
}

# =========================================================================
# FIND BACKUP DIRECTORY
# =========================================================================

find_backup() {
    print_step "1" "Locating Backup Directory..."
    
    # Find ALL backups
    BACKUP_COUNT=$(ls -d /root/blockdag_optimizer_backup_* 2>/dev/null | wc -l)
    
    if [ $BACKUP_COUNT -eq 0 ]; then
        print_error "No backup directory found!"
        echo ""
        echo -e "${YELLOW}Expected location: ${BOLD}/root/blockdag_optimizer_backup_*${NC}"
        echo -e "${YELLOW}This script can only restore if you have backups.${NC}"
        echo ""
        exit 1
    fi
    
    # Use OLDEST backup (contains true original settings)
    BACKUP_DIR=$(ls -td /root/blockdag_optimizer_backup_* 2>/dev/null | tail -1)
    
    print_success "Found $BACKUP_COUNT backup(s)"
    
    if [ $BACKUP_COUNT -gt 1 ]; then
        print_warning "Multiple backups detected!"
        print_info "Using OLDEST backup (contains original settings):"
        echo ""
        ls -td /root/blockdag_optimizer_backup_* 2>/dev/null | nl
        echo ""
        print_info "Selected: $(basename $BACKUP_DIR)"
        echo ""
        echo -e "${CYAN}${INFO} Why oldest? The first backup contains your true original${NC}"
        echo -e "${CYAN}   settings before any optimization. Newer backups may${NC}"
        echo -e "${CYAN}   contain already-optimized settings.${NC}"
        echo ""
    else
        print_success "Using backup: $BACKUP_DIR"
    fi
    
    # Show backup info
    BACKUP_DATE=$(basename "$BACKUP_DIR" | sed 's/blockdag_optimizer_backup_//')
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    
    print_info "Backup date: $BACKUP_DATE"
    print_info "Backup size: $BACKUP_SIZE"
    
    # List files in backup
    echo ""
    echo -e "${CYAN}Files in backup:${NC}"
    ls -lh "$BACKUP_DIR" | tail -n +2 | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    
    sleep 2
}

# =========================================================================
# RESTORE FUNCTIONS
# =========================================================================

restore_swappiness() {
    print_step "2" "Restoring Swappiness..."
    
    if [ -f "$BACKUP_DIR/swappiness.backup" ]; then
        ORIGINAL_SWAP=$(cat "$BACKUP_DIR/swappiness.backup")
        CURRENT_SWAP=$(cat /proc/sys/vm/swappiness)
        
        print_info "Current: $CURRENT_SWAP"
        print_info "Restoring to: $ORIGINAL_SWAP"
        
        # Restore runtime
        sysctl vm.swappiness=$ORIGINAL_SWAP > /dev/null 2>&1
        
        # Restore in sysctl.conf
        if grep -q "vm.swappiness" /etc/sysctl.conf; then
            sed -i "s/vm.swappiness=.*/vm.swappiness=$ORIGINAL_SWAP/" /etc/sysctl.conf
        else
            echo "vm.swappiness=$ORIGINAL_SWAP" >> /etc/sysctl.conf
        fi
        
        print_success "Swappiness restored: $CURRENT_SWAP → $ORIGINAL_SWAP"
        ((RESTORED_COUNT++))
    else
        print_warning "No swappiness backup found, skipping"
        ((FAILED_COUNT++))
    fi
    
    sleep 1
}

restore_sysctl() {
    print_step "3" "Restoring Kernel Parameters..."
    
    if [ -f "$BACKUP_DIR/sysctl.conf.backup" ]; then
        print_info "Restoring /etc/sysctl.conf"
        
        cp "$BACKUP_DIR/sysctl.conf.backup" /etc/sysctl.conf
        sysctl -p > /dev/null 2>&1
        
        print_success "Kernel parameters restored"
        ((RESTORED_COUNT++))
    else
        print_warning "No sysctl.conf backup found, skipping"
        ((FAILED_COUNT++))
    fi
    
    sleep 1
}

restore_limits() {
    print_step "4" "Restoring File Limits..."
    
    if [ -f "$BACKUP_DIR/limits.conf.backup" ]; then
        print_info "Restoring /etc/security/limits.conf"
        
        cp "$BACKUP_DIR/limits.conf.backup" /etc/security/limits.conf
        
        print_success "File limits restored"
        ((RESTORED_COUNT++))
    else
        print_warning "No limits.conf backup found, skipping"
        ((FAILED_COUNT++))
    fi
    
    # Remove SystemD limit overrides
    print_info "Removing SystemD limit overrides..."
    
    if [ -f /etc/systemd/user.conf.d/50-file-limits.conf ]; then
        rm -f /etc/systemd/user.conf.d/50-file-limits.conf
        print_success "Removed user SystemD limits"
    fi
    
    if [ -f /etc/systemd/system.conf.d/50-file-limits.conf ]; then
        rm -f /etc/systemd/system.conf.d/50-file-limits.conf
        print_success "Removed system SystemD limits"
    fi
    
    # Reload systemd
    systemctl daemon-reexec > /dev/null 2>&1
    
    sleep 1
}

restore_docker() {
    print_step "5" "Restoring Docker Configuration..."
    
    if [ -f "$BACKUP_DIR/daemon.json.backup" ]; then
        print_info "Restoring /etc/docker/daemon.json"
        
        cp "$BACKUP_DIR/daemon.json.backup" /etc/docker/daemon.json
        
        # Restart docker if running
        if systemctl is-active --quiet docker; then
            systemctl restart docker > /dev/null 2>&1
            print_success "Docker configuration restored and restarted"
        else
            print_success "Docker configuration restored"
        fi
        
        ((RESTORED_COUNT++))
    else
        print_info "No Docker backup found (may not have been installed)"
    fi
    
    sleep 1
}

restore_journald() {
    print_step "6" "Restoring Journal Configuration..."
    
    if [ -f "$BACKUP_DIR/journald.conf.backup" ]; then
        print_info "Restoring /etc/systemd/journald.conf"
        
        cp "$BACKUP_DIR/journald.conf.backup" /etc/systemd/journald.conf
        systemctl restart systemd-journald > /dev/null 2>&1
        
        print_success "Journal configuration restored"
        ((RESTORED_COUNT++))
    else
        print_warning "No journald.conf backup found, skipping"
        ((FAILED_COUNT++))
    fi
    
    sleep 1
}

restore_io_scheduler() {
    print_step "7" "Restoring I/O Scheduler..."
    
    print_info "Removing custom I/O scheduler rules..."
    
    if [ -f /etc/udev/rules.d/60-ioschedulers.rules ]; then
        rm -f /etc/udev/rules.d/60-ioschedulers.rules
        udevadm control --reload-rules > /dev/null 2>&1
        print_success "Custom I/O scheduler rules removed"
        ((RESTORED_COUNT++))
    else
        print_info "No custom I/O rules to remove"
    fi
    
    sleep 1
}

restore_cpu_governor() {
    print_step "8" "Restoring CPU Governor..."
    
    print_info "Removing performance governor setting..."
    
    if [ -f /etc/default/cpufrequtils ]; then
        rm -f /etc/default/cpufrequtils
        print_success "CPU governor settings removed (will use default)"
        ((RESTORED_COUNT++))
    else
        print_info "No CPU governor config to remove"
    fi
    
    sleep 1
}

restore_cron_jobs() {
    print_step "9" "Removing Maintenance Cron Jobs..."
    
    print_info "Removing BlockDAG maintenance tasks..."
    
    # Remove weekly maintenance cron
    if [ -f /etc/cron.weekly/blockdag-maintenance ]; then
        rm -f /etc/cron.weekly/blockdag-maintenance
        print_success "Weekly maintenance cron removed"
        ((RESTORED_COUNT++))
    else
        print_info "No maintenance cron to remove"
    fi
    
    sleep 1
}

reenable_services() {
    print_step "10" "Re-enabling Disabled Services..."
    
    print_info "Checking for disabled services..."
    
    # Re-enable CUPS if it was disabled
    if systemctl is-enabled cups.service 2>/dev/null | grep -q "disabled"; then
        systemctl enable cups.service > /dev/null 2>&1
        systemctl start cups.service > /dev/null 2>&1
        print_success "Re-enabled CUPS (printing service)"
        ((RESTORED_COUNT++))
    fi
    
    # Re-enable ModemManager if it was disabled
    if systemctl is-enabled ModemManager.service 2>/dev/null | grep -q "disabled"; then
        systemctl enable ModemManager.service > /dev/null 2>&1
        systemctl start ModemManager.service > /dev/null 2>&1
        print_success "Re-enabled ModemManager"
        ((RESTORED_COUNT++))
    fi
    
    # Re-enable apport if it was disabled
    if systemctl is-enabled apport.service 2>/dev/null | grep -q "disabled"; then
        systemctl enable apport.service > /dev/null 2>&1
        print_success "Re-enabled apport (crash reporting)"
        ((RESTORED_COUNT++))
    fi
    
    # Re-enable whoopsie if it was disabled
    if systemctl is-enabled whoopsie.service 2>/dev/null | grep -q "disabled"; then
        systemctl enable whoopsie.service > /dev/null 2>&1
        print_success "Re-enabled whoopsie (error reporting)"
        ((RESTORED_COUNT++))
    fi
    
    if [ $RESTORED_COUNT -eq 0 ]; then
        print_info "No services needed re-enabling"
    fi
    
    sleep 1
}

remove_temp_cleanup() {
    print_step "11" "Removing Temp Cleanup Script..."
    
    if [ -f /usr/local/bin/cleanup-temp-files.sh ]; then
        rm -f /usr/local/bin/cleanup-temp-files.sh
        print_success "Temp cleanup script removed"
        ((RESTORED_COUNT++))
    else
        print_info "No temp cleanup script to remove"
    fi
    
    sleep 1
}

delete_backup() {
    print_step "12" "Deleting Backup Directory..."
    
    # Count all backups
    ALL_BACKUPS=$(ls -d /root/blockdag_optimizer_backup_* 2>/dev/null)
    BACKUP_COUNT=$(echo "$ALL_BACKUPS" | wc -l)
    TOTAL_SIZE=$(du -sh /root/blockdag_optimizer_backup_* 2>/dev/null | awk '{sum+=$1} END {print sum}')
    
    if [ $BACKUP_COUNT -gt 1 ]; then
        echo -e "${YELLOW}${WARNING} Found $BACKUP_COUNT backup directories:${NC}"
        echo ""
        ls -td /root/blockdag_optimizer_backup_* 2>/dev/null | nl
        echo ""
        echo -e "${CYAN}${INFO} All backups will be deleted (system now restored to original)${NC}"
        echo ""
    else
        echo -e "${YELLOW}${WARNING} This will permanently delete the backup files.${NC}"
        echo -e "${CYAN}Backup location: ${BOLD}$BACKUP_DIR${NC}"
        echo ""
    fi
    
    read -p "Delete all backups now? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Delete all backup directories
        rm -rf /root/blockdag_optimizer_backup_* 2>/dev/null
        print_success "All backup directories deleted"
        print_info "Freed up space"
    else
        print_info "Backups kept in /root/"
        print_info "You can manually delete them later with:"
        echo -e "${CYAN}  sudo rm -rf /root/blockdag_optimizer_backup_*${NC}"
    fi
    
    sleep 1
}

# =========================================================================
# SUMMARY
# =========================================================================

show_summary() {
    print_step "13" "${UNDO} RESTORATION COMPLETE! ${UNDO}"
    
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                    RESTORATION SUMMARY                        ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CHECK} ${GREEN}Successfully restored: ${BOLD}$RESTORED_COUNT${NC} ${GREEN}settings${NC}"
    
    if [ $FAILED_COUNT -gt 0 ]; then
        echo -e "${WARNING} ${YELLOW}Skipped (no backup): ${BOLD}$FAILED_COUNT${NC} ${YELLOW}settings${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                    WHAT WAS RESTORED                          ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${UNDO} Swappiness (memory management)"
    echo -e "${UNDO} Kernel parameters (system tuning)"
    echo -e "${UNDO} File limits (connection limits)"
    echo -e "${UNDO} SystemD limits (persistent limits)"
    echo -e "${UNDO} I/O scheduler (disk performance)"
    echo -e "${UNDO} CPU governor (power management)"
    echo -e "${UNDO} Docker configuration (if present)"
    echo -e "${UNDO} Journal configuration (logging)"
    echo -e "${UNDO} Disabled services (re-enabled)"
    echo -e "${UNDO} Maintenance cron jobs (removed)"
    echo -e "${UNDO} Temp cleanup scripts (removed)"
    echo ""
    
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                    IMPORTANT NOTES                            ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WARNING} ${YELLOW}Your system is now back to its original state${NC}"
    echo -e "${INFO} ${CYAN}All performance optimizations have been removed${NC}"
    echo -e "${INFO} ${CYAN}Your system will run with default Linux settings${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                    NEXT STEPS                                 ║${NC}"
    echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} ${BOLD}Reboot your system${NC} to fully apply all changes:"
    echo -e "   ${CYAN}sudo reboot${NC}"
    echo ""
    echo -e "${YELLOW}2.${NC} After reboot, verify restoration:"
    echo -e "   ${CYAN}cat /proc/sys/vm/swappiness${NC}     # Should be 60 (default)"
    echo -e "   ${CYAN}ulimit -n${NC}                        # Should be 1024 (default)"
    echo ""
    echo -e "${YELLOW}3.${NC} If you want to re-optimize later:"
    echo -e "   Run the optimizer script again: ${CYAN}./blockdag_optimizer_v1.1.sh${NC}"
    echo ""
    
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}${BOLD}           Made by ArtX for BlockDAG Investors Group${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# =========================================================================
# MAIN EXECUTION
# =========================================================================

main() {
    # Setup modern sudo with auto-cleanup
    setup_sudo "$@"
    
    print_header
    
    echo -e "${YELLOW}${BOLD}${WARNING} WARNING: This will restore ALL original settings${NC}"
    echo -e "${CYAN}All optimizations will be removed and your system will return${NC}"
    echo -e "${CYAN}to its state before running the optimizer.${NC}"
    echo ""
    echo -e "${RED}${BOLD}This includes:${NC}"
    echo "  • Memory/swap settings"
    echo "  • CPU performance mode"
    echo "  • Disk I/O optimization"
    echo "  • Network optimization (BBR)"
    echo "  • File limits (connection capacity)"
    echo "  • All automatic maintenance"
    echo ""
    echo -e "${GREEN}✅ Safe: Uses your backup files to restore${NC}"
    echo -e "${GREEN}✅ Reversible: You can re-run optimizer anytime${NC}"
    echo ""
    read -p "Continue with restoration? (y/n): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Restoration cancelled by user${NC}"
        exit 0
    fi
    
    echo ""
    print_info "Starting restoration process..."
    sleep 2
    
    # Find and validate backup
    find_backup
    
    # Restore all settings
    restore_swappiness
    restore_sysctl
    restore_limits
    restore_docker
    restore_journald
    restore_io_scheduler
    restore_cpu_governor
    restore_cron_jobs
    reenable_services
    remove_temp_cleanup
    
    # Delete backup
    delete_backup
    
    # Show summary
    show_summary
    
    # Ask for reboot
    echo ""
    read -p "Reboot now to complete restoration? (recommended) [Y/n]: " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo -e "${GREEN}Rebooting in 5 seconds...${NC}"
        sleep 5
        reboot
    else
        echo -e "${YELLOW}Please reboot manually when ready: ${BOLD}sudo reboot${NC}"
    fi
}

# Run main function
main "$@"
