#!/bin/bash

# ============================================================================
# Multi-Repository Git Push Script
# ============================================================================
# This script pushes different directories to their respective Gitee repositories
#
# Security Note: This script uses Git credential storage instead of plaintext passwords
# ============================================================================

# Note: Removed 'set -e' to continue processing all repos even if one fails

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITEE_USERNAME="miuzujia1995@163.com"
GITEE_PASSWORD="456843d9586f483cd04d0b8b28ce95b7"  # Gitee Personal Access Token

# Repository mapping: LOCAL_DIR|REMOTE_URL|REPO_NAME
declare -a REPO_MAP=(
    "/home/siat/gem5-gpu-bak/gem5|https://gitee.com/miuzujia/gem5|gem5"
    "/home/siat/gem5-gpu-bak/gem5-gpu|https://gitee.com/miuzujia/gem5-gpu|gem5-gpu"
    "/home/siat/gem5-gpu-bak/gpgpu-sim|https://gitee.com/miuzujia/gpgpu-sim|gpgpu-sim"
    "/home/siat/gem5-gpu-bak/Graphite|https://gitee.com/miuzujia/graphite|Graphite"
    "/home/siat/gem5-gpu-bak/benchmarks|https://gitee.com/miuzujia/benchmarks|benchmarks"
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

# Function: URL encode string
url_encode() {
    local string="$1"
    local encoded=""
    local length="${#string}"

    for (( i=0; i<length; i++ )); do
        local c="${string:i:1}"
        case $c in
            [a-zA-Z0-9.~_-])
                encoded+="$c"
                ;;
            *)
                encoded+=$(printf '%%%02X' "'$c")
                ;;
        esac
    done

    echo "$encoded"
}

# Function: Setup Git credentials (one-time configuration)
setup_git_credentials() {
    print_header "Setting up Git credentials"

    # Configure Git credential storage
    git config --global credential.helper store

    # Configure user information
    git config --global user.email "$GITEE_USERNAME"
    git config --global user.name "miuzujia"

    print_msg "$GREEN" "✓ Git credentials configured"
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

    # Push to remote
    print_msg "$BLUE" "Pushing to $remote_url (branch: $current_branch)..."

    # Construct authenticated URL with proper encoding
    encoded_username=$(url_encode "$GITEE_USERNAME")
    encoded_password=$(url_encode "$GITEE_PASSWORD")
    auth_url=$(echo "$remote_url" | sed "s|https://|https://${encoded_username}:${encoded_password}@|")

    if git push -u "$auth_url" "$current_branch" >> "$LOG_FILE" 2>&1; then
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
    print_header "Git Multi-Repository Push Script"
    print_msg "$BLUE" "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
    print_msg "$BLUE" "Log file: $LOG_FILE"

    # Setup credentials (only needed once)
    setup_git_credentials

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

    echo ""
    print_msg "$YELLOW" "Note: Credentials are cached in Git credential store"
    print_msg "$YELLOW" "To clear credentials: git config --global --unset credential.helper"
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
    echo ""
    echo "Examples:"
    echo "  $0                    # Push all repositories"
    echo "  $0 --status           # Show status of all repositories"
    echo "  $0 --list             # List configured repositories"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
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
