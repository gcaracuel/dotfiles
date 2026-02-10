#!/usr/bin/env bash
# asdf.sh - Setup asdf plugins and versions
# Idempotent: safe to run multiple times

# Source utils if not already sourced
if [[ -z "${UTILS_SOURCED:-}" ]]; then
    ASDF_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=utils.sh
    source "$ASDF_SCRIPT_DIR/utils.sh"
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

# Required asdf plugins (always installed, needed for npm/pip/cargo packages)
REQUIRED_ASDF_PLUGINS=(
    "nodejs"
    "python"
    "rust"
    "uv"
    "golang"
    "bun"
    "just"
)

# =============================================================================
# PACKAGE LOADING FROM YAML
# =============================================================================

# Load npm packages from packages.yaml into NPM_GLOBAL_PACKAGES array
# Returns: 0 on success (even if no packages), 1 if YAML file not found
load_npm_packages() {
    NPM_GLOBAL_PACKAGES=()
    
    if [[ ! -f "$PACKAGES_YAML" ]]; then
        return 1  # Indicate file not found
    fi
    
    if ! command -v yq &>/dev/null; then
        return 1  # Indicate yq not available
    fi
    
    local packages
    packages=$(yq -r '.npm[]?' "$PACKAGES_YAML" 2>/dev/null) || true
    
    if [[ -n "$packages" ]]; then
        while IFS= read -r package; do
            [[ -n "$package" ]] && NPM_GLOBAL_PACKAGES+=("$package")
        done <<< "$packages"
    fi
    
    return 0
}

# Load pip packages from packages.yaml into PIP_PACKAGES array
# Returns: 0 on success (even if no packages), 1 if YAML file not found
load_pip_packages() {
    PIP_PACKAGES=()
    
    if [[ ! -f "$PACKAGES_YAML" ]]; then
        return 1  # Indicate file not found
    fi
    
    if ! command -v yq &>/dev/null; then
        return 1  # Indicate yq not available
    fi
    
    local packages
    packages=$(yq -r '.pip[]?' "$PACKAGES_YAML" 2>/dev/null) || true
    
    if [[ -n "$packages" ]]; then
        while IFS= read -r package; do
            [[ -n "$package" ]] && PIP_PACKAGES+=("$package")
        done <<< "$packages"
    fi
    
    return 0
}

# Initialize package arrays (call before using NPM_GLOBAL_PACKAGES or PIP_PACKAGES)
NPM_GLOBAL_PACKAGES=()
PIP_PACKAGES=()

# =============================================================================
# ASDF FUNCTIONS
# =============================================================================

# Check if asdf is available
is_asdf_available() {
    command -v asdf &>/dev/null
}

# Get list of installed plugins
get_installed_plugins() {
    asdf plugin list 2>/dev/null || true
}

# Check if a plugin is installed
is_plugin_installed() {
    local plugin="$1"
    asdf plugin list 2>/dev/null | grep -q "^${plugin}$"
}

# Install a plugin (idempotent)
install_plugin() {
    local plugin="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        if is_plugin_installed "$plugin"; then
            log_success "$plugin plugin (already installed)"
        else
            log_dry_run "$plugin plugin (would install)"
        fi
        return 0
    fi
    
    log_step "Adding plugin: $plugin"
    
    # asdf plugin add is idempotent - returns 0 even if already installed
    local error_output
    if error_output=$(asdf plugin add "$plugin" 2>&1); then
        log_success "$plugin plugin ready"
    else
        # Check if it's just "already added" or a real error
        if echo "$error_output" | grep -qi "already installed\|already added"; then
            log_success "$plugin plugin ready (already installed)"
        else
            log_warning "Failed to add $plugin plugin"
            # Show error output (full if verbose, first 2 lines otherwise)
            if [[ "$VERBOSE" == true ]]; then
                echo "$error_output" | sed 's/^/  /' >&2
            else
                echo "$error_output" | head -2 | sed 's/^/  /' >&2
            fi
        fi
    fi
}

