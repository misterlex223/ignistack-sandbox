#!/bin/bash

# Update GitHub-sourced WordPress Plugins Script
# Supports both development (auto-update) and production (version-locked) modes

set -e

WORDPRESS_DIR="${WORDPRESS_DIR:-/home/flexy/wordpress}"
PLUGINS_DIR="$WORDPRESS_DIR/wp-content/plugins"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Plugin definitions with their GitHub repos
declare -A PLUGINS=(
    ["sqlite-database-integration"]="WordPress/sqlite-database-integration"
    ["ignis-schema-wp"]="misterlex223/ignis-schema-wp"
    ["sync-fire-wp"]="misterlex223/sync-fire-wp"
)

# Plugin specific subdirectories (for nested plugin structures)
declare -A PLUGIN_SUBDIRS=(
    ["ignis-schema-wp"]="ignis-schema-wp"
    ["sync-fire-wp"]="sync-fire-wp"
)

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get current installed version (commit hash)
get_installed_version() {
    local plugin_name=$1
    local plugin_dir="$PLUGINS_DIR/$plugin_name"

    if [ -d "$plugin_dir/.git" ]; then
        cd "$plugin_dir" 2>/dev/null || return 1
        git rev-parse HEAD 2>/dev/null || echo "unknown"
    else
        echo "not-git"
    fi
}

# Function to update a single plugin
update_plugin() {
    local plugin_name=$1
    local repo=$2
    local target_version=${3:-main}
    local plugin_dir="$PLUGINS_DIR/$plugin_name"
    local temp_dir="/tmp/${plugin_name}-update"

    log_info "Updating plugin: $plugin_name"

    # Get current version
    local current_version=$(get_installed_version "$plugin_name")
    log_info "Current version: $current_version"

    # Clone fresh copy
    rm -rf "$temp_dir"
    log_info "Cloning from https://github.com/$repo (branch/tag: $target_version)..."
    
    # Change to a safe directory before cloning to avoid "Unable to read current working directory" error
    cd /tmp
    
    if ! git clone --depth 1 --branch "$target_version" "https://github.com/$repo.git" "$temp_dir" 2>&1; then
        log_error "Failed to clone repository. Branch/tag '$target_version' may not exist."
        return 1
    fi

    # Verify that the temp directory was created and navigate to it
    if [ ! -d "$temp_dir" ]; then
        log_error "Temporary directory was not created properly: $temp_dir"
        return 1
    fi
    
    cd "$temp_dir"
    if [ $? -ne 0 ]; then
        log_error "Could not change to temporary directory: $temp_dir"
        return 1
    fi
    
    local new_version=$(git rev-parse HEAD)
    if [ $? -ne 0 ]; then
        log_error "Could not get git revision"
        return 1
    fi
    log_info "Latest version: $new_version"

    # Check if update needed
    if [ "$current_version" = "$new_version" ]; then
        log_info "Plugin $plugin_name is already up to date"
        rm -rf "$temp_dir"
        return 0
    fi

    # Check if plugin is active before updating
    local was_active=false
    if wp plugin is-active "$plugin_name" --path="$WORDPRESS_DIR" 2>/dev/null; then
        was_active=true
        log_info "Deactivating plugin before update..."
        wp plugin deactivate "$plugin_name" --path="$WORDPRESS_DIR" 2>/dev/null || true
    fi

    # Backup current plugin if it exists
    if [ -d "$plugin_dir" ]; then
        local backup_dir="${plugin_dir}.backup-$(date +%Y%m%d-%H%M%S)"
        log_info "Backing up current version to $backup_dir"
        mv "$plugin_dir" "$backup_dir"
    fi

    # Install new version
    mkdir -p "$plugin_dir"

    # Check if plugin has nested structure
    local subdir="${PLUGIN_SUBDIRS[$plugin_name]}"
    if [ -n "$subdir" ] && [ -d "$temp_dir/$subdir" ]; then
        log_info "Extracting from subdirectory: $subdir"
        cp -r "$temp_dir/$subdir/"* "$plugin_dir/"
    else
        cp -r "$temp_dir/"* "$plugin_dir/"
    fi

    # Remove git repo to save space (but keep version info)
    echo "$new_version" > "$plugin_dir/.version"
    rm -rf "$plugin_dir/.git"

    # Install composer dependencies if composer.json exists
    if [ -f "$plugin_dir/composer.json" ]; then
        log_info "Installing Composer dependencies..."
        cd "$plugin_dir" 2>/dev/null || log_warn "Could not change directory for composer install: $plugin_dir"
        if command -v composer &> /dev/null; then
            composer install --no-dev --optimize-autoloader --quiet || log_warn "Composer install failed"
        else
            log_warn "Composer not found, skipping dependency installation"
        fi
    fi

    # Reactivate plugin if it was active
    if [ "$was_active" = true ]; then
        log_info "Reactivating plugin..."
        wp plugin activate "$plugin_name" --path="$WORDPRESS_DIR" 2>/dev/null || log_warn "Failed to reactivate plugin"
    fi

    # Cleanup
    rm -rf "$temp_dir"

    log_info "✓ Plugin $plugin_name updated successfully (${current_version:0:8} → ${new_version:0:8})"
    return 0
}

# Main execution
main() {
    local update_mode="${1:-dev}"

    echo "=========================================="
    echo "WordPress Plugin Update Tool"
    echo "Mode: $update_mode"
    echo "WordPress Directory: $WORDPRESS_DIR"
    echo "=========================================="
    echo ""

    # Check if WordPress directory exists
    if [ ! -d "$WORDPRESS_DIR" ]; then
        log_error "WordPress directory not found: $WORDPRESS_DIR"
        exit 1
    fi

    # Check if WP-CLI is available
    if ! command -v wp &> /dev/null; then
        log_warn "WP-CLI not found, plugin activation/deactivation will be skipped"
    fi

    local failed_plugins=()

    # Update each plugin
    for plugin_name in "${!PLUGINS[@]}"; do
        local repo="${PLUGINS[$plugin_name]}"

        # Determine version to install based on environment variables
        local version_var="PLUGIN_VERSION_$(echo "$plugin_name" | tr '[:lower:]-' '[:upper:]_')"
        local target_version="${!version_var:-main}"

        echo ""
        if update_plugin "$plugin_name" "$repo" "$target_version"; then
            log_info "✓ $plugin_name update completed"
        else
            log_error "✗ $plugin_name update failed"
            failed_plugins+=("$plugin_name")
        fi
    done

    echo ""
    echo "=========================================="
    if [ ${#failed_plugins[@]} -eq 0 ]; then
        log_info "All plugins updated successfully!"
    else
        log_error "Failed to update: ${failed_plugins[*]}"
        exit 1
    fi
    echo "=========================================="
}

# Run with argument or default to "dev"
main "$@"
