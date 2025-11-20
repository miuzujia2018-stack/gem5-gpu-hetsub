#!/bin/bash

# ============================================================================
# SSH Key Setup for Gitee - Interactive Helper Script
# ============================================================================
# This script helps you set up SSH authentication for Gitee repositories
# ============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
GIT_USER_EMAIL="miuzujia1995@163.com"
GITEE_HOST="gitee.com"

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

print_step() {
    local step=$1
    local message=$2
    echo ""
    print_msg "$CYAN" "[$step] $message"
}

# Check if SSH key exists
check_existing_key() {
    print_header "Step 1: Checking for Existing SSH Keys"

    if [ -f ~/.ssh/id_rsa.pub ]; then
        print_msg "$GREEN" "✓ Found existing RSA key: ~/.ssh/id_rsa.pub"
        return 0
    elif [ -f ~/.ssh/id_ed25519.pub ]; then
        print_msg "$GREEN" "✓ Found existing Ed25519 key: ~/.ssh/id_ed25519.pub"
        return 0
    else
        print_msg "$YELLOW" "⊘ No SSH key found"
        return 1
    fi
}

# Generate new SSH key
generate_ssh_key() {
    print_header "Step 2: Generating New SSH Key"

    echo ""
    print_msg "$YELLOW" "Choose SSH key type:"
    echo "  1) RSA (4096-bit) - More compatible"
    echo "  2) Ed25519 - More secure and faster"
    echo ""
    read -p "Enter choice [1-2] (default: 1): " choice

    case $choice in
        2)
            print_msg "$BLUE" "Generating Ed25519 key..."
            ssh-keygen -t ed25519 -C "$GIT_USER_EMAIL"
            KEY_FILE="$HOME/.ssh/id_ed25519.pub"
            ;;
        *)
            print_msg "$BLUE" "Generating RSA 4096-bit key..."
            ssh-keygen -t rsa -b 4096 -C "$GIT_USER_EMAIL"
            KEY_FILE="$HOME/.ssh/id_rsa.pub"
            ;;
    esac

    if [ -f "$KEY_FILE" ]; then
        print_msg "$GREEN" "✓ SSH key generated successfully"
        return 0
    else
        print_msg "$RED" "✗ Failed to generate SSH key"
        return 1
    fi
}

# Start SSH agent
start_ssh_agent() {
    print_header "Step 3: Starting SSH Agent"

    eval "$(ssh-agent -s)"

    if [ -f ~/.ssh/id_rsa ]; then
        ssh-add ~/.ssh/id_rsa
        print_msg "$GREEN" "✓ Added RSA key to SSH agent"
    elif [ -f ~/.ssh/id_ed25519 ]; then
        ssh-add ~/.ssh/id_ed25519
        print_msg "$GREEN" "✓ Added Ed25519 key to SSH agent"
    fi
}

# Display public key
display_public_key() {
    print_header "Step 4: Your SSH Public Key"

    if [ -f ~/.ssh/id_rsa.pub ]; then
        KEY_FILE="$HOME/.ssh/id_rsa.pub"
    elif [ -f ~/.ssh/id_ed25519.pub ]; then
        KEY_FILE="$HOME/.ssh/id_ed25519.pub"
    else
        print_msg "$RED" "✗ No public key found"
        return 1
    fi

    echo ""
    print_msg "$CYAN" "Copy the following public key:"
    echo "----------------------------------------"
    cat "$KEY_FILE"
    echo "----------------------------------------"
    echo ""
}

# Instructions for adding key to Gitee
gitee_instructions() {
    print_header "Step 5: Add SSH Key to Gitee"

    echo ""
    print_msg "$YELLOW" "Follow these steps to add your SSH key to Gitee:"
    echo ""
    echo "  1. Visit: https://gitee.com/profile/sshkeys"
    echo "  2. Click 'Add SSH Key' button"
    echo "  3. Enter a title (e.g., 'gem5-gpu-dev')"
    echo "  4. Paste your public key (shown above)"
    echo "  5. Click 'Confirm' to save"
    echo ""

    read -p "Press Enter when you've added the key to Gitee..."
}

# Test SSH connection
test_connection() {
    print_header "Step 6: Testing SSH Connection to Gitee"

    echo ""
    print_msg "$BLUE" "Testing connection to $GITEE_HOST..."
    echo ""

    if ssh -T git@gitee.com 2>&1 | grep -q "successfully authenticated"; then
        print_msg "$GREEN" "✓ SSH connection successful!"
        print_msg "$GREEN" "✓ You're authenticated with Gitee"
        return 0
    else
        print_msg "$YELLOW" "⚠ Connection test output:"
        ssh -T git@gitee.com 2>&1 || true
        echo ""
        print_msg "$YELLOW" "If you see 'Permission denied', the key may not be added correctly."
        print_msg "$YELLOW" "If you see 'successfully authenticated', you're good to go!"
        return 1
    fi
}

# Configure Git
configure_git() {
    print_header "Step 7: Configuring Git"

    git config --global user.email "$GIT_USER_EMAIL"
    git config --global user.name "miuzujia"

    print_msg "$GREEN" "✓ Git configuration updated"
    echo ""
    echo "  User email: $GIT_USER_EMAIL"
    echo "  User name: miuzujia"
}

# Main setup workflow
main() {
    print_header "SSH Key Setup for Gitee - Interactive Wizard"
    print_msg "$BLUE" "This script will help you set up SSH authentication for Gitee"

    # Check for existing key
    if check_existing_key; then
        echo ""
        read -p "Do you want to use the existing key? [Y/n]: " use_existing

        if [[ ! $use_existing =~ ^[Nn]$ ]]; then
            print_msg "$GREEN" "Using existing SSH key"
        else
            generate_ssh_key
        fi
    else
        generate_ssh_key
    fi

    # Start SSH agent
    start_ssh_agent

    # Display public key
    display_public_key

    # Auto-copy to clipboard if xclip is available
    if command -v xclip &> /dev/null; then
        if [ -f ~/.ssh/id_rsa.pub ]; then
            cat ~/.ssh/id_rsa.pub | xclip -selection clipboard
        elif [ -f ~/.ssh/id_ed25519.pub ]; then
            cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard
        fi
        print_msg "$GREEN" "✓ Public key copied to clipboard!"
    fi

    # Gitee instructions
    gitee_instructions

    # Test connection
    test_connection

    # Configure Git
    configure_git

    # Final instructions
    print_header "Setup Complete!"
    echo ""
    print_msg "$GREEN" "✓ SSH key setup is complete"
    echo ""
    print_msg "$CYAN" "Next steps:"
    echo "  1. Use the SSH version of the push script:"
    echo "     ./push_to_gitee_ssh.sh"
    echo ""
    echo "  2. Or use the password version (less secure):"
    echo "     ./push_to_gitee.sh"
    echo ""
    print_msg "$YELLOW" "Recommended: Always use the SSH version for better security"
    echo ""
}

# Run main workflow
main
