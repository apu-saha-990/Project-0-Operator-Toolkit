#!/bin/bash

#############################################
# BlockDAG Node Backup Script
# Sequential backup with enhanced security and reliability
# By ArtX
#############################################

set -e

#############################################
# ⚙️ USER CONFIGURATION - EDIT THIS!
#############################################

# 📦 BACKUP RETENTION POLICY
# How many backups to keep per node?
# 
# Examples:
#   1 = Keep only the latest backup (saves space)
#   2 = Keep last 2 backups
#   3 = Keep last 3 backups
#   5 = Keep last 5 backups
#   0 = Keep ALL backups forever (never auto-delete)
#
# ⚠️  Warning: More backups = more disk space needed!
#
MAX_BACKUPS_TO_KEEP=1

#############################################
# SYSTEM CONFIGURATION - DO NOT EDIT
#############################################

# Configuration
CONFIG_FILE="$HOME/.node-backup-config.json"
PYTHON_HELPER="/tmp/backup-json-helper-$$.py"
SUDOERS_FILE="/etc/sudoers.d/node-backup"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Detect mode
if [[ "$1" == "--cron" ]] || [[ "$1" == "--auto" ]]; then
    MODE="automated"
else
    MODE="interactive"
fi

#############################################
# PYTHON HELPER SCRIPT
#############################################

create_python_helper() {
    cat > "$PYTHON_HELPER" << 'PYTHON_EOF'
#!/usr/bin/env python3
import json
import sys

def main():
    if len(sys.argv) < 3:
        print("Usage: script.py <config_file> <operation> [args...]", file=sys.stderr)
        sys.exit(1)
    
    config_file = sys.argv[1]
    operation = sys.argv[2]
    
    try:
        with open(config_file, 'r') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"Config file not found: {config_file}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)
    
    if operation == "get_webhook":
        print(data.get('discord_webhook_url', ''))
    elif operation == "get_backup_path":
        print(data.get('backup_path', ''))
    elif operation == "get_node_count":
        print(len(data.get('nodes', [])))
    elif operation == "get_node_field":
        if len(sys.argv) < 5:
            print("Usage: get_node_field <index> <field>", file=sys.stderr)
            sys.exit(1)
        index = int(sys.argv[3])
        field = sys.argv[4]
        nodes = data.get('nodes', [])
        if index < len(nodes):
            print(nodes[index].get(field, ''))
        else:
            print('', file=sys.stderr)
    elif operation == "validate":
        required = ['nodes', 'backup_path']
        for key in required:
            if key not in data:
                print(f"Missing required key: {key}", file=sys.stderr)
                sys.exit(1)
        print("valid")
    elif operation == "add_nodes":
        if len(sys.argv) < 4:
            print("Usage: add_nodes <nodes_json>", file=sys.stderr)
            sys.exit(1)
        new_nodes_json = sys.argv[3]
        new_nodes = json.loads(new_nodes_json)
        data['nodes'].extend(new_nodes)
        with open(config_file, 'w') as f:
            json.dump(data, f, indent=2)
        print("success")
    elif operation == "remove_node":
        if len(sys.argv) < 4:
            print("Usage: remove_node <index>", file=sys.stderr)
            sys.exit(1)
        index = int(sys.argv[3])
        nodes = data.get('nodes', [])
        if index < len(nodes):
            removed = nodes.pop(index)
            data['nodes'] = nodes
            with open(config_file, 'w') as f:
                json.dump(data, f, indent=2)
            print("success")
        else:
            print("Invalid index", file=sys.stderr)
            sys.exit(1)
    else:
        print(f"Unknown operation: {operation}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
PYTHON_EOF
    
    chmod +x "$PYTHON_HELPER"
}

cleanup_python_helper() {
    rm -f "$PYTHON_HELPER"
}

trap cleanup_python_helper EXIT
#############################################
# UTILITY FUNCTIONS
#############################################

log() {
    local message="$1"
    echo -e "$message"
}

log_to_file() {
    local logfile="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$logfile"
}

log_error() {
    log "${RED}ERROR: $1${NC}"
}

log_success() {
    log "${GREEN}✓ $1${NC}"
}

log_info() {
    log "${WHITE}ℹ️  $1${NC}"
}

log_warning() {
    log "${YELLOW}⚠  $1${NC}"
}

get_available_space_gb() {
    local path="$1"
    df --output=avail "$path" 2>/dev/null | tail -1 | awk '{print int($1/1024/1024)}'
}

get_directory_size_gb() {
    local path="$1"
    du -sb "$path" 2>/dev/null | awk '{print int($1/1024/1024/1024)}'
}

get_directory_size_bytes() {
    local path="$1"
    du -sb "$path" 2>/dev/null | awk '{print $1}'
}

human_readable_size() {
    local BYTES=$1
    if [ "$BYTES" -lt 1024 ]; then
        echo "${BYTES} B"
    elif [ "$BYTES" -lt $((1024*1024)) ]; then
        echo "$((BYTES/1024)) KB"
    elif [ "$BYTES" -lt $((1024*1024*1024)) ]; then
        echo "$((BYTES/1024/1024)) MB"
    elif [ "$BYTES" -lt $((1024*1024*1024*1024)) ]; then
        printf "%.2f GB" $(echo "scale=2; $BYTES/1024/1024/1024" | bc)
    else
        printf "%.2f TB" $(echo "scale=2; $BYTES/1024/1024/1024/1024" | bc)
    fi
}

setup_sudo_session() {
    if [[ "$MODE" == "interactive" ]]; then
        log_info "This operation requires sudo access."
        echo ""
        echo "You'll be asked for your password once."
        echo "Sudo will remain active only during this session."
        echo ""
        
        if ! sudo -v; then
            log_error "Failed to validate sudo credentials"
            exit 1
        fi
        
        log_success "Sudo session activated ✓"
        
        while true; do 
            sudo -n true
            sleep 50
            kill -0 "$$" 2>/dev/null || exit
        done 2>/dev/null &
        SUDO_KEEPER_PID=$!
        
        trap "kill $SUDO_KEEPER_PID 2>/dev/null; cleanup_python_helper" EXIT
    fi
}
send_discord_notification() {
    local webhook_url="$1"
    local message="$2"
    
    if [[ -z "$webhook_url" ]] || [[ "$webhook_url" == "null" ]]; then
        return 0
    fi
    
    # Escape the message for JSON properly
    local escaped_message=$(printf '%s' "$message" | python3 -c "import json, sys; print(json.dumps(sys.stdin.read()))")
    
    local json_payload="{\"content\": $escaped_message}"
    
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "$json_payload" \
         "$webhook_url" >/dev/null 2>&1
}


check_docker() {
    log_info "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! sudo docker ps &>/dev/null; then
        log_error "Cannot connect to Docker daemon. Is Docker running?"
        exit 1
    fi
    
    log_success "Docker detected and running 🐳"
}

check_disk_space() {
    local source_path="$1"
    local backup_path="$2"
    local container_name="$3"
    local node_log="$4"
    
    local available_gb=$(get_available_space_gb "$backup_path")
    
    if [[ $available_gb -ge 500 ]]; then
        log_info "✓ Available space: ${available_gb}GB (sufficient)"
        log_to_file "$node_log" "Disk space check: ${available_gb}GB available (check skipped - plenty of space)"
        return 0
    fi
    
    log_info "Checking disk space requirement (available: ${available_gb}GB)..."
    log_to_file "$node_log" "Disk space check: ${available_gb}GB available"
    
    log_info "Calculating source directory size..."
    local source_size_gb=$(get_directory_size_gb "$source_path")
    local required_gb=$((source_size_gb * 2))
    
    log_to_file "$node_log" "Source size: ${source_size_gb}GB, Required: ${required_gb}GB"
    
    if [[ $available_gb -lt $required_gb ]]; then
        local shortage=$((required_gb - available_gb))
        log_error "Insufficient disk space!"
        log_error "Required: ${required_gb}GB (2x source)"
        log_error "Available: ${available_gb}GB"
        log_error "Shortage: ${shortage}GB"
        log_to_file "$node_log" "ERROR: Insufficient space - need ${shortage}GB more"
        
        if [[ "$MODE" == "interactive" ]]; then
            read -p "Continue anyway? (y/n): " response
            if [[ "$response" != "y" ]]; then
                return 1
            fi
            log_warning "Proceeding despite insufficient space (user override)"
            log_to_file "$node_log" "WARNING: User chose to proceed despite insufficient space"
        else
            return 1
        fi
    else
        log_success "Sufficient space available (${available_gb}GB >= ${required_gb}GB required)"
        log_to_file "$node_log" "Disk space check passed: ${available_gb}GB >= ${required_gb}GB"
    fi
    
    return 0
}

start_node_container() {
    local source_path="$1"
    local container_name="$2"
    local start_script="$3"
    local node_log="$4"
    
    log_info "🔄 Starting container..."
    log_to_file "$node_log" "Starting container: $container_name"
    
    if [[ -n "$start_script" ]] && [[ -f "$source_path/$start_script" ]]; then
        log_info "Using start script: $start_script"
        log_to_file "$node_log" "Using start script: $start_script"
        
        cd "$source_path"
        local script_output=$(./"$start_script" 2>&1)
        local script_exit=$?
        
        if [[ $script_exit -eq 0 ]]; then
            log_success "Start script executed successfully"
            log_to_file "$node_log" "Start script executed successfully"
        else
            log_warning "Start script failed, trying docker start as fallback"
            log_to_file "$node_log" "Start script failed: $script_output"
            log_to_file "$node_log" "Attempting docker start fallback"
            
            local docker_output=$(sudo docker start "$container_name" 2>&1)
            local docker_exit=$?
            
            if [[ $docker_exit -ne 0 ]]; then
                log_to_file "$node_log" "Docker start failed: $docker_output"
            else
                log_to_file "$node_log" "Docker start successful"
            fi
        fi
    else
        log_info "No start script found, using docker start"
        log_to_file "$node_log" "Using docker start (no script found)"
        
        local docker_output=$(sudo docker start "$container_name" 2>&1)
        local docker_exit=$?
        
        if [[ $docker_exit -ne 0 ]]; then
            log_error "Docker start failed: $docker_output"
            log_to_file "$node_log" "ERROR: Docker start failed: $docker_output"
        else
            log_to_file "$node_log" "Docker start successful"
        fi
    fi
}

verify_container_running() {
    local container_name="$1"
    local node_log="$2"
    local max_wait=30
    local elapsed=0
    
    log_info "⏳ Verifying container is up..."
    log_to_file "$node_log" "Verifying container startup..."
    
    while [[ $elapsed -lt $max_wait ]]; do
        if sudo docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            sleep 5
            
            status=$(sudo docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null)
            if [[ "$status" == "running" ]]; then
                log_success "Container is running and healthy 🟢"
                log_to_file "$node_log" "Container verified running (status: $status)"
                return 0
            fi
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    log_error "Container failed to start properly within ${max_wait} seconds 🔴"
    log_to_file "$node_log" "ERROR: Container failed to start within ${max_wait}s"
    return 1
}

#############################################
# CRON MANAGEMENT
#############################################

get_script_path() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
}

