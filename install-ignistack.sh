#!/usr/bin/env bash
# IgniStack Installation Script
# This script installs IgniStack integration for any project

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="${HOME}/.ignistack"
CLI_URL="https://raw.githubusercontent.com/misterlex223/ignistack-sandbox/main/ignistack-cli.sh"
SKILL_URL="https://raw.githubusercontent.com/misterlex223/ignistack-sandbox/main/.claude-skills/ignistack/skill.md"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        log_info "Visit https://docs.docker.com/get-docker/ for installation instructions"
        return 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker."
        return 1
    fi

    return 0
}

install_cli() {
    log_info "Installing IgniStack CLI..."

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    local cli_path="$INSTALL_DIR/ignistack-cli.sh"

    # Copy from local if this is the ignistack-sandbox repo
    if [[ -f "./ignistack-cli.sh" ]]; then
        cp ./ignistack-cli.sh "$cli_path"
        log_success "CLI installed from local source"
    else
        # Download from GitHub
        if command -v curl &> /dev/null; then
            curl -fsSL "$CLI_URL" -o "$cli_path"
        elif command -v wget &> /dev/null; then
            wget -q "$CLI_URL" -O "$cli_path"
        else
            log_error "Neither curl nor wget is available"
            return 1
        fi
        log_success "CLI downloaded from GitHub"
    fi

    # Make executable
    chmod +x "$cli_path"

    # Create symlink
    local symlink_path="/usr/local/bin/ignistack"

    if [[ -w "/usr/local/bin" ]] || mkdir -p "/usr/local/bin" 2>/dev/null; then
        ln -sf "$cli_path" "$symlink_path" 2>/dev/null || true
        if [[ -L "$symlink_path" ]]; then
            log_success "CLI linked to $symlink_path"
        else
            log_warning "Could not create symlink at $symlink_path"
            log_info "You can add the following to your ~/.bashrc or ~/.zshrc:"
            log_info "  export PATH=\"\$PATH:$INSTALL_DIR\""
        fi
    else
        log_warning "Cannot write to /usr/local/bin"
        log_info "Add the following to your ~/.bashrc or ~/.zshrc:"
        log_info "  export PATH=\"\$PATH:$INSTALL_DIR\""
    fi

    return 0
}

install_skill() {
    log_info "Installing Claude Code Skill..."

    local skill_dir="$HOME/.claude/skills/ignistack"
    mkdir -p "$skill_dir"

    local skill_file="$skill_dir/skill.md"

    # Copy from local if this is the ignistack-sandbox repo
    if [[ -f "./.claude-skills/ignistack/skill.md" ]]; then
        cp ./.claude-skills/ignistack/skill.md "$skill_file"
        log_success "Skill installed from local source"
    else
        # Download from GitHub
        if command -v curl &> /dev/null; then
            curl -fsSL "$SKILL_URL" -o "$skill_file"
        elif command -v wget &> /dev/null; then
            wget -q "$SKILL_URL" -O "$skill_file"
        else
            log_error "Neither curl nor wget is available"
            return 1
        fi
        log_success "Skill downloaded from GitHub"
    fi

    return 0
}

setup_completion() {
    log_info "Setting up shell completion..."

    local bash_completion="$INSTALL_DIR/completion.bash"
    local zsh_completion="$INSTALL_DIR/completion.zsh"

    # Create bash completion
    cat > "$bash_completion" <<'EOF'
_ignistack() {
    local cur prev words cword
    _init_completion || return

    if [[ ${cword} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "init create-instance list start stop restart info remove wp schema ai logs shell doctor help" -- "${cur}"))
    fi
}

complete -F _ignistack ignistack
EOF

    # Create zsh completion
    cat > "$zsh_completion" <<'EOF'
#compdef ignistack

_ignistack() {
    local -a commands
    commands=(
        'init:Initialize a new IgniStack environment'
        'create-instance:Create a new WordPress instance'
        'list:List all instances'
        'start:Start an instance'
        'stop:Stop an instance'
        'restart:Restart an instance'
        'info:Show instance details'
        'remove:Remove an instance'
        'wp:Run WP-CLI command'
        'schema:Manage schemas'
        'ai:Run AI operations'
        'logs:Show container logs'
        'shell:Open shell in container'
        'doctor:Run diagnostics'
        'help:Show help'
    )

    if (( CURRENT == 2 )); then
        _describe 'command' commands
    fi
}

_ignistack "$@"
EOF

    log_info "Completion scripts created:"
    log_info "  Bash: source $bash_completion"
    log_info "  Zsh:   source $zsh_completion"
}

verify_installation() {
    log_info "Verifying installation..."

    # Check CLI
    if [[ -f "$INSTALL_DIR/ignistack-cli.sh" ]]; then
        log_success "CLI script installed"
    else
        log_error "CLI script not found"
        return 1
    fi

    # Check Skill
    if [[ -f "$HOME/.claude/skills/ignistack/skill.md" ]]; then
        log_success "Claude Code Skill installed"
    else
        log_warning "Claude Code Skill not found (optional)"
    fi

    return 0
}

show_quick_start() {
    echo
    log_success "IgniStack installed successfully!"
    echo
    echo "QUICK START:"
    echo
    echo "  # Initialize a new project"
    echo "  ignistack init my-project"
    echo
    echo "  # List all instances"
    echo "  ignistack list"
    echo
    echo "  # Start an instance"
    echo "  ignistack start my-project"
    echo
    echo "  # Show instance info"
    echo "  ignistack info my-project"
    echo
    echo "  # Run diagnostics"
    echo "  ignistack doctor"
    echo
    echo "FOR CLAUDE CODE USERS:"
    echo
    echo "  The IgniStack Skill is now available. Use:"
    echo "  /ignistack init my-project"
    echo
    echo "FOR MORE INFORMATION:"
    echo
    echo "  Visit: https://github.com/misterlex223/ignistack-sandbox"
    echo
}

main() {
    echo "IgniStack Installation Script"
    echo "=============================="
    echo

    # Check prerequisites
    log_info "Checking prerequisites..."
    if ! check_docker; then
        exit 1
    fi
    echo

    # Install CLI
    if ! install_cli; then
        log_error "Failed to install CLI"
        exit 1
    fi
    echo

    # Install Skill
    if ! install_skill; then
        log_warning "Failed to install Skill (optional)"
    fi
    echo

    # Setup completion
    setup_completion
    echo

    # Verify
    if ! verify_installation; then
        log_error "Installation verification failed"
        exit 1
    fi
    echo

    # Show quick start
    show_quick_start
}

main "$@"
