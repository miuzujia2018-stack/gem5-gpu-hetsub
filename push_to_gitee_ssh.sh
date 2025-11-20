#!/bin/bash

# ============================================================================
# Multi-Repository Git Push Script (SSH Version - RECOMMENDED)
# ============================================================================
# This script uses SSH authentication for secure repository access
# No passwords are stored in the script
# ============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GIT_USER_EMAIL="miuzujia1995@163.com"
GIT_USER_NAME="miuzujia"

# Repository mapping using SSH URLs (SECURE)
declare -a REPO_MAP=(
    "/home/siat/gem5-gpu-bak/gem5|git@gitee.com:miuzujia/gem5.git|gem5"
    "/home/siat/gem5-gpu-bak/gem5-gpu|git@gitee.com:miuzujia/gem5-gpu.git|gem5-gpu"
    "/home/siat/gem5-gpu-bak/gpgpu-sim|git@gitee.com:miuzujia/gpgpu-sim.git|gpgpu-sim"
    "/home/siat/gem5-gpu-bak/Graphite|git@gitee.com:miuzujia/graphite.git|Graphite"
    "/home/siat/gem5-gpu-bak/benchmarks|git@gitee.com:miuzujia/benchmarks.git|benchmarks"
)

# Log file
LOG_DIR="/home/siat/gem5-gpu-bak/build_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/git_push_$(date +%Y%m%d_%H%M%S).log"

# Function: Print colored message
print_msg() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}" | tee -a "$LOG_FILE"
}

# Function: Print section header
print_header() {
    echo "" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
    print_msg "$BLUE" "$1"
    echo "========================================" | tee -a "$LOG_FILE"
}

# Function: Check SSH key setup
check_ssh_key() {
    print_header "Checking SSH Key Configuration"

    if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then
        print_msg "$RED" "✗ No SSH key found!"
        echo ""
        print_msg "$YELLOW" "Please generate an SSH key first:"
        echo "  ssh-keygen -t rsa -b 4096 -C \"$GIT_USER_EMAIL\""
        echo ""
        print_msg "$YELLOW" "Then add the public key to Gitee:"
        echo "  1. Copy your public key: cat ~/.ssh/id_rsa.pub"
        echo "  2. Login to Gitee → Settings → SSH Keys"
        echo "  3. Paste and save the key"
        echo ""
        return 1
    fi

    # Test SSH connection to Gitee
    if ssh -T git@gitee.com 2>&1 | grep -q "successfully authenticated"; then
        print_msg "$GREEN" "✓ SSH connection to Gitee verified"
        return 0
    else
        print_msg "$YELLOW" "⚠ Could not verify SSH connection to Gitee"
        print_msg "$YELLOW" "Please ensure your SSH key is added to Gitee"
        return 1
    fi
}

# Function: Setup Git configuration
setup_git_config() {
    print_header "Setting up Git configuration"

    git config --global user.email "$GIT_USER_EMAIL"
    git config --global user.name "$GIT_USER_NAME"

    print_msg "$GREEN" "✓ Git user configuration set"
}

# Function: Initialize Git repository if needed
init_git_repo() {
    local dir=$1
    local remote_url=$2
    local repo_name=$3

    if [ ! -d "$dir/.git" ]; then
        print_msg "$YELLOW" "Initializing Git repository in $dir"
        cd "$dir"
        git init >> "$LOG_FILE" 2>&1
        git remote add origin "$remote_url" >> "$LOG_FILE" 2>&1 || true
        print_msg "$GREEN" "✓ Repository initialized"
    else
        cd "$dir"
        # Check if remote exists
        if ! git remote get-url origin >> "$LOG_FILE" 2>&1; then
            git remote add origin "$remote_url" >> "$LOG_FILE" 2>&1
        else
            # Update remote URL if different
            current_url=$(git remote get-url origin)
            if [ "$current_url" != "$remote_url" ]; then
                git remote set-url origin "$remote_url" >> "$LOG_FILE" 2>&1
                print_msg "$YELLOW" "Updated remote URL to $remote_url"
            fi
        fi
    fi
}