# Ensure Python build dependencies are installed
ensure_python_build_deps() {
    local os
    os=$(get_os)
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would install Python build dependencies (OpenSSL)"
        return 0
    fi
    
    log_step "Installing Python build dependencies..."
    
    if is_macos || [[ "$FORCE_BREW" == true ]]; then
        # On macOS/Homebrew, install openssl@3 via Homebrew
        # Don't check for 'openssl' command - it might be system OpenSSL which won't work
        if ! brew list openssl@3 &>/dev/null; then
            brew install openssl@3 || {
                log_warning "Failed to install openssl@3 - Python builds may fail"
                return 1
            }
            log_success "OpenSSL installed"
        else
            log_success "OpenSSL already installed"
        fi
    elif is_fedora; then
        # On Fedora, install development packages
        if ! rpm -q openssl-devel &>/dev/null; then
            sudo dnf install -y openssl-devel bzip2-devel libffi-devel readline-devel sqlite-devel zlib-devel || {
                log_warning "Failed to install Python build dependencies"
                return 1
            }
            log_success "Python build dependencies installed"
        else
            log_success "Python build dependencies already installed"
        fi
    elif is_generic_linux; then
        log_warning "Generic Linux detected - install Python build dependencies manually:"
        log_info "  Debian/Ubuntu: sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libffi-dev"
        log_info "  Arch: sudo pacman -S base-devel openssl zlib bzip2 readline sqlite libffi"
        return 1
    fi
    
    return 0
}

# Get OpenSSL environment variables for Python builds
get_python_build_env() {
    local os
    os=$(get_os)
    
    # Workaround for Python download issues with wget
    # See: https://github.com/asdf-community/asdf-python/issues/194
    export PYTHON_BUILD_HTTP_CLIENT=curl
    log_debug "Setting PYTHON_BUILD_HTTP_CLIENT=curl to avoid wget download issues"
    
    if is_macos || [[ "$FORCE_BREW" == true ]]; then
        # On macOS with Homebrew, set flags to find OpenSSL
        local openssl_prefix
        if openssl_prefix=$(brew --prefix openssl@3 2>/dev/null); then
            log_debug "Setting Python build environment for Homebrew OpenSSL: $openssl_prefix"
            export CFLAGS="-I${openssl_prefix}/include"
            export LDFLAGS="-L${openssl_prefix}/lib"
            export PKG_CONFIG_PATH="${openssl_prefix}/lib/pkgconfig"
        else
            log_warning "Could not get OpenSSL prefix from Homebrew - Python build may fail"
        fi
    fi
}

