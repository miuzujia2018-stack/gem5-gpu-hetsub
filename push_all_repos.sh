#!/bin/bash

# ============================================================================
# Push ALL Repositories - Main Repository + All Submodules
# ============================================================================
# This script pushes:
# 1. Main repository (gem5-gpu-bak) - scripts, docs, config
# 2. All 6 submodules (gem5, gem5-gpu, gpgpu-sim, Graphite, benchmarks, mvpp_manuscript)
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
GITEE_USERNAME="miuzujia1995@163.com"
GITEE_PASSWORD="456843d9586f483cd04d0b8b28ce95b7"
MAIN_REPO_URL="https://gitee.com/miuzujia/gem5-gpu-bak"

# Submodule mapping: LOCAL_DIR|REMOTE_URL|REPO_NAME
declare -a SUBMODULES=(
    "/mnt/d/gem5-gpu-bak/gem5|https://gitee.com/miuzujia/gem5|gem5"
    "/mnt/d/gem5-gpu-bak/gem5-gpu|https://gitee.com/miuzujia/gem5-gpu|gem5-gpu"
    "/mnt/d/gem5-gpu-bak/gpgpu-sim|https://gitee.com/miuzujia/gpgpu-sim|gpgpu-sim"
    "/mnt/d/gem5-gpu-bak/Graphite|https://gitee.com/miuzujia/graphite|Graphite"
    "/mnt/d/gem5-gpu-bak/benchmarks|https://gitee.com/miuzujia/benchmarks|benchmarks"
)

# Log file
LOG_DIR="/mnt/d/gem5-gpu-bak/build_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/push_all_$(date +%Y%m%d_%H%M%S).log"

# URL encoding function
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

# Function: Push main repository
push_main_repo() {
    print_header "Step 1: Push Main Repository (gem5-gpu-bak)"

    cd /mnt/d/gem5-gpu-bak

    # Check if there are changes
    if git diff --quiet && git diff --cached --quiet; then
        print_msg "$YELLOW" "⊘ No uncommitted changes in main repository"
    else
        print_msg "$BLUE" "Adding and committing changes..."
        git add -A >> "$LOG_FILE" 2>&1
        commit_msg="Update gem5-gpu-bak - $(date '+%Y-%m-%d %H:%M:%S')"
        git commit -m "$commit_msg" >> "$LOG_FILE" 2>&1 || {
            print_msg "$YELLOW" "⊘ No changes to commit"
        }
    fi

    # Push to remote
    print_msg "$BLUE" "Pushing main repository..."

    encoded_username=$(url_encode "$GITEE_USERNAME")
    encoded_password=$(url_encode "$GITEE_PASSWORD")
    auth_url=$(echo "$MAIN_REPO_URL" | sed "s|https://|https://${encoded_username}:${encoded_password}@|")

    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")

    if git push -u "$auth_url" "$current_branch" >> "$LOG_FILE" 2>&1; then
        print_msg "$GREEN" "✓ Main repository pushed successfully"
        return 0
    else
        print_msg "$RED" "✗ Failed to push main repository"
        return 1
    fi
}

# Function: Push submodule
push_submodule() {
    local dir=$1
    local remote_url=$2
    local repo_name=$3

    print_header "Processing Submodule: $repo_name"
    print_msg "$BLUE" "Directory: $dir"
    print_msg "$BLUE" "Remote: $remote_url"

    # Check if directory exists
    if [ ! -d "$dir" ]; then
        print_msg "$RED" "✗ Directory not found: $dir"
        return 1
    fi

    cd "$dir"

    # Check if it's a git repository
    if [ ! -d .git ]; then
        print_msg "$YELLOW" "⊘ Not a git repository, skipping: $repo_name"
        return 0
    fi

    # Update remote URL
    if git remote get-url origin >> "$LOG_FILE" 2>&1; then
        current_url=$(git remote get-url origin)
        if [ "$current_url" != "$remote_url" ]; then
            git remote set-url origin "$remote_url" >> "$LOG_FILE" 2>&1
            print_msg "$YELLOW" "Updated remote URL"
        fi
    else
        git remote add origin "$remote_url" >> "$LOG_FILE" 2>&1
    fi

    # Check for changes
    if git diff --quiet && git diff --cached --quiet; then
        print_msg "$YELLOW" "⊘ No changes to commit in $repo_name"
    else
        print_msg "$BLUE" "Adding changes..."
        git add -A >> "$LOG_FILE" 2>&1

        commit_message="Update $repo_name - $(date '+%Y-%m-%d %H:%M:%S')"
        print_msg "$BLUE" "Committing: $commit_message"
        git commit -m "$commit_message" >> "$LOG_FILE" 2>&1 || {
            print_msg "$YELLOW" "⊘ No changes to commit (already staged)"
        }
    fi

    # Get current branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "master")

    # Push to remote
    print_msg "$BLUE" "Pushing $repo_name (branch: $current_branch)..."

    encoded_username=$(url_encode "$GITEE_USERNAME")
    encoded_password=$(url_encode "$GITEE_PASSWORD")
    auth_url=$(echo "$remote_url" | sed "s|https://|https://${encoded_username}:${encoded_password}@|")

    if git push -u "$auth_url" "$current_branch" >> "$LOG_FILE" 2>&1; then
        print_msg "$GREEN" "✓ Successfully pushed $repo_name"
        return 0
    else
        print_msg "$RED" "✗ Failed to push $repo_name"
        print_msg "$YELLOW" "Check log file: $LOG_FILE"
        return 1
    fi
}