# Function: Push repository to Gitee
push_repository() {
    local dir=$1
    local remote_url=$2
    local repo_name=$3

    print_header "Processing: $repo_name"
    print_msg "$BLUE" "Directory: $dir"
    print_msg "$BLUE" "Remote: $remote_url"

    # Check if directory exists
    if [ ! -d "$dir" ]; then
        print_msg "$RED" "✗ Directory not found: $dir"
        return 1
    fi

    # Initialize repo if needed
    init_git_repo "$dir" "$remote_url" "$repo_name"

    cd "$dir"

    # Check for changes
    if git diff --quiet && git diff --cached --quiet; then
        print_msg "$YELLOW" "⊘ No changes to commit in $repo_name"
    else
        # Add all changes
        print_msg "$BLUE" "Adding changes..."
        git add -A >> "$LOG_FILE" 2>&1

        # Commit changes
        commit_message="Update $repo_name - $(date '+%Y-%m-%d %H:%M:%S')"
        print_msg "$BLUE" "Committing: $commit_message"
        git commit -m "$commit_message" >> "$LOG_FILE" 2>&1 || {
            print_msg "$YELLOW" "⊘ No changes to commit (already staged)"
        }
    fi

    # Get current branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")

    # Push to remote (SSH - no password needed)
    print_msg "$BLUE" "Pushing to $remote_url (branch: $current_branch)..."

    if git push -u origin "$current_branch" >> "$LOG_FILE" 2>&1; then
        print_msg "$GREEN" "✓ Successfully pushed $repo_name"
    else
        print_msg "$RED" "✗ Failed to push $repo_name"
        print_msg "$YELLOW" "Check log file: $LOG_FILE"
        return 1
    fi

    echo "" | tee -a "$LOG_FILE"
}

# Function: Show repository status
show_status() {
    local dir=$1
    local repo_name=$2

    if [ -d "$dir/.git" ]; then
        cd "$dir"
        echo "" | tee -a "$LOG_FILE"
        print_msg "$BLUE" "Status of $repo_name:"
        git status -s | tee -a "$LOG_FILE"
    fi
}

# Function: Main execution
main() {
    print_header "Git Multi-Repository Push Script (SSH Version)"
    print_msg "$BLUE" "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
    print_msg "$BLUE" "Log file: $LOG_FILE"

    # Check SSH key setup
    if ! check_ssh_key; then
        print_msg "$RED" "✗ SSH key setup incomplete. Exiting."
        exit 1
    fi

    # Setup Git configuration
    setup_git_config

    # Process each repository
    success_count=0
    fail_count=0

    for entry in "${REPO_MAP[@]}"; do
        IFS='|' read -r dir remote_url repo_name <<< "$entry"

        if push_repository "$dir" "$remote_url" "$repo_name"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done

    # Summary
    print_header "Push Summary"
    print_msg "$GREEN" "✓ Successfully pushed: $success_count repositories"
    if [ $fail_count -gt 0 ]; then
        print_msg "$RED" "✗ Failed: $fail_count repositories"
    fi
    print_msg "$BLUE" "End time: $(date '+%Y-%m-%d %H:%M:%S')"
    print_msg "$BLUE" "Log saved to: $LOG_FILE"
}

# Function: Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -s, --status     Show status of all repositories"
    echo "  -l, --list       List all configured repositories"
    echo "  -p, --push       Push all repositories (default)"
    echo "  -c, --check      Check SSH key configuration"
    echo ""
    echo "Examples:"
    echo "  $0                    # Push all repositories"
    echo "  $0 --status           # Show status of all repositories"
    echo "  $0 --list             # List configured repositories"
    echo "  $0 --check            # Check SSH configuration"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    -c|--check)
        check_ssh_key
        exit $?
        ;;
    -s|--status)
        for entry in "${REPO_MAP[@]}"; do
            IFS='|' read -r dir remote_url repo_name <<< "$entry"
            show_status "$dir" "$repo_name"
        done
        exit 0
        ;;
    -l|--list)
        print_header "Configured Repositories"
        for entry in "${REPO_MAP[@]}"; do
            IFS='|' read -r dir remote_url repo_name <<< "$entry"
            echo ""
            print_msg "$BLUE" "Repository: $repo_name"
            echo "  Directory: $dir"
            echo "  Remote: $remote_url"
        done
        exit 0
        ;;
    -p|--push|"")
        main
        ;;
    *)
        print_msg "$RED" "Unknown option: $1"
        usage
        exit 1
        ;;
esac