check_cron_exists() {
    local script_path=$(get_script_path)
    crontab -l 2>/dev/null | grep -q "$script_path --cron"
    return $?
}

get_cron_schedule() {
    local script_path=$(get_script_path)
    crontab -l 2>/dev/null | grep "$script_path --cron" | head -1
}

calculate_next_run() {
    local cron_expr="$1"
    local minute=$(echo "$cron_expr" | awk '{print $1}')
    local hour=$(echo "$cron_expr" | awk '{print $2}')
    local day_of_month=$(echo "$cron_expr" | awk '{print $3}')
    local month=$(echo "$cron_expr" | awk '{print $4}')
    local day_of_week=$(echo "$cron_expr" | awk '{print $5}')
    
    if [[ "$day_of_week" == "*" ]] && [[ "$day_of_month" == "*" ]]; then
        local next_time="${hour}:$(printf '%02d' $minute)"
        local current_time=$(date +%H:%M)
        
        if [[ "$current_time" < "$next_time" ]]; then
            echo "Today at $next_time"
        else
            echo "Tomorrow at $next_time"
        fi
    elif [[ "$day_of_week" != "*" ]]; then
        local days=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
        echo "Next ${days[$day_of_week]} at ${hour}:$(printf '%02d' $minute)"
    else
        echo "As scheduled"
    fi
}

add_cron_job() {
    local cron_expression="$1"
    local script_path=$(get_script_path)
    
    if check_cron_exists; then
        log_warning "Cron job already exists!"
        read -p "Replace existing schedule? (y/n): " replace
        if [[ "$replace" != "y" ]]; then
            return 1
        fi
        remove_cron_job
    fi
    
    crontab -l > /tmp/crontab.backup.$$ 2>/dev/null || true
    (crontab -l 2>/dev/null; echo "$cron_expression $script_path --cron") | crontab -
    
    if check_cron_exists; then
        log_success "Cron job added successfully ✅"
        rm -f /tmp/crontab.backup.$$
        return 0
    else
        log_error "Failed to add cron job"
        crontab /tmp/crontab.backup.$$ 2>/dev/null || true
        rm -f /tmp/crontab.backup.$$
        return 1
    fi
}

remove_cron_job() {
    local script_path=$(get_script_path)
    
    if ! check_cron_exists; then
        log_warning "No cron job found for this script"
        return 1
    fi
    
    crontab -l > /tmp/crontab.backup.$$ 2>/dev/null
    crontab -l 2>/dev/null | grep -v "$script_path --cron" | crontab -
    
    if ! check_cron_exists; then
        log_success "Cron job removed successfully ✅"
        rm -f /tmp/crontab.backup.$$
        return 0
    else
        log_error "Failed to remove cron job"
        crontab /tmp/crontab.backup.$$ 2>/dev/null || true
        rm -f /tmp/crontab.backup.$$
        return 1
    fi
}

view_cron_schedule() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "  ⏰ AUTOMATED BACKUP SCHEDULE"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    if ! check_cron_exists; then
        log_warning "Status: ❌ Not scheduled"
        echo ""
        echo "No automated backups configured."
        echo "Run 'Setup automated backups' from menu to configure."
        echo ""
        return
    fi
    
    local cron_line=$(get_cron_schedule)
    local cron_expr=$(echo "$cron_line" | awk '{print $1" "$2" "$3" "$4" "$5}')
    local script_path=$(get_script_path)
    
    local frequency=""
    local minute=$(echo "$cron_expr" | awk '{print $1}')
    local hour=$(echo "$cron_expr" | awk '{print $2}')
    local day_of_week=$(echo "$cron_expr" | awk '{print $5}')
    
    if [[ "$hour" == *","* ]]; then
        local hours_array=(${hour//,/ })
        frequency="Every 12 hours (${hours_array[0]}:$(printf '%02d' $minute) and ${hours_array[1]}:$(printf '%02d' $minute))"
    elif [[ "$day_of_week" == "*" ]]; then
        frequency="Daily at ${hour}:$(printf '%02d' $minute)"
    else
        local days=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
        frequency="Weekly on ${days[$day_of_week]} at ${hour}:$(printf '%02d' $minute)"
    fi
    
    local next_run=$(calculate_next_run "$cron_expr")
    
    log_success "Status: ✅ Active"
    echo "Frequency: $frequency"
    echo "Next Run: $next_run"
    echo "Command: $script_path --cron"
    echo ""
    echo "Cron Entry:"
    echo "  $cron_line"
    echo ""
    
    if [[ -f "$CONFIG_FILE" ]]; then
        create_python_helper
        local webhook=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_webhook)
        if [[ -n "$webhook" ]] && [[ "$webhook" != "null" ]]; then
            echo "Discord: ✅ Enabled"
        else
            echo "Discord: ❌ Disabled (no notifications)"
        fi
        local backup_path=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_backup_path)
        echo "Logs: $backup_path/<container_name>/backup.log"
    fi
    
    echo ""
}