# Main function
main() {
    print_header "Push ALL Repositories - Complete Workflow"
    print_msg "$BLUE" "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
    print_msg "$BLUE" "Log file: $LOG_FILE"

    # Initialize counters
    total_repos=$((1 + ${#SUBMODULES[@]}))  # Main + submodules
    success_count=0
    fail_count=0

    # Push main repository
    if push_main_repo; then
        ((success_count++))
    else
        ((fail_count++))
    fi

    echo "" | tee -a "$LOG_FILE"

    # Push all submodules
    print_header "Step 2: Push All Submodules"

    for entry in "${SUBMODULES[@]}"; do
        IFS='|' read -r dir remote_url repo_name <<< "$entry"

        if push_submodule "$dir" "$remote_url" "$repo_name"; then
            ((success_count++))
        else
            ((fail_count++))
        fi

        echo "" | tee -a "$LOG_FILE"
    done

    # Summary
    print_header "Push Summary"
    echo "" | tee -a "$LOG_FILE"
    print_msg "$CYAN" "Total repositories: $total_repos"
    print_msg "$GREEN" "✓ Successfully pushed: $success_count"
    if [ $fail_count -gt 0 ]; then
        print_msg "$RED" "✗ Failed: $fail_count"
    fi
    echo "" | tee -a "$LOG_FILE"
    print_msg "$BLUE" "End time: $(date '+%Y-%m-%d %H:%M:%S')"
    print_msg "$BLUE" "Log saved to: $LOG_FILE"

    echo ""
    print_msg "$CYAN" "Repository URLs:"
    echo "  Main: https://gitee.com/miuzujia/gem5-gpu-bak"
    echo "  • gem5: https://gitee.com/miuzujia/gem5"
    echo "  • gem5-gpu: https://gitee.com/miuzujia/gem5-gpu"
    echo "  • gpgpu-sim: https://gitee.com/miuzujia/gpgpu-sim"
    echo "  • Graphite: https://gitee.com/miuzujia/graphite"
    echo "  • benchmarks: https://gitee.com/miuzujia/benchmarks"

    if [ $fail_count -eq 0 ]; then
        echo ""
        print_msg "$GREEN" "🎉 All repositories pushed successfully!"
        return 0
    else
        echo ""
        print_msg "$YELLOW" "⚠ Some repositories failed. Check the log file for details."
        return 1
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Push all repositories (main + submodules) to Gitee"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -m, --main-only  Push only main repository"
    echo "  -s, --subs-only  Push only submodules"
    echo ""
    echo "Examples:"
    echo "  $0                    # Push everything (main + submodules)"
    echo "  $0 --main-only        # Push only main repository"
    echo "  $0 --subs-only        # Push only submodules"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    -m|--main-only)
        print_header "Push Main Repository Only"
        push_main_repo
        exit $?
        ;;
    -s|--subs-only)
        print_header "Push Submodules Only"
        success_count=0
        fail_count=0
        for entry in "${SUBMODULES[@]}"; do
            IFS='|' read -r dir remote_url repo_name <<< "$entry"
            if push_submodule "$dir" "$remote_url" "$repo_name"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        done
        print_msg "$GREEN" "✓ Successfully pushed: $success_count submodules"
        [ $fail_count -gt 0 ] && print_msg "$RED" "✗ Failed: $fail_count submodules"
        exit $([ $fail_count -eq 0 ] && echo 0 || echo 1)
        ;;
    "")
        main
        ;;
    *)
        print_msg "$RED" "Unknown option: $1"
        usage
        exit 1
        ;;
esac
