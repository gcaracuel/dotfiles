#!/usr/bin/env bash
# krew.sh - Install kubectl krew plugin manager and plugins
# Krew is a plugin manager for kubectl command-line tool

# Source utils if not already sourced
if [[ -z "${UTILS_SOURCED:-}" ]]; then
    KREW_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=utils.sh
    source "$KREW_SCRIPT_DIR/utils.sh"
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly KREW_ROOT="${KREW_ROOT:-$HOME/.krew}"
readonly KREW_BIN="$KREW_ROOT/bin"

# =============================================================================
# KREW DETECTION
# =============================================================================

# Check if krew is already installed
is_krew_installed() {
    [[ -x "$KREW_BIN/kubectl-krew" ]] || command_exists kubectl-krew
}

# Check if a krew plugin is installed
is_krew_plugin_installed() {
    local plugin="$1"
    
    # Add krew to PATH temporarily if needed
    if [[ -d "$KREW_BIN" ]] && [[ ! "$PATH" =~ $KREW_BIN ]]; then
        export PATH="$KREW_BIN:$PATH"
    fi
    
    kubectl krew list 2>/dev/null | grep -q "^${plugin}$"
}

# =============================================================================
# KREW INSTALLATION
# =============================================================================

# Install kubectl krew plugin manager
install_krew() {
    log_header "Installing kubectl krew"
    
    # Check if kubectl is installed
    if ! command_exists kubectl; then
        log_warning "kubectl not found - krew requires kubectl to be installed"
        log_info "Install kubectl first, then run this script again"
        return 0
    fi
    
    if is_krew_installed; then
        log_success "kubectl krew already installed"
    else
        if [[ "$DRY_RUN" == true ]]; then
            log_dry_run "Would install kubectl krew"
            log_dry_run "Would add $KREW_BIN to PATH"
            return 0
        fi
        
        log_step "Downloading and installing krew..."
        
        # Create a temporary directory for installation
        local temp_dir
        temp_dir=$(mktemp -d)
        
        # Ensure cleanup on exit
        trap "rm -rf '$temp_dir'" EXIT
        
        # Run the official krew installation script
        (
            set -x
            cd "$temp_dir" || exit 1
            
            # Detect OS and architecture
            OS="$(uname | tr '[:upper:]' '[:lower:]')"
            ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"
            KREW="krew-${OS}_${ARCH}"
            
            # Download krew
            if ! curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"; then
                die "Failed to download krew" \
                    "Check your internet connection and try again"
            fi
            
            # Extract and install
            if ! tar zxf "${KREW}.tar.gz" 2>&1 | grep -v "Ignoring unknown extended header"; then
                die "Failed to extract krew archive"
            fi
            
            if ! ./"${KREW}" install krew; then
                die "Failed to install krew"
            fi
        ) || return 1
        
        log_success "kubectl krew installed"
        
        # Check if krew bin is in PATH
        if [[ ! "$PATH" =~ $KREW_BIN ]]; then
            log_info "Add krew to your PATH by adding this to your shell config:"
            log_info "  export PATH=\"\${KREW_ROOT:-\$HOME/.krew}/bin:\$PATH\""
        fi
        
        # Temporarily add to PATH for this session
        if [[ -d "$KREW_BIN" ]]; then
            export PATH="$KREW_BIN:$PATH"
        fi
    fi
}

# =============================================================================
# KREW PLUGINS
# =============================================================================

# Get list of krew plugins from packages.yaml
get_krew_plugins() {
    if [[ ! -f "$PACKAGES_YAML" ]]; then
        return 0
    fi
    
    # Extract krew_plugins array from YAML
    # Works with both mikefarah/yq (Go) and kislyuk/yq (Python/jq wrapper)
    yq -r '.krew_plugins[]' "$PACKAGES_YAML" 2>/dev/null || \
    yq eval '.krew_plugins[]' "$PACKAGES_YAML" 2>/dev/null || true
}

# Install krew plugins from packages.yaml
install_krew_plugins() {
    # Ensure krew is in PATH
    if [[ -d "$KREW_BIN" ]] && [[ ! "$PATH" =~ $KREW_BIN ]]; then
        export PATH="$KREW_BIN:$PATH"
    fi
    
    if ! is_krew_installed; then
        log_warning "kubectl krew not installed - skipping plugin installation"
        return 0
    fi
    
    local plugins
    plugins=$(get_krew_plugins)
    
    if [[ -z "$plugins" ]]; then
        log_info "No krew plugins to install"
        return 0
    fi
    
    log_header "Installing kubectl krew plugins"
    
    local installed_count=0
    local skipped_count=0
    
    while IFS= read -r plugin; do
        [[ -z "$plugin" ]] && continue
        
        # Extract plugin name (handle format like "kvaps/node-shell")
        local plugin_name
        if [[ "$plugin" =~ / ]]; then
            plugin_name="${plugin##*/}"
        else
            plugin_name="$plugin"
        fi
        
        if is_krew_plugin_installed "$plugin_name"; then
            log_debug "kubectl krew plugin already installed: $plugin"
            skipped_count=$((skipped_count + 1))
        else
            if [[ "$DRY_RUN" == true ]]; then
                log_dry_run "Would install: $plugin"
            else
                log_step "Installing kubectl krew plugin: $plugin"
                log_debug "Running: kubectl krew install $plugin"
                
                local error_output
                if error_output=$(kubectl krew install "$plugin" 2>&1); then
                    log_success "$plugin installed"
                    log_debug "Successfully installed $plugin"
                    installed_count=$((installed_count + 1))
                else
                    log_warning "Failed to install $plugin"
                    # Show first 3 lines of error for context
                    local error_preview
                    error_preview=$(echo "$error_output" | head -3 | sed 's/^/  /')
                    echo "$error_preview" >&2
                    log_debug "Failed to install $plugin: $error_output"
                fi
            fi
        fi
    done <<< "$plugins"
    
    if [[ "$DRY_RUN" != true ]]; then
        log_success "Krew plugins complete (installed: $installed_count, already installed: $skipped_count)"
    fi
}

# =============================================================================
# DRY-RUN CHECK
# =============================================================================

check_krew_dry_run() {
    log_header "KUBECTL KREW"
    
    if ! command_exists kubectl; then
        log_warning "kubectl not found - krew requires kubectl"
        return 0
    fi
    
    if is_krew_installed; then
        log_success "kubectl krew is already installed"
    else
        log_dry_run "Would install kubectl krew"
        log_dry_run "Would add $KREW_BIN to PATH"
    fi
    
    # Show plugins that would be installed
    local plugins
    plugins=$(get_krew_plugins)
    
    if [[ -n "$plugins" ]]; then
        echo ""
        log_info "Krew plugins to install:"
        while IFS= read -r plugin; do
            [[ -z "$plugin" ]] && continue
            
            local plugin_name
            if [[ "$plugin" =~ / ]]; then
                plugin_name="${plugin##*/}"
            else
                plugin_name="$plugin"
            fi
            
            if is_krew_installed && is_krew_plugin_installed "$plugin_name"; then
                log_success "  $plugin (already installed)"
            else
                log_dry_run "  Would install: $plugin"
            fi
        done <<< "$plugins"
    fi
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

setup_krew() {
    if [[ "$DRY_RUN" == true ]]; then
        check_krew_dry_run
    else
        # Install krew itself
        install_krew
        
        # Install plugins from packages.yaml
        install_krew_plugins
    fi
}