setup_cron_schedule() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "  ⏰ SCHEDULE AUTOMATED BACKUPS"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "How often should backups run?"
    echo ""
    echo "1. Every 12 hours (2:00 AM and 2:00 PM)"
    echo "2. Once a day (choose time)"
    echo "3. Weekly (choose day and time)"
    echo "4. Cancel"
    echo ""
    read -p "Select option (1-4): " freq_choice
    
    local cron_expr=""
    local description=""
    
    case $freq_choice in
        1)
            cron_expr="0 2,14 * * *"
            description="Every 12 hours at 2:00 AM and 2:00 PM"
            ;;
        2)
            while true; do
                read -p "Enter hour (0-23, default 2 for 2 AM): " daily_hour
                daily_hour=${daily_hour:-2}
                if [[ "$daily_hour" =~ ^[0-9]+$ ]] && [[ $daily_hour -ge 0 ]] && [[ $daily_hour -le 23 ]]; then
                    break
                else
                    log_error "Please enter a number between 0 and 23"
                fi
            done
            cron_expr="0 $daily_hour * * *"
            description="Daily at ${daily_hour}:00"
            ;;
        3)
            echo ""
            echo "Select day of week:"
            echo "0 = Sunday"
            echo "1 = Monday"
            echo "2 = Tuesday"
            echo "3 = Wednesday"
            echo "4 = Thursday"
            echo "5 = Friday"
            echo "6 = Saturday"
            echo ""
            while true; do
                read -p "Enter day (0-6): " day_of_week
                if [[ "$day_of_week" =~ ^[0-6]$ ]]; then
                    break
                else
                    log_error "Please enter a number between 0 and 6"
                fi
            done
            
            while true; do
                read -p "Enter hour (0-23, default 2 for 2 AM): " weekly_hour
                weekly_hour=${weekly_hour:-2}
                if [[ "$weekly_hour" =~ ^[0-9]+$ ]] && [[ $weekly_hour -ge 0 ]] && [[ $weekly_hour -le 23 ]]; then
                    break
                else
                    log_error "Please enter a number between 0 and 23"
                fi
            done
            
            local days=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
            cron_expr="0 $weekly_hour * * $day_of_week"
            description="Weekly on ${days[$day_of_week]} at ${weekly_hour}:00"
            ;;
        4)
            log_info "Cancelled"
            return 1
            ;;
        *)
            log_error "Invalid option"
            return 1
            ;;
    esac
    
    echo ""
    log_info "Schedule: $description"
    read -p "Confirm and create cron job? (y/n): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        log_info "Cancelled"
        return 1
    fi
    
    if add_cron_job "$cron_expr"; then
        echo ""
        echo "╔═══════════════════════════════════════════════════════════╗"
        log_success "✅ AUTOMATED BACKUPS CONFIGURED!"
        echo "╚═══════════════════════════════════════════════════════════╝"
        echo ""
        echo "Schedule: $description"
        echo "Next Run: $(calculate_next_run "$cron_expr")"
        
        if [[ -f "$CONFIG_FILE" ]]; then
            create_python_helper
            local backup_path=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_backup_path)
            echo "Logs: $backup_path/<container_name>/backup.log"
        fi
        
        echo ""
        return 0
    else
        return 1
    fi
}

setup_automated_backups() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         AUTOMATED BACKUP SETUP WIZARD                      ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "No configuration found. Please create configuration first."
        return 1
    fi
    
    create_python_helper
    
    echo "─── Step 1/3: Sudo Configuration ───"
    echo ""
    
    if [[ -f "$SUDOERS_FILE" ]]; then
        log_success "Sudo already configured ✅"
    else
        echo "For automated/cron backups, passwordless sudo is required."
        echo ""
        echo "This will create LIMITED sudo rules for:"
        echo "  • Docker operations (stop/start/inspect)"
        echo "  • Rsync (backup with permissions)"
        echo "  • Cleanup in backup directory only"
        echo ""
        read -p "Configure sudo now? (y/n): " sudo_response
        
        if [[ "$sudo_response" != "y" ]]; then
            log_warning "Cannot continue without sudo configuration"
            return 1
        fi
        
        local backup_path=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_backup_path)
        
        if [[ -z "$backup_path" ]]; then
            log_error "No backup path in configuration"
            return 1
        fi
        
        local sudoers_content="# BlockDAG Node Backup - Limited sudo permissions