# Install versions from .tool-versions
install_versions() {
    local tool_versions="$HOME/.tool-versions"
    
    if [[ ! -f "$tool_versions" ]]; then
        log_info "No ~/.tool-versions file found - skipping version installation"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would install versions from ~/.tool-versions"
        return 0
    fi
    
    log_step "Installing versions from ~/.tool-versions"
    
    # Check if Python is in .tool-versions and ensure build deps are installed
    if grep -q "^python " "$tool_versions"; then
        ensure_python_build_deps
    fi
    
    # Try to install all versions, but track failures
    local failed_tools=()
    
    # Read .tool-versions and install each tool individually for better error reporting
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Extract plugin name and version
        local plugin version
        plugin=$(echo "$line" | awk '{print $1}')
        version=$(echo "$line" | awk '{print $2}')
        
        [[ -z "$plugin" || -z "$version" ]] && continue
        
        # Check if already installed
        if asdf list "$plugin" 2>/dev/null | grep -q "^[[:space:]]*${version}$"; then
            log_success "$plugin $version (already installed)"
            continue
        fi
        
        # Set environment variables for Python builds
        if [[ "$plugin" == "python" ]]; then
            get_python_build_env
            
            # For debugging: show what environment variables were set
            if [[ "$VERBOSE" == true ]]; then
                log_debug "Python build environment: CFLAGS=${CFLAGS:-not set} LDFLAGS=${LDFLAGS:-not set}"
            fi
        fi
        
        # Install this specific version
        log_step "Installing $plugin $version..."
        local error_output
        if error_output=$(asdf install "$plugin" "$version" 2>&1); then
            log_success "$plugin $version installed"
        else
            log_warning "Failed to install $plugin $version"
            failed_tools+=("$plugin $version")
            
            # Show error output (full if verbose, condensed otherwise)
            if [[ "$VERBOSE" == true ]]; then
                echo "$error_output" | sed 's/^/    /' >&2
            else
                # Show condensed error details - try to extract meaningful errors
                local error_summary
                error_summary=$(echo "$error_output" | grep -E "Error|ERROR|failed|Failed|ModuleNotFoundError|Missing|exit status" | head -5 | sed 's/^/    /')
                
                # If no specific errors found, show last 5 lines of output
                if [[ -z "$error_summary" ]]; then
                    error_summary=$(echo "$error_output" | tail -5 | sed 's/^/    /')
                fi
                
                if [[ -n "$error_summary" ]]; then
                    echo "$error_summary" >&2
                fi
            fi
            
        fi
    done < "$tool_versions"
    
    # Summary
    if [[ ${#failed_tools[@]} -gt 0 ]]; then
        echo ""
        log_warning "Failed to install ${#failed_tools[@]} tool(s):"
        for tool in "${failed_tools[@]}"; do
            echo "  - $tool" >&2
        done
        echo ""
        log_info "You can install these manually later with: asdf install <plugin> <version>"
    else
        log_success "All versions installed successfully"
    fi
    
    # Ensure shims are available after installing versions
    # asdf reshim updates shims for all installed versions
    if [[ -d "$HOME/.asdf/shims" ]]; then
        asdf reshim
        # Add shims to PATH if not already there
        if [[ ! "$PATH" =~ "$HOME/.asdf/shims" ]]; then
            export PATH="$HOME/.asdf/shims:$PATH"
        fi
    fi
}

# Get plugins from .tool-versions file
get_plugins_from_tool_versions() {
    local tool_versions="$HOME/.tool-versions"
    
    if [[ -f "$tool_versions" ]]; then
        # Extract plugin names (first column)
        awk '{print $1}' "$tool_versions" | sort -u
    fi
}

# =============================================================================
# NPM PACKAGES
# =============================================================================

# Check if npm is available (via asdf nodejs)
is_npm_available() {
    command -v npm &>/dev/null
}

# Check if an npm global package is installed
is_npm_package_installed() {
    local package="$1"
    npm list -g "$package" &>/dev/null
}

# Install npm global packages
install_npm_packages() {
    # Load packages from YAML
    if ! load_npm_packages; then
        log_warning "Cannot load npm packages (packages.yaml not found or yq not available)"
        return 0
    fi
    
    if [[ ${#NPM_GLOBAL_PACKAGES[@]} -eq 0 ]]; then
        echo ""
        log_info "  No npm packages defined in packages.yaml"
        return 0
    fi
    
    log_info "NPM global packages:"
    
    if ! is_npm_available; then
        log_warning "npm not available - install nodejs via asdf first"
        return 0
    fi
    
    local installed=0
    local would_install=0
    
    for package in "${NPM_GLOBAL_PACKAGES[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            if is_npm_package_installed "$package"; then
                log_success "$package (installed)"
                installed=$((installed + 1))
            else
                log_dry_run "$package (would install)"
                would_install=$((would_install + 1))
            fi
        else
            if is_npm_package_installed "$package"; then
                log_success "$package (already installed)"
                installed=$((installed + 1))
            else
                log_step "Installing npm package: $package"
                local error_output
                if error_output=$(npm install -g "$package" 2>&1); then
                    log_success "$package installed"
                    installed=$((installed + 1))
                else
                    log_warning "Failed to install $package"
                    # Show error output (full if verbose, first 3 lines otherwise)
                    if [[ "$VERBOSE" == true ]]; then
                        echo "$error_output" | sed 's/^/  /' >&2
                    else
                        local error_preview
                        error_preview=$(echo "$error_output" | head -3 | sed 's/^/  /')
                        echo "$error_preview" >&2
                    fi
                fi
            fi
        fi
    done
    
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        log_info "NPM summary: $installed installed, $would_install would install"
    fi
}

# =============================================================================
# PIP PACKAGES
# =============================================================================

# Check if pip/uv is available
is_pip_available() {
    command -v uv &>/dev/null || command -v pip &>/dev/null || command -v pip3 &>/dev/null
}

# Get the pip command to use (prefer uv, then pip3, then pip)
get_pip_command() {
    if command -v uv &>/dev/null; then
        echo "uv pip"
    elif command -v pip3 &>/dev/null; then
        echo "pip3"
    elif command -v pip &>/dev/null; then
        echo "pip"
    fi
}

# Check if a pip package is installed
is_pip_package_installed() {
    local package="$1"
    if command -v uv &>/dev/null; then
        uv pip show --system "$package" &>/dev/null
    elif command -v pip3 &>/dev/null; then
        pip3 show "$package" &>/dev/null
    else
        pip show "$package" &>/dev/null
    fi
}

# Install pip packages
install_pip_packages() {
    # Load packages from YAML
    if ! load_pip_packages; then
        log_warning "Cannot load pip packages (packages.yaml not found or yq not available)"
        return 0
    fi
    
    if [[ ${#PIP_PACKAGES[@]} -eq 0 ]]; then
        echo ""
        log_info "  No pip packages defined in packages.yaml"
        return 0
    fi
    
    log_info "Pip packages:"
    
    if ! is_pip_available; then
        log_warning "pip/uv not available - install python via asdf first"
        return 0
    fi
    
    local pip_cmd
    pip_cmd=$(get_pip_command)
    local installed=0
    local would_install=0
    
    for package in "${PIP_PACKAGES[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            if is_pip_package_installed "$package"; then
                log_success "$package (installed)"
                installed=$((installed + 1))
            else
                log_dry_run "$package (would install via $pip_cmd)"
                would_install=$((would_install + 1))
            fi
        else
            if is_pip_package_installed "$package"; then
                log_success "$package (already installed)"
                installed=$((installed + 1))
            else
                log_step "Installing pip package: $package"
                local error_output
                # Use --system flag for uv to install globally (not in venv)
                local install_success=false
                if [[ "$pip_cmd" == "uv pip" ]]; then
                    if error_output=$(uv pip install --system "$package" 2>&1); then
                        install_success=true
                    fi
                else
                    if error_output=$($pip_cmd install "$package" 2>&1); then
                        install_success=true
                    fi
                fi
                
                if [[ "$install_success" == true ]]; then
                    log_success "$package installed"
                    installed=$((installed + 1))
                else
                    log_warning "Failed to install $package"
                    # Show error output (full if verbose, first 3 lines otherwise)
                    if [[ "$VERBOSE" == true ]]; then
                        echo "$error_output" | sed 's/^/  /' >&2
                    else
                        local error_preview
                        error_preview=$(echo "$error_output" | head -3 | sed 's/^/  /')
                        echo "$error_preview" >&2
                    fi
                fi
            fi
        fi
    done
    
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        log_info "Pip summary: $installed installed, $would_install would install"
    fi
}

# =============================================================================
# CARGO PACKAGES (Rust CLI tools)
# =============================================================================

# Check if cargo is available (via asdf rust)
is_cargo_available() {
    command -v cargo &>/dev/null
}

# Check if a cargo package is installed
is_cargo_package_installed() {
    local package="$1"
    cargo install --list 2>/dev/null | grep -q "^${package}\b"
}

# Check if bun is available in PATH
is_bun_available() {
    command -v bun &>/dev/null
}

# Check if a bun package is installed globally
is_bun_package_installed() {
    local package="$1"
    bun pm ls -g 2>/dev/null | grep -q "^  $package@"
}

# Load cargo packages from packages.yaml into CARGO_PACKAGES array
# Returns: 0 on success (even if no packages), 1 if YAML file not found
load_cargo_packages() {
    CARGO_PACKAGES=()
    
    if [[ ! -f "$PACKAGES_YAML" ]]; then
        return 1  # Indicate file not found
    fi
    
    if ! command -v yq &>/dev/null; then
        return 1  # Indicate yq not available
    fi
    
    local packages
    packages=$(yq -r '.cargo[]?' "$PACKAGES_YAML" 2>/dev/null) || true
    
    if [[ -n "$packages" ]]; then
        while IFS= read -r package; do
            [[ -n "$package" ]] && CARGO_PACKAGES+=("$package")
        done <<< "$packages"
    fi
    
    return 0
}

# Initialize CARGO_PACKAGES array
CARGO_PACKAGES=()

# Load bun packages from packages.yaml into BUN_PACKAGES array
# Returns: 0 on success (even if no packages), 1 if YAML file not found
load_bun_packages() {
    BUN_PACKAGES=()
    
    if [[ ! -f "$PACKAGES_YAML" ]]; then
        return 1  # Indicate file not found
    fi
    
    if ! command -v yq &>/dev/null; then
        return 1  # Indicate yq not available
    fi
    
    local packages
    packages=$(yq -r '.bun[]?' "$PACKAGES_YAML" 2>/dev/null) || true
    
    if [[ -n "$packages" ]]; then
        while IFS= read -r package; do
            [[ -n "$package" ]] && BUN_PACKAGES+=("$package")
        done <<< "$packages"
    fi
    
    return 0
}

# Initialize BUN_PACKAGES array
BUN_PACKAGES=()

# Install cargo packages
install_cargo_packages() {
    # Load packages from YAML
    if ! load_cargo_packages; then
        log_warning "Cannot load cargo packages (packages.yaml not found or yq not available)"
        return 0
    fi
    
    if [[ ${#CARGO_PACKAGES[@]} -eq 0 ]]; then
        echo ""
        log_info "  No cargo packages defined in packages.yaml"
        return 0
    fi
    
    log_info "Cargo packages:"
    
    if ! is_cargo_available; then
        log_warning "cargo not available - install rust via asdf first"
        return 0
    fi
    
    local installed=0
    local would_install=0
    
    for package in "${CARGO_PACKAGES[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            if is_cargo_package_installed "$package"; then
                log_success "$package (installed)"
                installed=$((installed + 1))
            else
                log_dry_run "$package (would install via cargo)"
                would_install=$((would_install + 1))
            fi
        else
            if is_cargo_package_installed "$package"; then
                log_success "$package (already installed)"
                installed=$((installed + 1))
            else
                log_step "Installing cargo package: $package"
                local error_output
                if error_output=$(cargo install "$package" 2>&1); then
                    log_success "$package installed"
                    installed=$((installed + 1))
                else
                    log_warning "Failed to install $package"
                    # Show first 3 lines of error for context
                    local error_preview
                    error_preview=$(echo "$error_output" | head -3 | sed 's/^/  /')
                    echo "$error_preview" >&2
                fi
            fi
        fi
    done
    
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        log_info "Cargo summary: $installed installed, $would_install would install"
    fi
}

# Install bun packages
install_bun_packages() {
    # Load packages from YAML
    if ! load_bun_packages; then
        log_warning "Cannot load bun packages (packages.yaml not found or yq not available)"
        return 0
    fi
    
    if [[ ${#BUN_PACKAGES[@]} -eq 0 ]]; then
        echo ""
        log_info "  No bun packages defined in packages.yaml"
        return 0
    fi
    
    log_info "Bun packages:"
    
    if ! is_bun_available; then
        log_warning "bun not available - install bun via asdf first"
        return 0
    fi
    
    local installed=0
    local would_install=0
    
    for package in "${BUN_PACKAGES[@]}"; do
        if [[ "$DRY_RUN" == true ]]; then
            if is_bun_package_installed "$package"; then
                log_success "$package (installed)"
                installed=$((installed + 1))
            else
                log_dry_run "$package (would install via bun)"
                would_install=$((would_install + 1))
            fi
        else
            if is_bun_package_installed "$package"; then
                log_success "$package (already installed)"
                installed=$((installed + 1))
            else
                log_step "Installing bun package: $package"
                local error_output
                if error_output=$(bun install -g "$package" 2>&1); then
                    log_success "$package installed"
                    installed=$((installed + 1))
                else
                    log_warning "Failed to install $package"
                    # Show first 3 lines of error for context
                    local error_preview
                    error_preview=$(echo "$error_output" | head -3 | sed 's/^/  /')
                    echo "$error_preview" >&2
                fi
            fi
        fi
    done
    
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        log_info "  Bun summary: $installed installed, $would_install would install"
    fi
}

# =============================================================================
# UV TOOLS (isolated CLI tools via uv tool install)
# =============================================================================

# Check if uv is available
is_uv_available() {
    command -v uv &>/dev/null
}

# Check if a uv tool is installed
is_uv_tool_installed() {
    local tool_name="$1"
    uv tool list 2>/dev/null | grep -q "^${tool_name}\b"
}

# Load uv tools from packages.yaml into UV_TOOLS array
# Each element is "name|from" format
# Returns: 0 on success (even if no tools), 1 if YAML file not found
load_uv_tools() {
    UV_TOOLS=()
    
    if [[ ! -f "$PACKAGES_YAML" ]]; then
        return 1  # Indicate file not found
    fi
    
    if ! command -v yq &>/dev/null; then
        return 1  # Indicate yq not available
    fi
    
    # Get count of uv_tools entries
    local count
    count=$(yq '.uv_tools | length' "$PACKAGES_YAML" 2>/dev/null) || count=0
    
    if [[ "$count" -eq 0 || "$count" == "null" ]]; then
        return 0
    fi
    
    # Read each tool entry
    local i=0
    while [[ $i -lt $count ]]; do
        local name from
        name=$(yq ".uv_tools[$i].name" "$PACKAGES_YAML" 2>/dev/null) || true
        from=$(yq ".uv_tools[$i].from" "$PACKAGES_YAML" 2>/dev/null) || true
        
        if [[ -n "$name" && -n "$from" && "$name" != "null" && "$from" != "null" ]]; then
            UV_TOOLS+=("${name}|${from}")
        fi
        i=$((i + 1))
    done
    
    return 0
}

# Initialize UV_TOOLS array
UV_TOOLS=()

# Install uv tools
install_uv_tools() {
    # Load tools from YAML
    if ! load_uv_tools; then
        log_warning "Cannot load uv tools (packages.yaml not found or yq not available)"
        return 0
    fi
    
    if [[ ${#UV_TOOLS[@]} -eq 0 ]]; then
        echo ""
        log_info "  No uv tools defined in packages.yaml"
        return 0
    fi
    
    log_info "UV tools:"
    
    if ! is_uv_available; then
        log_warning "uv not available - install uv via asdf first"
        return 0
    fi
    
    local installed=0
    local would_install=0
    
    for entry in "${UV_TOOLS[@]}"; do
        local name="${entry%%|*}"
        local from="${entry#*|}"
        
        if [[ "$DRY_RUN" == true ]]; then
            if is_uv_tool_installed "$name"; then
                log_success "$name (installed)"
                installed=$((installed + 1))
            else
                log_dry_run "$name (would install from $from)"
                would_install=$((would_install + 1))
            fi
        else
            if is_uv_tool_installed "$name"; then
                log_success "$name (already installed)"
                installed=$((installed + 1))
            else
                log_step "Installing uv tool: $name"
                local error_output
                if error_output=$(uv tool install "$name" --from "$from" 2>&1); then
                    log_success "$name installed"
                    installed=$((installed + 1))
                else
                    log_warning "Failed to install $name"
                    # Show first 3 lines of error for context
                    local error_preview
                    error_preview=$(echo "$error_output" | head -3 | sed 's/^/  /')
                    echo "$error_preview" >&2
                fi
            fi
        fi
    done
    
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        log_info "UV tools summary: $installed installed, $would_install would install"
    fi
}

# =============================================================================
# MAIN ASDF SETUP
# =============================================================================

setup_asdf() {
    log_header "Setting up asdf"
    
    # Ensure asdf is in PATH for this session (if installed but not in PATH)
    if [[ -d "$HOME/.asdf/bin" ]] && [[ ! "$PATH" =~ "$HOME/.asdf/bin" ]]; then
        export PATH="$HOME/.asdf/bin:$PATH"
    fi
    
    # Ensure asdf shims are in PATH for this session (needed for installed tools)
    if [[ -d "$HOME/.asdf/shims" ]] && [[ ! "$PATH" =~ "$HOME/.asdf/shims" ]]; then
        export PATH="$HOME/.asdf/shims:$PATH"
    fi
    
    if ! is_asdf_available; then
        log_warning "asdf is not installed or not in PATH"
        log_info "Install asdf first, then run this script again"
        return 0
    fi
    
    # Combine required plugins with those from .tool-versions
    local plugins_to_install=()
    local seen_plugins=()
    
    # Always include required plugins first
    for plugin in "${REQUIRED_ASDF_PLUGINS[@]}"; do
        plugins_to_install+=("$plugin")
        seen_plugins+=("$plugin")
    done
    
    # Add any additional plugins from .tool-versions
    local tool_versions_plugins
    tool_versions_plugins=$(get_plugins_from_tool_versions)
    
    if [[ -n "$tool_versions_plugins" ]]; then
        while IFS= read -r plugin; do
            if [[ -n "$plugin" ]]; then
                # Check if already in list
                local found=false
                for seen in "${seen_plugins[@]}"; do
                    if [[ "$seen" == "$plugin" ]]; then
                        found=true
                        break
                    fi
                done
                if [[ "$found" == false ]]; then
                    plugins_to_install+=("$plugin")
                fi
            fi
        done <<< "$tool_versions_plugins"
    fi
    
    log_info "Plugins to install: ${plugins_to_install[*]}"
    
    # Install plugins
    for plugin in "${plugins_to_install[@]}"; do
        install_plugin "$plugin"
    done
    
    # Install versions from .tool-versions
    install_versions
    
    echo ""
    
    # Reshim nodejs to make npm available in PATH
    if is_asdf_available && is_plugin_installed "nodejs"; then
        log_debug "Reshimming nodejs to update PATH with npm"
        asdf reshim nodejs &>/dev/null || true
    fi
    
    # Install npm global packages
    install_npm_packages
    echo ""
    
    # Reshim python to make pip available in PATH
    if is_asdf_available && is_plugin_installed "python"; then
        log_debug "Reshimming python to update PATH with pip"
        asdf reshim python &>/dev/null || true
    fi
    
    # Install pip packages
    install_pip_packages
    echo ""
    
    # Reshim rust to make cargo available in PATH
    if is_asdf_available && is_plugin_installed "rust"; then
        log_debug "Reshimming rust to update PATH with cargo"
        asdf reshim rust &>/dev/null || true
    fi
    
    # Install cargo packages
    install_cargo_packages
    echo ""
    
    # Reshim bun to make bun available in PATH
    if is_asdf_available && is_plugin_installed "bun"; then
        log_debug "Reshimming bun to update PATH with bun"
        asdf reshim bun &>/dev/null || true
    fi
    
    # Install bun packages
    install_bun_packages
    echo ""
    
    # Reshim uv to make uv available in PATH
    if is_asdf_available && is_plugin_installed "uv"; then
        log_debug "Reshimming uv to update PATH with uv"
        asdf reshim uv &>/dev/null || true
    fi
    
    # Install uv tools
    install_uv_tools
    
    log_success "asdf setup complete"
}

# =============================================================================
# DRY-RUN CHECK
# =============================================================================

check_asdf_dry_run() {
    log_header "ASDF"
    
    if ! is_asdf_available; then
        log_warning "asdf not available - will be configured after packages are installed"
        return 0
    fi
    
    local tool_versions="$HOME/.tool-versions"
    
    # Combine required plugins with those from .tool-versions
    local plugins_to_install=()
    local seen_plugins=()
    
    # Always include required plugins first
    for plugin in "${REQUIRED_ASDF_PLUGINS[@]}"; do
        plugins_to_install+=("$plugin")
        seen_plugins+=("$plugin")
    done
    
    # Add any additional plugins from .tool-versions
    local tool_versions_plugins
    tool_versions_plugins=$(get_plugins_from_tool_versions)
    
    if [[ -n "$tool_versions_plugins" ]]; then
        while IFS= read -r plugin; do
            if [[ -n "$plugin" ]]; then
                local found=false
                for seen in "${seen_plugins[@]}"; do
                    if [[ "$seen" == "$plugin" ]]; then
                        found=true
                        break
                    fi
                done
                if [[ "$found" == false ]]; then
                    plugins_to_install+=("$plugin")
                fi
            fi
        done <<< "$tool_versions_plugins"
    fi
    
    log_info "Plugins (required + from ~/.tool-versions):"
    echo ""
    for plugin in "${plugins_to_install[@]}"; do
        if is_plugin_installed "$plugin"; then
            log_success "$plugin (installed)"
        else
            log_dry_run "$plugin (would install)"
        fi
    done
    
    echo ""
    if [[ -f "$tool_versions" ]]; then
        log_info "Versions from ~/.tool-versions:"
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            log_info "  $line"
        done < "$tool_versions"
    else
        log_info "No ~/.tool-versions file - versions will not be installed"
    fi
    
    echo ""
    install_npm_packages
    
    echo ""
    install_pip_packages
    
    echo ""
    install_cargo_packages
    
    echo ""
    install_bun_packages
    
    echo ""
    install_uv_tools
}
