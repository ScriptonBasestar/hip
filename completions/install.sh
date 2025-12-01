#!/usr/bin/env bash
# Hip Shell Completion Installation Script
#
# Usage:
#   ./completions/install.sh              # Interactive install
#   ./completions/install.sh bash         # Install bash only
#   ./completions/install.sh zsh          # Install zsh only
#   ./completions/install.sh --user       # User-level install (default)
#   ./completions/install.sh --system     # System-wide install
#   ./completions/install.sh --uninstall  # Remove completions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HIP_BASH_COMPLETION="$SCRIPT_DIR/hip.bash"
HIP_ZSH_COMPLETION="$SCRIPT_DIR/_hip"

# Default options
INSTALL_SCOPE="user"
INSTALL_BASH=""
INSTALL_ZSH=""
UNINSTALL=false

# Helper functions
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  Hip Shell Completion Installation         ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. Completions require jq for manifest parsing."
        echo ""
        echo "Install jq:"
        echo "  macOS:        brew install jq"
        echo "  Ubuntu/Debian: sudo apt-get install jq"
        echo "  CentOS/RHEL:   sudo yum install jq"
        echo ""
        read -p "Continue installation anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "jq is installed"
    fi
}

# Detect shell
detect_shell() {
    local shell_name=$(basename "$SHELL")

    case "$shell_name" in
        bash)
            INSTALL_BASH=true
            ;;
        zsh)
            INSTALL_ZSH=true
            ;;
        *)
            print_warning "Shell '$shell_name' detected, but only bash/zsh are supported"
            INSTALL_BASH=true
            INSTALL_ZSH=true
            ;;
    esac
}

# Install bash completion
install_bash_completion() {
    local install_path=""

    if [[ "$INSTALL_SCOPE" == "user" ]]; then
        # User-level install
        local rc_file="$HOME/.bashrc"

        # Check for .bash_profile on macOS
        if [[ "$OSTYPE" == "darwin"* ]] && [[ -f "$HOME/.bash_profile" ]]; then
            rc_file="$HOME/.bash_profile"
        fi

        # Check if already sourced
        if grep -q "hip.bash" "$rc_file" 2>/dev/null; then
            print_warning "Bash completion already configured in $rc_file"
            return 0
        fi

        # Add source line
        echo "" >> "$rc_file"
        echo "# Hip CLI completion" >> "$rc_file"
        echo "source \"$HIP_BASH_COMPLETION\"" >> "$rc_file"

        print_success "Bash completion added to $rc_file"
        print_info "Run: source $rc_file"

    else
        # System-wide install
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS with Homebrew
            if command -v brew &> /dev/null; then
                install_path="$(brew --prefix)/etc/bash_completion.d/hip"
            else
                install_path="/usr/local/etc/bash_completion.d/hip"
            fi
        else
            # Linux
            if [[ -d "/usr/share/bash-completion/completions" ]]; then
                install_path="/usr/share/bash-completion/completions/hip"
            else
                install_path="/etc/bash_completion.d/hip"
            fi
        fi

        # Check if target directory exists
        local target_dir=$(dirname "$install_path")
        if [[ ! -d "$target_dir" ]]; then
            print_error "Directory $target_dir does not exist"
            print_info "Install bash-completion package first"
            return 1
        fi

        # Copy file
        sudo cp "$HIP_BASH_COMPLETION" "$install_path"
        print_success "Bash completion installed to $install_path"
        print_info "Restart your shell or run: exec bash"
    fi
}

# Install zsh completion
install_zsh_completion() {
    local install_path=""

    if [[ "$INSTALL_SCOPE" == "user" ]]; then
        # User-level install
        local zshrc="$HOME/.zshrc"

        # Check if fpath already configured
        if grep -q "fpath=.*hip.*completions" "$zshrc" 2>/dev/null; then
            print_warning "Zsh completion already configured in $zshrc"
            return 0
        fi

        # Add fpath and compinit
        echo "" >> "$zshrc"
        echo "# Hip CLI completion" >> "$zshrc"
        echo "fpath=($SCRIPT_DIR \$fpath)" >> "$zshrc"

        # Check if compinit already exists
        if ! grep -q "compinit" "$zshrc" 2>/dev/null; then
            echo "autoload -Uz compinit && compinit" >> "$zshrc"
        fi

        print_success "Zsh completion added to $zshrc"
        print_info "Run: exec zsh"

    else
        # System-wide install
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS with Homebrew
            if command -v brew &> /dev/null; then
                install_path="$(brew --prefix)/share/zsh/site-functions/_hip"
            else
                install_path="/usr/local/share/zsh/site-functions/_hip"
            fi
        else
            # Linux
            install_path="/usr/local/share/zsh/site-functions/_hip"
        fi

        # Check if target directory exists
        local target_dir=$(dirname "$install_path")
        if [[ ! -d "$target_dir" ]]; then
            print_info "Creating directory: $target_dir"
            sudo mkdir -p "$target_dir"
        fi

        # Copy file
        sudo cp "$HIP_ZSH_COMPLETION" "$install_path"
        print_success "Zsh completion installed to $install_path"
        print_info "Run: rm -f ~/.zcompdump && exec zsh"
    fi
}

