#!/bin/bash

# ============================================================================
# Setup Automatic Daily Git Push - Cron Job Configuration
# ============================================================================
# This script sets up a cron job to automatically push all repositories
# at 2:00 AM every day
# ============================================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_msg() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo ""
    echo "========================================"
    print_msg "$BLUE" "$1"
    echo "========================================"
}

# Configuration
PROJECT_DIR="/home/siat/gem5-gpu-bak"
PUSH_SCRIPT="$PROJECT_DIR/push_all_repos.sh"
CRON_TIME="0 2 * * *"  # 2:00 AM every day
LOG_DIR="$PROJECT_DIR/build_logs/auto_push"

# Create log directory
mkdir -p "$LOG_DIR"

print_header "Automatic Git Push Setup"

# Check if push script exists
if [ ! -f "$PUSH_SCRIPT" ]; then
    print_msg "$RED" "✗ Push script not found: $PUSH_SCRIPT"
    exit 1
fi

# Make sure script is executable
chmod +x "$PUSH_SCRIPT"
print_msg "$GREEN" "✓ Push script is executable"

# Create wrapper script for cron
WRAPPER_SCRIPT="$PROJECT_DIR/auto_push_wrapper.sh"

cat > "$WRAPPER_SCRIPT" << 'EOF'
#!/bin/bash

# Wrapper script for automatic push
# This runs from cron at 2:00 AM daily

# Configuration
PROJECT_DIR="/home/siat/gem5-gpu-bak"
LOG_DIR="$PROJECT_DIR/build_logs/auto_push"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/auto_push_${TIMESTAMP}.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Header
echo "========================================" > "$LOG_FILE"
echo "Automatic Git Push - $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Change to project directory
cd "$PROJECT_DIR" || {
    echo "ERROR: Failed to change to project directory" >> "$LOG_FILE"
    exit 1
}

# Run push script
echo "Starting automatic push..." >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

"$PROJECT_DIR/push_all_repos.sh" >> "$LOG_FILE" 2>&1
EXIT_CODE=$?

# Summary
echo "" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "Push completed at $(date)" >> "$LOG_FILE"
echo "Exit code: $EXIT_CODE" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Send notification (optional, uncomment if you want email notifications)
# if [ $EXIT_CODE -eq 0 ]; then
#     echo "Automatic push succeeded" | mail -s "Git Push Success" your@email.com
# else
#     echo "Automatic push failed. Check $LOG_FILE" | mail -s "Git Push FAILED" your@email.com
# fi

# Cleanup old logs (keep last 30 days)
find "$LOG_DIR" -name "auto_push_*.log" -mtime +30 -delete 2>/dev/null

exit $EXIT_CODE
EOF

chmod +x "$WRAPPER_SCRIPT"
print_msg "$GREEN" "✓ Wrapper script created: $WRAPPER_SCRIPT"

# Create cron entry
CRON_ENTRY="$CRON_TIME $WRAPPER_SCRIPT"

print_header "Cron Job Configuration"

echo ""
print_msg "$CYAN" "Cron job details:"
echo "  Time: 2:00 AM every day"
echo "  Command: $WRAPPER_SCRIPT"
echo "  Logs: $LOG_DIR/auto_push_YYYYMMDD_HHMMSS.log"
echo ""

# Check if cron entry already exists
if crontab -l 2>/dev/null | grep -q "$WRAPPER_SCRIPT"; then
    print_msg "$YELLOW" "⚠ Cron job already exists"
    echo ""
    read -p "Do you want to update it? [Y/n]: " update_cron

    if [[ $update_cron =~ ^[Nn]$ ]]; then
        print_msg "$YELLOW" "Setup cancelled"
        exit 0
    fi

    # Remove existing entry
    crontab -l 2>/dev/null | grep -v "$WRAPPER_SCRIPT" | crontab -
    print_msg "$YELLOW" "Removed existing cron job"
fi

# Add new cron entry
(crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

if [ $? -eq 0 ]; then
    print_msg "$GREEN" "✓ Cron job added successfully"
else
    print_msg "$RED" "✗ Failed to add cron job"
    exit 1
fi

print_header "Verification"

echo ""
print_msg "$CYAN" "Current cron jobs:"
crontab -l | grep -E "(push|git)" || echo "  (none found)"

print_header "Setup Complete!"

echo ""
print_msg "$GREEN" "✓ Automatic push configured"
echo ""
print_msg "$CYAN" "Schedule:"
echo "  • Every day at 2:00 AM"
echo "  • Pushes all repositories (main + submodules)"
echo ""
print_msg "$CYAN" "Logs will be saved to:"
echo "  $LOG_DIR/auto_push_YYYYMMDD_HHMMSS.log"
echo ""
print_msg "$CYAN" "To manage cron jobs:"
echo "  View:   crontab -l"
echo "  Edit:   crontab -e"
echo "  Remove: crontab -r"
echo ""
print_msg "$CYAN" "To test immediately:"
echo "  $WRAPPER_SCRIPT"
echo ""
print_msg "$YELLOW" "Note: Make sure your machine is running at 2:00 AM!"
echo "      WSL may be suspended if Windows is asleep."
echo ""

# Offer to test now
read -p "Do you want to test the automatic push now? [Y/n]: " test_now

if [[ ! $test_now =~ ^[Nn]$ ]]; then
    print_header "Testing Automatic Push"
    echo ""
    print_msg "$BLUE" "Running test push..."
    "$WRAPPER_SCRIPT"

    if [ $? -eq 0 ]; then
        print_msg "$GREEN" "✓ Test push completed successfully"
    else
        print_msg "$RED" "✗ Test push failed"
    fi

    echo ""
    print_msg "$CYAN" "View the log:"
    latest_log=$(ls -t "$LOG_DIR"/auto_push_*.log 2>/dev/null | head -1)
    if [ -n "$latest_log" ]; then
        echo "  cat $latest_log"
    fi
fi

print_header "Additional Information"

echo ""
print_msg "$CYAN" "WSL/Windows users:"
echo "  • Windows Task Scheduler can keep WSL running"
echo "  • Or use Windows Task Scheduler to trigger the script"
echo ""
print_msg "$CYAN" "To disable automatic push:"
echo "  1. Run: crontab -e"
echo "  2. Comment out or delete the line with: $WRAPPER_SCRIPT"
echo "  3. Or run: crontab -r (removes ALL cron jobs)"
echo ""
print_msg "$CYAN" "To change the schedule:"
echo "  1. Run: crontab -e"
echo "  2. Modify the time (currently: 0 2 * * * = 2:00 AM daily)"
echo ""
print_msg "$CYAN" "Common cron time patterns:"
echo "  0 2 * * *     - 2:00 AM every day (current)"
echo "  0 3 * * *     - 3:00 AM every day"
echo "  0 2 * * 1-5   - 2:00 AM weekdays only"
echo "  0 */6 * * *   - Every 6 hours"
echo "  0 0 * * 0     - Midnight every Sunday"
echo ""