# Created: $(date)
# User: $(whoami)
# Backup Path: ${backup_path}
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/docker stop *
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/docker start *
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/docker ps *
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/docker inspect *
$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/rsync *
$(whoami) ALL=(ALL) NOPASSWD: /bin/rm -rf ${backup_path}/*"
        
        local temp_sudoers="/tmp/node-backup-sudoers-$$"
        echo "$sudoers_content" > "$temp_sudoers"
        
        if ! visudo -c -f "$temp_sudoers" &>/dev/null; then
            log_error "Sudoers syntax validation failed"
            rm -f "$temp_sudoers"
            return 1
        fi
        
        sudo cp "$temp_sudoers" "$SUDOERS_FILE"
        sudo chmod 0440 "$SUDOERS_FILE"
        rm -f "$temp_sudoers"
        
        if [[ -f "$SUDOERS_FILE" ]]; then
            log_success "Limited sudo configuration created ✅"
        else
            log_error "Failed to create sudo configuration"
            return 1
        fi
    fi
    
    echo ""
    
    echo "─── Step 2/3: Discord Notifications ───"
    echo ""
    
    local webhook=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_webhook)
    
    if [[ -n "$webhook" ]] && [[ "$webhook" != "null" ]]; then
        log_success "Discord webhook configured ✅"
        echo "Notifications will be sent for all backups (manual & automated)"
    else
        log_warning "⚠️  No Discord webhook configured!"
        echo ""
        echo "Without Discord webhook, you will NOT receive:"
        echo "  • Backup start/progress notifications"
        echo "  • Backup success/failure notifications"
        echo "  • Disk space warnings"
        echo "  • Summary reports"
        echo ""
        echo "Backups will still run successfully, but silently."
        echo ""
        read -p "Would you like to configure Discord webhook now? (y/n): " discord_response
        
        if [[ "$discord_response" == "y" ]]; then
            read -p "Enter your Discord webhook URL: " new_webhook
            
            if [[ -n "$new_webhook" ]]; then
                local temp_config="/tmp/config-update-$$.py"
                cat > "$temp_config" << 'ENDPY'
import json
import sys
config_file = sys.argv[1]
new_webhook = sys.argv[2]
with open(config_file, 'r') as f:
    config = json.load(f)
config['discord_webhook_url'] = new_webhook
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
ENDPY
                python3 "$temp_config" "$CONFIG_FILE" "$new_webhook"
                rm -f "$temp_config"
                
                echo ""
                echo "Testing webhook..."
                send_discord_notification \
                    "$new_webhook" \
                    "✅ **Webhook Configured**

Discord notifications are now enabled for all backups!"
                log_success "Webhook configured and tested! ✅"
            fi
        else
            log_warning "Continuing without Discord notifications"
            echo "You can add webhook later by editing config or from menu"
        fi
    fi
    
    echo ""
    
    echo "─── Step 3/3: Schedule Backups ───"
    echo ""
    
    if check_cron_exists; then
        log_warning "Automated backups already scheduled!"
        echo ""
        view_cron_schedule
        echo ""
        read -p "Would you like to change the schedule? (y/n): " change_schedule
        
        if [[ "$change_schedule" != "y" ]]; then
            log_info "Setup complete - keeping existing schedule"
            return 0
        fi
    fi
    
    if setup_cron_schedule; then
        echo ""
        log_success "🎉 Automated backup setup complete!"
        echo ""
        echo "Your backups will run automatically as scheduled."
        echo "Check logs in: <backup_path>/<container_name>/backup.log"
        echo ""
        return 0
    else
        log_warning "Cron scheduling cancelled"
        log_info "Sudo is configured. You can schedule later from menu option 6."
        return 1
    fi
}

check_sudo_config() {
    if [[ "$MODE" != "automated" ]]; then
        return 0
    fi
    
    if [[ ! -f "$SUDOERS_FILE" ]]; then
        log_error "Automated mode requires sudo configuration!"
        log_error "Run script in interactive mode and setup sudo from menu."
        exit 1
    fi
    
    local config_path=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_backup_path 2>/dev/null || echo "")
    
    if [[ -z "$config_path" ]]; then
        return 0
    fi
    
    if ! grep -q "rm -rf ${config_path}/\*" "$SUDOERS_FILE" 2>/dev/null; then
        log_warning "⚠️  SUDO CONFIGURATION MISMATCH DETECTED!"
        log_warning "Backup path in config doesn't match sudo permissions."
        log_warning ""
        log_warning "Config path: $config_path"
        log_warning "Sudo cleanup may not work correctly."
        log_warning ""
        log_warning "To fix: Re-run sudo setup from the menu"
        echo ""
        
        if [[ "$MODE" == "interactive" ]]; then
            read -p "Continue anyway? (y/n): " response
            if [[ "$response" != "y" ]]; then
                exit 1
            fi
        fi
    fi
}

#############################################
# CONFIGURATION MANAGEMENT
#############################################

create_config() {
    log_info "Starting configuration wizard... 🛠️"
    echo ""
    
    while true; do
        read -p "How many nodes would you like to backup?: " num_nodes
        if [[ "$num_nodes" =~ ^[0-9]+$ ]] && [[ $num_nodes -ge 1 ]] && [[ $num_nodes -le 20 ]]; then
            break
        else
            log_error "Please enter a number between 1 and 20"
        fi
    done
    
    declare -a nodes
    for ((i=1; i<=num_nodes; i++)); do
        echo ""
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "  📦 Node $i Configuration"
        echo "╚═══════════════════════════════════════════════════════════╝"
        
        while true; do
            read -p "Enter source path for node $i: " source_path
            if [[ -d "$source_path" ]]; then
                break
            else
                log_error "Directory does not exist: $source_path"
            fi
        done
        
        yml_file=""
        
        for pattern in "docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml"; do
            if [[ -f "$source_path/$pattern" ]]; then
                yml_file="$source_path/$pattern"
                break
            fi
        done
        
        if [[ -z "$yml_file" ]]; then
            yml_file=$(find "$source_path" -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \) | head -1)
        fi
        
        if [[ -z "$yml_file" ]]; then
            log_warning "No .yml file found in $source_path"
            read -p "Enter path to .yml file for this node: " yml_file
        else
            log_success "Found yml file: $(basename "$yml_file")"
        fi
        
        container_name=""
        if [[ -f "$yml_file" ]]; then
            container_name=$(grep -A 1 "container_name:" "$yml_file" | grep -v "^--$" | grep "container_name:" | awk '{print $2}' | tr -d '"' | head -1)
        fi
        
        if [[ -z "$container_name" ]]; then
            read -p "Enter container name for node $i: " container_name
        else
            log_success "Detected container name: $container_name"
        fi
        
        start_script=""
        
        if [[ $i -eq 1 ]]; then
            if [[ -f "$source_path/blockdag.sh" ]]; then
                start_script="blockdag.sh"
                log_success "Found start script: blockdag.sh"
            else
                log_warning "No blockdag.sh found, will use docker start as fallback"
            fi
        else
            start_script=$(find "$source_path" -maxdepth 1 -type f -name "blockdag*.sh" ! -name "blockdag.sh" | head -1)
            if [[ -n "$start_script" ]]; then
                start_script=$(basename "$start_script")
                log_success "Found start script: $start_script"
            else
                log_warning "No blockdag*.sh found, will use docker start as fallback"
            fi
        fi
        
        source_path_escaped=$(echo "$source_path" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        yml_file_escaped=$(echo "$yml_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        
        nodes+=("{\"name\":\"node$i\",\"source_path\":\"$source_path_escaped\",\"container_name\":\"$container_name\",\"yml_file\":\"$yml_file_escaped\",\"start_script\":\"$start_script\"}")
    done
    
    echo ""
    while true; do
        read -p "Enter backup destination path (e.g., /mnt/external/backups): " backup_path
        if [[ -d "$backup_path" ]]; then
            break
        else
            read -p "Directory does not exist. Create it? (y/n): " create_dir
            if [[ "$create_dir" == "y" ]]; then
                mkdir -p "$backup_path" && break
            fi
        fi
    done
    
    check_backup_destination "$backup_path"
    
    available_space=$(get_available_space_gb "$backup_path")
    echo ""
    log_info "Available space: ${available_space}GB"
    echo ""
    
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "  💬 Discord Webhook Configuration"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo "Would you like to receive Discord notifications?"
    echo "(Notifications are sent for BOTH manual and automated backups)"
    read -p "(y/n): " enable_discord
    
    webhook_url=""
    if [[ "$enable_discord" == "y" ]]; then
        read -p "Enter your Discord webhook URL (or press Enter to skip): " webhook_url
        
        if [[ -n "$webhook_url" ]]; then
            echo "Testing webhook..."
            send_discord_notification \
                "$webhook_url" \
                "✅ **Webhook Test**

Discord notifications configured successfully! Node backup script is ready."
            log_success "Test notification sent! Check your Discord channel."
        fi
    fi
    
    backup_path_escaped=$(echo "$backup_path" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    webhook_url_escaped=$(echo "$webhook_url" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    
    echo "{" > "$CONFIG_FILE"
    echo "  \"nodes\": [" >> "$CONFIG_FILE"
    for ((i=0; i<${#nodes[@]}; i++)); do
        echo "    ${nodes[$i]}" >> "$CONFIG_FILE"
        if [[ $i -lt $((${#nodes[@]}-1)) ]]; then
            echo "," >> "$CONFIG_FILE"
        fi
    done
    echo "  ]," >> "$CONFIG_FILE"
    echo "  \"backup_path\": \"$backup_path_escaped\"," >> "$CONFIG_FILE"
    echo "  \"discord_webhook_url\": \"$webhook_url_escaped\"," >> "$CONFIG_FILE"
    echo "  \"created_at\": \"$(date '+%Y-%m-%d %H:%M:%S')\"" >> "$CONFIG_FILE"
    echo "}" >> "$CONFIG_FILE"
    
    echo ""
    log_success "Configuration saved to: $CONFIG_FILE"
    echo ""
    
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         AUTOMATED BACKUP SETUP (Optional)                  ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Would you like to setup automated/scheduled backups now?"
    echo "This will configure sudo and create a cron schedule."
    echo ""
    read -p "Setup automated backups now? (y/n): " setup_auto
    
    if [[ "$setup_auto" == "y" ]]; then
        setup_automated_backups
    else
        log_info "Skipped automated setup."
        echo ""
        echo "You can:"
        echo "  • Run manual backups from menu option 1"
        echo "  • Setup automated backups later from menu option 5"
        echo ""
    fi
}

check_backup_destination() {
    local path="$1"
    
    log_info "Checking backup destination..."
    
    if ! mountpoint -q "$path" 2>/dev/null; then
        if [[ "$path" == /mnt/* ]] || [[ "$path" == /media/* ]]; then
            log_warning "Path appears to be an external drive but is not mounted"
        fi
    fi
    
    fs_type=$(df -T "$path" 2>/dev/null | awk 'NR==2 {print $2}')
    
    case "$fs_type" in
        ext4|ext3|btrfs|xfs)
            log_success "Filesystem: $fs_type (Good for preserving permissions)"
            ;;
        vfat|exfat|ntfs)
            log_warning "Filesystem: $fs_type (May not preserve all permissions/symlinks)"
            ;;
        *)
            log_info "Filesystem: $fs_type"
            ;;
    esac
}

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        if [[ "$MODE" == "automated" ]]; then
            log_error "Run script in interactive mode first to create configuration"
            exit 1
        fi
        return 1
    fi
    
    local validation=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" validate 2>&1)
    if [[ "$validation" != "valid" ]]; then
        log_error "Invalid configuration file: $validation"
        exit 1
    fi
    
    log_success "Configuration loaded from: $CONFIG_FILE"
    return 0
}

add_more_nodes() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "No existing configuration found"
        return 1
    fi
    
    log_info "Adding more nodes to existing configuration..."
    echo ""
    
    read -p "How many additional nodes to add? : " num_new_nodes
    
    existing_nodes=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_count)
    
    declare -a new_nodes
    for ((i=1; i<=num_new_nodes; i++)); do
        node_num=$((existing_nodes + i))
        echo ""
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "  📦 Node $node_num Configuration"
        echo "╚═══════════════════════════════════════════════════════════╝"
        
        while true; do
            read -p "Enter source path for node $node_num: " source_path
            if [[ -d "$source_path" ]]; then
                break
            else
                log_error "Directory does not exist: $source_path"
            fi
        done
        
        yml_file=""
        for pattern in "docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml"; do
            if [[ -f "$source_path/$pattern" ]]; then
                yml_file="$source_path/$pattern"
                break
            fi
        done
        
        if [[ -z "$yml_file" ]]; then
            yml_file=$(find "$source_path" -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \) | head -1)
        fi
        
        if [[ -z "$yml_file" ]]; then
            read -p "Enter path to .yml file for this node: " yml_file
        else
            log_success "Found yml file: $(basename "$yml_file")"
        fi
        
        container_name=""
        if [[ -f "$yml_file" ]]; then
            container_name=$(grep -A 1 "container_name:" "$yml_file" | grep -v "^--$" | grep "container_name:" | awk '{print $2}' | tr -d '"' | head -1)
        fi
        
        if [[ -z "$container_name" ]]; then
            read -p "Enter container name for node $node_num: " container_name
        else
            log_success "Detected container name: $container_name"
        fi
        
        start_script=$(find "$source_path" -maxdepth 1 -type f -name "blockdag*.sh" ! -name "blockdag.sh" | head -1)
        if [[ -n "$start_script" ]]; then
            start_script=$(basename "$start_script")
            log_success "Found start script: $start_script"
        else
            log_warning "No blockdag*.sh found, will use docker start as fallback"
            start_script=""
        fi
        
        source_path_escaped=$(echo "$source_path" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        yml_file_escaped=$(echo "$yml_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        
        new_nodes+=("{\"name\":\"node$node_num\",\"source_path\":\"$source_path_escaped\",\"container_name\":\"$container_name\",\"yml_file\":\"$yml_file_escaped\",\"start_script\":\"$start_script\"}")
    done
    
    local nodes_json="["
    for ((i=0; i<${#new_nodes[@]}; i++)); do
        nodes_json+="${new_nodes[$i]}"
        if [[ $i -lt $((${#new_nodes[@]}-1)) ]]; then
            nodes_json+=","
        fi
    done
    nodes_json+="]"
    
    python3 "$PYTHON_HELPER" "$CONFIG_FILE" add_nodes "$nodes_json" &>/dev/null
    
    log_success "Added $num_new_nodes new nodes to configuration"
}

remove_node_from_config() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║            🗑️  REMOVE NODE FROM CONFIGURATION            ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "No configuration found"
        return 1
    fi
    
    create_python_helper
    
    local num_nodes=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_count)
    
    if [[ $num_nodes -eq 0 ]]; then
        log_error "No nodes in configuration"
        return 1
    fi
    
    if [[ $num_nodes -eq 1 ]]; then
        echo "❌ Cannot remove the last node!"
        echo ""
        echo "You must have at least 1 node in the configuration."
        echo ""
        echo "If you want to replace this node:"
        echo "  1. Add the new node first"
        echo "  2. Then remove the old node"
        echo ""
        read -p "Press Enter to return to menu..."
        return 1
    fi
    
    echo "Current nodes in configuration:"
    echo "──────────────────────────────────────────────────────────"
    
    for ((i=0; i<num_nodes; i++)); do
        local node_num=$((i+1))
        local container_name=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_field $i container_name)
        local source_path=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_field $i source_path)
        local node_name=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_field $i name)
        
        echo "  $node_num. $container_name ($node_name)"
        echo "     Path: $source_path"
        echo "     Container: $container_name"
        echo ""
    done
    
    echo "──────────────────────────────────────────────────────────"
    echo "Total nodes: $num_nodes"
    echo ""
    
    read -p "Select node to remove (1-$num_nodes, or 'c' to cancel): " selection
    
    if [[ "$selection" == "c" ]] || [[ "$selection" == "C" ]]; then
        log_info "Cancelled"
        return 0
    fi
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ $selection -lt 1 ]] || [[ $selection -gt $num_nodes ]]; then
        log_error "Invalid selection"
        return 1
    fi
    
    local index=$((selection - 1))
    local container_name=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_field $index container_name)
    local source_path=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_field $index source_path)
    local node_name=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_field $index name)
    local backup_path=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_backup_path)
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  CONFIRMATION ⚠️                    ║"
    echo "╠═══════════════════════════════════════════════════════════╣"
    echo "║                                                           ║"
    echo "║  You are about to REMOVE this node from configuration:   ║"
    echo "║                                                           ║"
    echo "║  Node: $node_name"
    echo "║  Container: $container_name"
    echo "║  Path: $source_path"
    echo "║                                                           ║"
    echo "║  ⚠️  This will:                                           ║"
    echo "║    • Remove node from automated backups                   ║"
    echo "║    • Prevent this node from being backed up by cron       ║"
    echo "║    • Keep all existing backup data (not deleted)          ║"
    echo "║    • Keep the node directory and container intact         ║"
    echo "║                                                           ║"
    echo "║  ✅ This will NOT:                                        ║"
    echo "║    • Stop or delete the container                         ║"
    echo "║    • Delete any backup files                              ║"
    echo "║    • Delete the node directory                            ║"
    echo "║                                                           ║"
    echo "║  💡 Tip: You can add this node back later using           ║"
    echo "║     \"Add more nodes\" option                               ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    if [[ -d "$backup_path/$container_name" ]]; then
        local backup_count=$(find "$backup_path/$container_name" -maxdepth 1 -type d -name "20*" 2>/dev/null | wc -l)
        if [[ $backup_count -gt 0 ]]; then
            local backup_size=$(du -sh "$backup_path/$container_name" 2>/dev/null | awk '{print $1}')
            echo "ℹ️  Backup Information:"
            echo "   Existing backups: $backup_count backup(s) found"
            echo "   Total size: $backup_size"
            echo "   Location: $backup_path/$container_name/"
            echo ""
            echo "   These backups will remain untouched."
            echo ""
        fi
    fi
    
    read -p "Type 'remove' to confirm (or 'cancel'): " confirmation
    
    if [[ "$confirmation" != "remove" ]]; then
        log_info "Cancelled"
        return 0
    fi
    
    echo ""
    log_info "📝 Removing node from configuration..."
    
    if python3 "$PYTHON_HELPER" "$CONFIG_FILE" remove_node $index &>/dev/null; then
        log_success "✅ Node removed successfully!"
        echo ""
        echo "Updated configuration:"
        echo "──────────────────────────────────────────────────────────"
        
        local new_num_nodes=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_count)
        for ((i=0; i<new_num_nodes; i++)); do
            local node_num=$((i+1))
            local container=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_field $i container_name)
            local name=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_field $i name)
            echo "  $node_num. $container ($name)"
        done
        
        echo "──────────────────────────────────────────────────────────"
        echo "Total nodes: $new_num_nodes"
        echo ""
        log_info "💾 Configuration saved to: $CONFIG_FILE"
        echo ""
    else
        log_error "Failed to remove node from configuration"
        return 1
    fi
    
    read -p "Press Enter to return to menu..."
}

#############################################
# BACKUP EXECUTION - SEQUENTIAL MODE
#############################################

perform_backup() {
    log_info "Starting sequential backup process... 🚀"
    
    create_python_helper
    
    if ! load_config; then
        return 1
    fi
    
    if [[ "$MODE" == "automated" ]]; then
        check_sudo_config
    fi
    
    WEBHOOK_URL=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_webhook)
    BACKUP_PATH=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_backup_path)
    NUM_NODES=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_count)
    
    if [[ "$BACKUP_PATH" == /mnt/* ]] || [[ "$BACKUP_PATH" == /media/* ]]; then
        log_info "Checking if backup destination is mounted..."
        if ! mountpoint -q "$BACKUP_PATH" 2>/dev/null; then
            log_error "Backup destination is not mounted: $BACKUP_PATH"
            log_error "Please mount the drive and try again"
            
            send_discord_notification \
                "$WEBHOOK_URL" \
                "❌ **Backup Failed - Drive Not Mounted**
🛑 Backup cannot start because external drive is not mounted
📁 Path: \`$BACKUP_PATH\`"
            
            exit 1
        fi
        log_success "Backup destination is mounted ✅"
    fi
    
    declare -a SUCCESS_NODES
    declare -a FAILED_NODES
    declare -a NODE_TIMES
    declare -a NODE_SIZES
    declare -a NODE_ERRORS
    
    BACKUP_START_TIME=$(date +%s)
    BACKUP_START_FORMATTED=$(date '+%Y-%m-%d-%H%M')
    
    # Send initial Discord notification
    send_discord_notification \
        "$WEBHOOK_URL" \
        "🚀 **Backup Started at $(date '+%Y-%m-%d %H:%M:%S')**
📦 Nodes to backup: **$NUM_NODES**
⚙️ Mode: $MODE"
    
    for ((i=0; i<NUM_NODES; i++)); do
        node_num=$((i+1))
        source_path=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_field $i source_path)
        container_name=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_field $i container_name)
        start_script=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_node_field $i start_script)
        
        mkdir -p "$BACKUP_PATH/$container_name"
        NODE_LOG="$BACKUP_PATH/$container_name/backup.log"
        
        if [[ -f "$NODE_LOG" ]]; then
            if [[ -f "$NODE_LOG.1" ]]; then
                rm -f "$NODE_LOG.1"
            fi
            mv "$NODE_LOG" "$NODE_LOG.1"
        fi
        
        log_to_file "$NODE_LOG" "=========================================="
        log_to_file "$NODE_LOG" "Backup started for: $container_name"
        log_to_file "$NODE_LOG" "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
        log_to_file "$NODE_LOG" "Mode: $MODE"
        log_to_file "$NODE_LOG" "=========================================="
        
        echo ""
        echo "╔═══════════════════════════════════════════════════════════╗"
        log_info "📦 NODE $node_num/$NUM_NODES: $container_name"
        echo "╚═══════════════════════════════════════════════════════════╝"
        
        if ! check_disk_space "$source_path" "$BACKUP_PATH" "$container_name" "$NODE_LOG"; then
            log_error "Skipping node due to insufficient disk space"
            log_to_file "$NODE_LOG" "ERROR: Backup aborted - insufficient disk space"
            log_to_file "$NODE_LOG" "=========================================="
            
            FAILED_NODES+=("$container_name")
            NODE_TIMES+=("0m 00s")
            NODE_SIZES+=("0 B")
            NODE_ERRORS+=("Insufficient disk space")
            
            send_discord_notification \
                "$WEBHOOK_URL" \
                "❌ **Node $node_num/$NUM_NODES Failed**
🐳 Container: \`$container_name\`
⚠️ Error: Insufficient disk space"
            
            continue
        fi
        
        log_info "🛑 Stopping container..."
        log_to_file "$NODE_LOG" "Stopping container..."
        
        send_discord_notification \
            "$WEBHOOK_URL" \
            "🛑 **Node $node_num/$NUM_NODES stopped at $(date '+%Y-%m-%d-%H%M')**"
        
        if sudo docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            stop_output=$(sudo docker stop "$container_name" 2>&1)
            stop_exit=$?
            
            if [[ $stop_exit -ne 0 ]]; then
                log_warning "Failed to stop $container_name gracefully: $stop_output"
                log_to_file "$NODE_LOG" "WARNING: Stop failed: $stop_output"
            else
                log_to_file "$NODE_LOG" "Container stopped successfully"
            fi
        else
            log_warning "Container $container_name is not running"
            log_to_file "$NODE_LOG" "WARNING: Container was not running"
        fi
        
        log_info "⏳ Waiting 10 seconds for clean shutdown..."
        log_to_file "$NODE_LOG" "Waiting 10 seconds for clean shutdown..."
        for j in {10..1}; do
            echo -n "."
            sleep 1
        done
        echo ""
        log_success "Container stopped ✅"
        log_to_file "$NODE_LOG" "Shutdown complete"
        
        timestamp=$(date +%Y-%m-%d-%H%M)
        backup_dest="$BACKUP_PATH/$container_name/$timestamp"
        mkdir -p "$backup_dest"
        
        touch "$backup_dest/.backup_incomplete"
        log_to_file "$NODE_LOG" "Created backup directory: $timestamp"
        log_to_file "$NODE_LOG" "Backup destination: $backup_dest"
        log_to_file "$NODE_LOG" "Created .backup_incomplete marker"
        
        
        node_start=$(date +%s)
        log_info "📦 Copying files..."
        log_to_file "$NODE_LOG" "Starting rsync backup..."
        
        rsync_output=$(sudo rsync -aHAX --checksum "$source_path/" "$backup_dest/" 2>&1)
        rsync_exit=$?
        
        log_to_file "$NODE_LOG" "Rsync completed with exit code: $rsync_exit"
        
        if [[ $rsync_exit -eq 0 ]]; then
            log_success "Copy completed ✅"
            log_to_file "$NODE_LOG" "Copy phase successful"
            
            log_info "🔍 Verifying backup against source..."
            log_to_file "$NODE_LOG" "Starting verification..."
            echo "Checking file integrity..."
            echo "Comparing checksums..."
            
            verify_output=$(sudo rsync -aHAXn --checksum "$source_path/" "$backup_dest/" 2>&1)
            verify_exit=$?
            
            node_end=$(date +%s)
            duration=$((node_end - node_start))
            duration_formatted=$(printf "%dm %02ds" $((duration/60)) $((duration%60)))
            
            log_to_file "$NODE_LOG" "Verification completed with exit code: $verify_exit"
            log_to_file "$NODE_LOG" "Total backup duration: $duration_formatted"
            
            if [[ $verify_exit -eq 0 ]]; then
                log_success "Verification complete - Backup matches source 100% ✅"
                log_to_file "$NODE_LOG" "Verification successful - backup is valid"
                
                # Mark backup as complete FIRST
                rm -f "$backup_dest/.backup_incomplete"
                touch "$backup_dest/.backup_complete"
                log_to_file "$NODE_LOG" "Backup marked as complete"
                
                # Send "Backup created" ONLY after verification passes
                send_discord_notification \
                    "$WEBHOOK_URL" \
                    "📁 **Backup created:** $BACKUP_PATH/$container_name/\`$timestamp\` (Size: calculating...)"
                
                # Flush filesystem buffers BEFORE calculating size
                sync
                sleep 10
                
                # Calculate backup size using sudo for accuracy (Option B)
                backup_size_bytes=$(sudo du -sb "$backup_dest" | awk '{print $1}')
                backup_size_human=$(human_readable_size "$backup_size_bytes")
                log_to_file "$NODE_LOG" "Backup size: $backup_size_human"
                
                 # Update Discord with actual size
                send_discord_notification \
                    "$WEBHOOK_URL" \
                    "💾 **Backup verified:** $backup_size_human"
                
                send_discord_notification \
                    "$WEBHOOK_URL" \
                    "✅ **No differences found. Proceeding with old backups cleanup...**"
                
                # Cleanup old backups based on retention policy
                log_to_file "$NODE_LOG" "Checking backup retention policy (keep: $MAX_BACKUPS_TO_KEEP)..."
                
                if [[ $MAX_BACKUPS_TO_KEEP -gt 0 ]]; then
                    old_backups=$(find "$BACKUP_PATH/$container_name" -maxdepth 1 -type d -name "20*" -exec stat -c '%Y %n' {} \; | sort -rn | awk 'NR>'$MAX_BACKUPS_TO_KEEP' {print $2}')
                    
                    if [[ -n "$old_backups" ]]; then
                        while IFS= read -r old_backup; do
                            old_backup_name=$(basename "$old_backup")
                            log_info "Deleting old backup: $old_backup_name"
                            log_to_file "$NODE_LOG" "Deleting old backup: $old_backup_name"
                            
                            send_discord_notification \
                                "$WEBHOOK_URL" \
                                "🗑️ **Deleted old backup:** $BACKUP_PATH/$container_name/\`$old_backup_name\`"
                            
                            sudo rm -rf "$old_backup"
                        done <<< "$old_backups"
                        log_to_file "$NODE_LOG" "Old backups cleaned up per retention policy"
                    else
                        log_to_file "$NODE_LOG" "No old backups to clean up"
                    fi
                else
                    log_to_file "$NODE_LOG" "Retention policy: Keep all backups (MAX_BACKUPS_TO_KEEP=0)"
                fi
                
                echo ""
                echo "╔═══════════════════════════════════════════════════════════╗"
                log_success "✅ Node $node_num Backup Complete"
                echo "╚═══════════════════════════════════════════════════════════╝"
                echo "Status: ✅ Verified"
                echo "Size: $backup_size_human"
                echo "Time: $duration_formatted"
                echo ""
                
                SUCCESS_NODES+=("$container_name")
                NODE_TIMES+=("$duration_formatted")
                NODE_SIZES+=("$backup_size_human")
                NODE_ERRORS+=("")
                
            else
                log_error "Verification failed - Backup does not match source"
                log_to_file "$NODE_LOG" "ERROR: Verification failed"
                log_to_file "$NODE_LOG" "Verification output: $verify_output"
                
                node_end=$(date +%s)
                duration=$((node_end - node_start))
                duration_formatted=$(printf "%dm %02ds" $((duration/60)) $((duration%60)))
                
                FAILED_NODES+=("$container_name")
                NODE_TIMES+=("$duration_formatted")
                NODE_SIZES+=("0 B")
                NODE_ERRORS+=("Verification failed")
                
                sudo rm -rf "$backup_dest"
                log_to_file "$NODE_LOG" "Failed backup directory removed"
                
                send_discord_notification \
                    "$WEBHOOK_URL" \
                    "❌ **Node $node_num/$NUM_NODES Failed**
🐳 Container: \`$container_name\`
⚠️ Error: Verification failed
⏱️ Duration: $duration_formatted"
            fi
        else
            log_error "Copy failed"
            rsync_error=$(echo "$rsync_output" | tail -n 3 | tr '\n' ' ')
            log_error "Rsync error: $rsync_error"
            log_to_file "$NODE_LOG" "ERROR: Rsync failed"
            log_to_file "$NODE_LOG" "Rsync output: $rsync_output"
            
            node_end=$(date +%s)
            duration=$((node_end - node_start))
            duration_formatted=$(printf "%dm %02ds" $((duration/60)) $((duration%60)))
            
            FAILED_NODES+=("$container_name")
            NODE_TIMES+=("$duration_formatted")
            NODE_SIZES+=("0 B")
            NODE_ERRORS+=("Rsync failed")
            
            sudo rm -rf "$backup_dest"
            log_to_file "$NODE_LOG" "Failed backup directory removed"
            
            send_discord_notification \
                "$WEBHOOK_URL" \
                "❌ **Node $node_num/$NUM_NODES Failed**
🐳 Container: \`$container_name\`
⚠️ Error: Copy failed
⏱️ Duration: $duration_formatted"
        fi
        
        log_to_file "$NODE_LOG" "=========================================="
        
        if [[ "$MODE" == "interactive" ]]; then
            read -p "Press Enter to start Node $node_num and continue..."
            echo ""
        fi
        
        start_node_container "$source_path" "$container_name" "$start_script" "$NODE_LOG"
        
       if verify_container_running "$container_name" "$NODE_LOG"; then
            log_success "Node $node_num is UP and running 🟢"
            log_to_file "$NODE_LOG" "Container is running successfully"
            
            # Send Discord notification AFTER container is verified running
            send_discord_notification \
                "$WEBHOOK_URL" \
                "🚀 **Node started successfully at $(date '+%Y-%m-%d-%H%M')**"
        else
            log_error "Node $node_num failed to start properly 🔴"
            log_to_file "$NODE_LOG" "ERROR: Container failed to start properly"
            
            # Send Discord notification for failed start
            send_discord_notification \
                "$WEBHOOK_URL" \
                "🔴 **Node failed to start at $(date '+%Y-%m-%d-%H%M')**"
        fi
        
        log_to_file "$NODE_LOG" "=========================================="
        log_to_file "$NODE_LOG" "Backup session completed"
        log_to_file "$NODE_LOG" "=========================================="
        
        if [[ $i -lt $((NUM_NODES - 1)) ]]; then
            log_info "Moving to next node... ➡️"
            sleep 3
        fi
    done
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "╔═══════════════════════════════════════════════════════════╗"
    log_success "✅ ALL NODES PROCESSED"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    BACKUP_END_TIME=$(date +%s)
    BACKUP_END_FORMATTED=$(date '+%b %d, %Y %I:%M:%S %p')
    TOTAL_TIME=$((BACKUP_END_TIME - BACKUP_START_TIME))
    TOTAL_TIME_FORMATTED=$(printf "%dm %02ds" $((TOTAL_TIME/60)) $((TOTAL_TIME%60)))
    
    success_count=${#SUCCESS_NODES[@]}
    failed_count=${#FAILED_NODES[@]}
    
    # Calculate total backup size
    total_size_bytes=0
    for size_str in "${NODE_SIZES[@]}"; do
        if [[ "$size_str" != "0 B" ]]; then
            if [[ "$size_str" =~ ([0-9.]+)[[:space:]]*(GB|MB|TB|KB|B) ]]; then
                num="${BASH_REMATCH[1]}"
                unit="${BASH_REMATCH[2]}"
                case "$unit" in
                    TB) bytes=$(echo "$num * 1024 * 1024 * 1024 * 1024" | bc | cut -d. -f1) ;;
                    GB) bytes=$(echo "$num * 1024 * 1024 * 1024" | bc | cut -d. -f1) ;;
                    MB) bytes=$(echo "$num * 1024 * 1024" | bc | cut -d. -f1) ;;
                    KB) bytes=$(echo "$num * 1024" | bc | cut -d. -f1) ;;
                    B) bytes="$num" ;;
                esac
                total_size_bytes=$((total_size_bytes + bytes))
            fi
        fi
    done
    total_size_human=$(human_readable_size "$total_size_bytes")
    
    echo "╔══ NODE STATUS ══╗"
    for i in "${!SUCCESS_NODES[@]}"; do
        container_name="${SUCCESS_NODES[$i]}"
        if sudo docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            echo "🟢 ${container_name} - Running"
        else
            echo "🔴 ${container_name} - Not Running"
        fi
    done
    
    for i in "${!FAILED_NODES[@]}"; do
        node="${FAILED_NODES[$i]}"
        if sudo docker ps --format '{{.Names}}' | grep -q "^${node}$"; then
            echo "🟡 ${node} - Running (Backup Failed)"
        else
            echo "🔴 ${node} - Not Running (Backup Failed)"
        fi
    done
    echo ""
    
    if [[ $failed_count -eq 0 ]]; then
        log_success "All backups completed successfully! 🎉"
    else
        log_warning "Backup completed with some failures ⚠️"
        log_warning "Check logs in: $BACKUP_PATH/<container_name>/backup.log"
    fi
    
    echo ""
    
    # Send final Discord summary
    local summary_msg="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 **BACKUP SUMMARY**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⏱️ **Duration:** $TOTAL_TIME_FORMATTED
💾 **Total Size:** $total_size_human

**Results:**
✅ Successful: $success_count/$NUM_NODES
❌ Failed: $failed_count/$NUM_NODES

**Nodes:**"
    
    for i in "${!SUCCESS_NODES[@]}"; do
        summary_msg="${summary_msg}
✅ \`${SUCCESS_NODES[$i]}\` - ${NODE_SIZES[$i]} (${NODE_TIMES[$i]})"
    done
    
    for i in "${!FAILED_NODES[@]}"; do
        summary_msg="${summary_msg}
❌ \`${FAILED_NODES[$i]}\` - Failed (${NODE_ERRORS[$i]})"
    done
    
    summary_msg="${summary_msg}

📋 Retention: Keeping $MAX_BACKUPS_TO_KEEP backup(s) per node
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    send_discord_notification \
        "$WEBHOOK_URL" \
        "$summary_msg"
}

#############################################
# INTERACTIVE MENU
#############################################

show_menu() {
    while true; do
        echo ""
        echo "╔═══════════════════════════════════════════════════════════╗"
        echo "  📦 NODE BACKUP TOOL - SEQUENTIAL MODE"
        echo "╚═══════════════════════════════════════════════════════════╝"
        echo "1. 🚀 Backup Nodes (one at a time)"
        echo "2. ➕ Add more Nodes"
        echo "3. 👁️  View Configuration"
        echo "4. 💬 Test Discord Webhook"
        echo "5. 🔧 Setup Automated backups (Cron)"
        echo "6. ⏰ View Cron schedule"
        echo "7. 🗑️  Remove/disable Cron schedule"
        echo "8. ➖ Remove Node from configuration"
        echo "9. 🚪 Exit"
        echo "╚═══════════════════════════════════════════════════════════╝"
        read -p "Select an option (1-9): " choice
        
        case $choice in
            1)
                setup_sudo_session
                perform_backup
                ;;
            2)
                if [[ -f "$CONFIG_FILE" ]]; then
                    create_python_helper
                    add_more_nodes
                else
                    log_error "No configuration found. Please create initial configuration first."
                    create_config
                fi
                ;;
            3)
                if [[ -f "$CONFIG_FILE" ]]; then
                    echo ""
                    cat "$CONFIG_FILE"
                    echo ""
                    log_info "Configuration file: $CONFIG_FILE"
                    echo ""
                    log_info "Backup Retention: $MAX_BACKUPS_TO_KEEP backup(s) per node"
                    if [[ $MAX_BACKUPS_TO_KEEP -eq 0 ]]; then
                        echo "(Keeping ALL backups - never delete old ones)"
                    fi
                else
                    log_error "No configuration found ❌"
                fi
                ;;
            4)
                if [[ -f "$CONFIG_FILE" ]]; then
                    create_python_helper
                    webhook=$(python3 "$PYTHON_HELPER" "$CONFIG_FILE" get_webhook)
                    if [[ -n "$webhook" ]] && [[ "$webhook" != "null" ]]; then
                        send_discord_notification \
                            "$webhook" \
                            "🔔 **Webhook Test**

This is a test notification from Node Backup Script.

If you see this, your webhook is working correctly! ✅"
                        log_success "Test notification sent! 📨"
                    else
                        log_error "No webhook URL configured ❌"
                        echo ""
                        read -p "Would you like to configure webhook now? (y/n): " add_webhook
                        if [[ "$add_webhook" == "y" ]]; then
                            read -p "Enter your Discord webhook URL: " new_webhook
                            if [[ -n "$new_webhook" ]]; then
                                local temp_config="/tmp/config-update-$$.py"
                                cat > "$temp_config" << 'ENDPY'
import json
import sys
config_file = sys.argv[1]
new_webhook = sys.argv[2]
with open(config_file, 'r') as f:
    config = json.load(f)
config['discord_webhook_url'] = new_webhook
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
ENDPY
                                python3 "$temp_config" "$CONFIG_FILE" "$new_webhook"
                                rm -f "$temp_config"
                                
                                send_discord_notification \
                                    "$new_webhook" \
                                    "✅ **Webhook Configured**

Discord webhook successfully added!"
                                log_success "Webhook configured and tested! ✅"
                            fi
                        fi
                    fi
                else
                    log_error "No configuration found ❌"
                fi
                ;;
            5)
                if [[ -f "$CONFIG_FILE" ]]; then
                    setup_automated_backups
                else
                    log_error "No configuration found. Create configuration first."
                fi
                ;;
            6)
                view_cron_schedule
                ;;
            7)
                echo ""
                echo "╔═══════════════════════════════════════════════════════════╗"
                echo "  🗑️  REMOVE AUTOMATED BACKUP SCHEDULE"
                echo "╚═══════════════════════════════════════════════════════════╝"
                echo ""
                
                if ! check_cron_exists; then
                    log_warning "No automated schedule found"
                else
                    local current_schedule=$(get_cron_schedule)
                    echo "Current schedule:"
                    echo "  $current_schedule"
                    echo ""
                    log_warning "⚠️  This will remove the automated backup schedule"
                    echo ""
                    echo "This will:"
                    echo "  • Remove cron job"
                    echo "  • Keep sudo configuration (for manual backups)"
                    echo "  • Keep all backup data"
                    echo "  • Keep configuration file"
                    echo ""
                    read -p "Continue? (y/n): " remove_confirm
                    
                    if [[ "$remove_confirm" == "y" ]]; then
                        if remove_cron_job; then
                            echo ""
                            log_success "Automated schedule removed ✅"
                            echo ""
                            echo "You can still run backups manually from menu option 1"
                            echo "Or re-enable automated backups from menu option 5"
                            echo ""
                        fi
                    else
                        log_info "Cancelled"
                    fi
                fi
                ;;
            8)
                remove_node_from_config
                ;;
            9)
                log_info "Exiting... 👋"
                exit 0
                ;;
            *)
                log_error "Invalid option ❌"
                ;;
        esac
    done
}

#############################################
# MAIN EXECUTION
#############################################

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "  ⛏️  BlockDAG Node Backup Tool  ⛏️"
    echo "      	    By"
    echo "   🔥ArtX -BlockDAG Investors Group🔥"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    if [[ "$MODE" == "interactive" ]] && [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}Configuration: ${NC}$CONFIG_FILE"
        echo -e "${YELLOW}Logs Location: ${NC}<backup_path>/<container_name>/backup.log"
        echo -e "${YELLOW}Retention Policy: ${NC}Keep $MAX_BACKUPS_TO_KEEP backup(s) per node"
        if [[ $MAX_BACKUPS_TO_KEEP -eq 0 ]]; then
            echo -e "${YELLOW}Note: ${NC}Retention set to 0 - keeping ALL backups"
        fi
        echo ""
    fi
    
    log_info "Node Backup Script - Mode: $MODE"
    
    check_docker
    
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 is required but not installed ❌"
        exit 1
    fi
    
    if ! command -v rsync &> /dev/null; then
        log_error "rsync is required but not installed ❌"
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        log_error "bc is required but not installed ❌"
        log_error "Install with: sudo apt install bc"
        exit 1
    fi
    
    if [[ "$MODE" == "automated" ]]; then
        create_python_helper
        
        if ! load_config; then
            log_error "Cannot run in automated mode without configuration ❌"
            exit 1
        fi
        
        perform_backup
        
    else
        if [[ ! -f "$CONFIG_FILE" ]]; then
            log_info "No configuration found. Starting setup... 🛠️"
            create_config
        fi
        
        show_menu
    fi
}

main