# Uninstall completions
uninstall_completions() {
    print_header
    print_info "Uninstalling Hip completions..."
    echo ""

    local removed=false

    # Remove from .bashrc
    if [[ -f "$HOME/.bashrc" ]]; then
        if grep -q "hip.bash" "$HOME/.bashrc"; then
            sed -i.bak '/# Hip CLI completion/d' "$HOME/.bashrc"
            sed -i.bak '\|hip.bash|d' "$HOME/.bashrc"
            print_success "Removed from ~/.bashrc"
            removed=true
        fi
    fi

    # Remove from .bash_profile
    if [[ -f "$HOME/.bash_profile" ]]; then
        if grep -q "hip.bash" "$HOME/.bash_profile"; then
            sed -i.bak '/# Hip CLI completion/d' "$HOME/.bash_profile"
            sed -i.bak '\|hip.bash|d' "$HOME/.bash_profile"
            print_success "Removed from ~/.bash_profile"
            removed=true
        fi
    fi

    # Remove from .zshrc
    if [[ -f "$HOME/.zshrc" ]]; then
        if grep -q "hip.*completions" "$HOME/.zshrc"; then
            sed -i.bak '/# Hip CLI completion/d' "$HOME/.zshrc"
            sed -i.bak '/fpath=.*hip.*completions/d' "$HOME/.zshrc"
            print_success "Removed from ~/.zshrc"
            removed=true
        fi
    fi

    # Remove system-wide files
    local system_files=(
        "/etc/bash_completion.d/hip"
        "/usr/share/bash-completion/completions/hip"
        "/usr/local/share/zsh/site-functions/_hip"
    )

    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &> /dev/null; then
        system_files+=(
            "$(brew --prefix)/etc/bash_completion.d/hip"
            "$(brew --prefix)/share/zsh/site-functions/_hip"
        )
    fi

    for file in "${system_files[@]}"; do
        if [[ -f "$file" ]]; then
            sudo rm -f "$file"
            print_success "Removed $file"
            removed=true
        fi
    done

    if [[ "$removed" == true ]]; then
        echo ""
        print_success "Hip completions uninstalled"
        print_info "Restart your shell for changes to take effect"
    else
        print_warning "No Hip completions found"
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        bash)
            INSTALL_BASH=true
            shift
            ;;
        zsh)
            INSTALL_ZSH=true
            shift
            ;;
        --user)
            INSTALL_SCOPE="user"
            shift
            ;;
        --system)
            INSTALL_SCOPE="system"
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] [SHELL]"
            echo ""
            echo "Options:"
            echo "  bash              Install bash completion only"
            echo "  zsh               Install zsh completion only"
            echo "  --user            User-level install (default)"
            echo "  --system          System-wide install (requires sudo)"
            echo "  --uninstall       Remove completions"
            echo "  -h, --help        Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                # Interactive install"
            echo "  $0 bash           # Install bash completion"
            echo "  $0 --system zsh   # System-wide zsh install"
            echo "  $0 --uninstall    # Uninstall all completions"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Handle uninstall
if [[ "$UNINSTALL" == true ]]; then
    uninstall_completions
    exit 0
fi

# Main installation
print_header

# Check for jq
check_jq
echo ""

# Auto-detect shell if not specified
if [[ -z "$INSTALL_BASH" ]] && [[ -z "$INSTALL_ZSH" ]]; then
    print_info "Detecting shell..."
    detect_shell
    echo ""
fi

# Confirm installation
print_info "Installation plan:"
echo "  Scope: $INSTALL_SCOPE"
[[ "$INSTALL_BASH" == true ]] && echo "  - Bash completion"
[[ "$INSTALL_ZSH" == true ]] && echo "  - Zsh completion"
echo ""

read -p "Proceed with installation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled"
    exit 0
fi

echo ""

# Install completions
if [[ "$INSTALL_BASH" == true ]]; then
    print_info "Installing bash completion..."
    install_bash_completion
    echo ""
fi

if [[ "$INSTALL_ZSH" == true ]]; then
    print_info "Installing zsh completion..."
    install_zsh_completion
    echo ""
fi

# Final message
print_success "Installation complete!"
echo ""
print_info "Next steps:"
echo "  1. Restart your shell or source your rc file"
echo "  2. Try: hip <TAB>"
echo ""
print_info "Troubleshooting:"
echo "  - Run: hip manifest  # Verify Hip is in PATH"
echo "  - Check: which jq    # Ensure jq is installed"
echo "  - See: completions/README.md for more help"
echo ""
