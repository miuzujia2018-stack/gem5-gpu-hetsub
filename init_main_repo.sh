#!/bin/bash

# ============================================================================
# Initialize gem5-gpu-bak Main Repository with Git Submodules
# ============================================================================
# This script creates a main repository that uses git submodules to reference
# the already-pushed repositories, and only pushes configuration/script files
# ============================================================================

set -e  # Exit on error

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
MAIN_REPO_URL="https://gitee.com/miuzujia/gem5-gpu-bak"
GITEE_USERNAME="miuzujia1995@163.com"
GITEE_PASSWORD="456843d9586f483cd04d0b8b28ce95b7"

# Submodule configuration: PATH|URL
declare -a SUBMODULES=(
    "gem5|https://gitee.com/miuzujia/gem5"
    "gem5-gpu|https://gitee.com/miuzujia/gem5-gpu"
    "gpgpu-sim|https://gitee.com/miuzujia/gpgpu-sim"
    "Graphite|https://gitee.com/miuzujia/graphite"
    "benchmarks|https://gitee.com/miuzujia/benchmarks"
)

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

# Main function
main() {
    print_header "gem5-gpu-bak Main Repository Setup"

    # Check if already initialized
    if [ -d .git ]; then
        print_msg "$YELLOW" "⚠ Git repository already exists"
        read -p "Do you want to reinitialize? This will remove .git directory [y/N]: " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            print_msg "$YELLOW" "Removing existing .git directory..."
            rm -rf .git
        else
            print_msg "$RED" "Aborted"
            exit 1
        fi
    fi

    # Initialize git repository
    print_header "Step 1: Initialize Git Repository"
    git init
    print_msg "$GREEN" "✓ Git repository initialized"

    # Configure git
    print_header "Step 2: Configure Git"
    git config user.email "$GITEE_USERNAME"
    git config user.name "miuzujia"
    print_msg "$GREEN" "✓ Git configured"

    # Check .gitignore
    print_header "Step 3: Check .gitignore"
    if [ -f .gitignore ]; then
        print_msg "$GREEN" "✓ .gitignore exists"
    else
        print_msg "$RED" "✗ .gitignore not found!"
        print_msg "$YELLOW" "Please create .gitignore first"
        exit 1
    fi

    # Show what will be included
    print_header "Step 4: Preview Files to be Pushed"
    echo ""
    print_msg "$CYAN" "Files that will be included:"
    git add -A --dry-run 2>&1 | grep -E "^\s*add" | head -20
    echo ""

    total_files=$(git add -A --dry-run 2>&1 | grep -E "^\s*add" | wc -l)
    print_msg "$BLUE" "Total files to be added: $total_files"

    echo ""
    read -p "Continue with these files? [Y/n]: " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        print_msg "$RED" "Aborted"
        exit 1
    fi

    # Add all files (respecting .gitignore)
    print_header "Step 5: Stage Files"
    git add -A
    print_msg "$GREEN" "✓ Files staged"

    # Show git status
    print_msg "$CYAN" "Git status:"
    git status -s | head -30

    # Initial commit
    print_header "Step 6: Create Initial Commit"
    git commit -m "Initial commit: gem5-gpu-bak configuration and scripts

- Build and test automation scripts
- Project documentation (CLAUDE.md, README files)
- Analysis and generation Python scripts
- Configuration files
- Small reports and diagrams

Note: Large repositories (gem5, gem5-gpu, etc.) are managed as submodules
and pushed separately to individual repositories.

🤖 Generated with Claude Code
"
    print_msg "$GREEN" "✓ Initial commit created"

    # Add remote
    print_header "Step 7: Add Remote Repository"
    git remote add origin "$MAIN_REPO_URL"
    print_msg "$GREEN" "✓ Remote added: $MAIN_REPO_URL"

    # Create .gitmodules file
    print_header "Step 8: Create .gitmodules Configuration"
    cat > .gitmodules << 'EOF'
[submodule "gem5"]
	path = gem5
	url = https://gitee.com/miuzujia/gem5
[submodule "gem5-gpu"]
	path = gem5-gpu
	url = https://gitee.com/miuzujia/gem5-gpu
[submodule "gpgpu-sim"]
	path = gpgpu-sim
	url = https://gitee.com/miuzujia/gpgpu-sim
[submodule "Graphite"]
	path = Graphite
	url = https://gitee.com/miuzujia/graphite
[submodule "benchmarks"]
	path = benchmarks
	url = https://gitee.com/miuzujia/benchmarks
EOF

    git add .gitmodules
    git commit -m "Add submodule configuration

Submodules point to separately maintained repositories:
- gem5: Core simulator
- gem5-gpu: GPU integration layer
- gpgpu-sim: GPU simulation engine
- Graphite: Network simulator
- benchmarks: Test benchmarks

🤖 Generated with Claude Code
"
    print_msg "$GREEN" "✓ .gitmodules created and committed"

    # Push to remote
    print_header "Step 9: Push to Gitee"

    encoded_username=$(url_encode "$GITEE_USERNAME")
    encoded_password=$(url_encode "$GITEE_PASSWORD")
    auth_url=$(echo "$MAIN_REPO_URL" | sed "s|https://|https://${encoded_username}:${encoded_password}@|")

    print_msg "$BLUE" "Pushing to $MAIN_REPO_URL..."

    if git push -u "$auth_url" master; then
        print_msg "$GREEN" "✓ Successfully pushed to Gitee!"
    else
        print_msg "$RED" "✗ Push failed"
        print_msg "$YELLOW" "You may need to create the repository on Gitee first:"
        print_msg "$YELLOW" "  https://gitee.com/new"
        exit 1
    fi

    # Summary
    print_header "Setup Complete!"
    echo ""
    print_msg "$GREEN" "✓ Main repository initialized and pushed"
    print_msg "$BLUE" "Repository URL: $MAIN_REPO_URL"
    echo ""
    print_msg "$CYAN" "Next steps:"
    echo "  1. Others can clone with submodules:"
    echo "     git clone --recursive $MAIN_REPO_URL"
    echo ""
    echo "  2. Or clone and init submodules separately:"
    echo "     git clone $MAIN_REPO_URL"
    echo "     cd gem5-gpu-bak"
    echo "     git submodule init"
    echo "     git submodule update"
    echo ""
    print_msg "$YELLOW" "Note: Submodules reference existing repositories"
    print_msg "$YELLOW" "Update submodules separately in their own directories"
}

# Run main function
main
