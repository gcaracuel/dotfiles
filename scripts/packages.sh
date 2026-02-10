#!/usr/bin/env bash
# packages.sh - Install packages from packages.yaml
# Parses YAML and installs packages via appropriate package manager

# Source utils if not already sourced
if [[ -z "${UTILS_SOURCED:-}" ]]; then
    PACKAGES_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=utils.sh
    source "$PACKAGES_SCRIPT_DIR/utils.sh"
fi

# =============================================================================
# PACKAGE TRACKING
# =============================================================================

# Track packages that were already installed before this run
# This allows us to show "installed" vs "already installed" correctly
declare -g -A PACKAGES_BEFORE_RUN

# Snapshot currently installed packages (call this before installing anything)
snapshot_installed_packages() {
    local package_list="$1"  # Newline or space-separated list of packages to check
    
    # Handle both newline-separated and space-separated lists
    while IFS= read -r package; do
        [[ -z "$package" ]] && continue
        
        if is_macos && command_exists brew; then
            if brew list "$package" &>/dev/null; then
                PACKAGES_BEFORE_RUN["$package"]=1
            fi
        elif is_linux && command_exists dnf; then
            if rpm -q "$package" &>/dev/null; then
                PACKAGES_BEFORE_RUN["$package"]=1
            fi
        fi
    done <<< "$package_list"
}

# Check if a package was already installed before this run
was_already_installed() {
    local package="$1"
    [[ -n "${PACKAGES_BEFORE_RUN[$package]:-}" ]]
}

# =============================================================================
# YAML PARSING
# =============================================================================

# Get packages from YAML for a specific path (e.g., macos.personal.cli)
# For macOS, returns simple package names
# For Linux CLI, returns JSON that may contain distro-specific names
get_packages_raw() {
    local yaml_path="$1"
    
    if [[ ! -f "$PACKAGES_YAML" ]]; then
        die "packages.yaml not found at $PACKAGES_YAML"
    fi
    
    # Return each array element as compact JSON (preserves objects)
    # -o=json -I=0 gives compact one-line JSON output per element
    yq -o=json -I=0 ".$yaml_path // [] | .[]?" "$PACKAGES_YAML" 2>/dev/null || true
}

# Get packages as simple strings (for macOS and Linux GUI/Flatpak)
get_packages() {
    local yaml_path="$1"
    
    if [[ ! -f "$PACKAGES_YAML" ]]; then
        die "packages.yaml not found at $PACKAGES_YAML"
    fi
    
    # Extract array as newline-separated values (removes quotes from strings)
    yq ".$yaml_path // [] | .[]?" "$PACKAGES_YAML" 2>/dev/null || true
}

# Get package count for a path
get_package_count() {
    local yaml_path="$1"
    local count
    count=$(yq ".$yaml_path // [] | length" "$PACKAGES_YAML" 2>/dev/null || echo "0")
    echo "$count"
}

# Resolve a Linux CLI package entry to the correct package name for the current distro
# Input: JSON string (could be simple string or object with dnf/brew keys)
# Output: package name for current distro, or empty if not applicable
resolve_linux_package() {
    local entry="$1"
    local distro_key=""
    
    # Determine which key to use based on distro
    if is_fedora; then
        distro_key="dnf"
    else
        # Default to dnf for other Linux
        distro_key="dnf"
    fi
    
    # Check if entry is a simple string (starts with quote) or object (starts with brace)
    if [[ "$entry" == "{"* ]]; then
        # It's an object - extract the distro-specific package name
        # Use -p=json to tell yq the input is JSON format
        local package
        package=$(echo "$entry" | yq -p=json ".$distro_key" 2>/dev/null)
        # yq returns "null" for missing keys, convert to empty
        [[ "$package" == "null" ]] && package=""
        echo "$package"
    else
        # It's a simple string - remove quotes and return
        echo "$entry" | tr -d '"'
    fi
}

# =============================================================================
# UNIFIED PACKAGE SCHEMA FUNCTIONS
# =============================================================================

# Get unified packages filtered by gui/work flags
# Returns: Array of package entries (one per line, format: name|description|gui|work|macos_override|linux_override)
get_unified_packages() {
    local packages_file="$1"
    
    log_debug "get_unified_packages called with: $packages_file"
    
    if [[ ! -f "$packages_file" ]]; then
        log_debug "Package file not found: $packages_file"
        return 1
    fi
    
    log_debug "INCLUDE_WORK=$INCLUDE_WORK"
    
    # Build selection filter based on flags  
    local select_filter='true'
    
    if [[ "$INCLUDE_WORK" == false ]]; then
        select_filter='(.work == false)'
    fi
    
    log_debug "Filter: $select_filter"
    
    # Output format: name|description|gui|work|macos_override|linux_override
    # Note: We use a single yq call that outputs all fields at once to avoid duplicate
    # processing when package names are not unique (e.g., alacritty appears twice with
    # different OS overrides). We output TSV format and convert to pipe-delimited.
    # For overrides: "NOOVERRIDES" = no overrides field OR field not present, "null" = explicitly null, "value" = override value
    
    # Get raw TSV output from yq
    # Note: Different yq versions have different syntax. We'll use a simpler approach.
    # Instead of complex conditionals, we'll handle the overrides after extraction.
    local tsv_output
    local yq_error
    yq_error=$(mktemp)
    
    # Simpler query that works with both yq versions
    tsv_output=$(yq -r '.packages[]? | select('"$select_filter"') | [.name, .description, .gui, .work, (.overrides.macos // "NOOVERRIDES"), (.overrides.linux // "NOOVERRIDES")] | @tsv' "$packages_file" 2>"$yq_error")
    local yq_exit_code=$?
    
    if [[ $yq_exit_code -ne 0 ]]; then
        log_debug "yq command failed with exit code: $yq_exit_code"
        log_debug "yq error output: $(cat "$yq_error")"
    fi
    rm -f "$yq_error"
    
    log_debug "TSV output length: ${#tsv_output}"
    log_debug "TSV first line: $(echo "$tsv_output" | head -1)"
    
    # Convert TSV to pipe-delimited format
    if [[ -n "$tsv_output" ]]; then
        while IFS=$'\t' read -r name desc gui work mac_override linux_override; do
            # Handle cases where yq returns "null" string for null values
            [[ "$mac_override" == "null" ]] && mac_override="null"
            [[ "$linux_override" == "null" ]] && linux_override="null"
            echo "$name|$desc|$gui|$work|$mac_override|$linux_override"
        done <<< "$tsv_output"
    else
        log_debug "TSV output is empty!"
    fi
}

# Resolve package name for current OS
# Args: $1=name, $2=macos_override, $3=linux_override
# Returns: Resolved package name or empty string if null override (skip package)
resolve_package_name() {
    local name="$1"
    local macos_override="$2"
    local linux_override="$3"
    local os
    os=$(get_os)
    
    if [[ "$os" == "macos" ]]; then
        # Check if explicitly set to null in YAML (yq returns "null" string)
        if [[ "$macos_override" == "null" ]]; then
            echo ""  # Skip on macOS
        elif [[ "$macos_override" == "NOOVERRIDES" || -z "$macos_override" ]]; then
            # No override field or empty, use default name
            echo "$name"
        else
            # Has an override value
            echo "$macos_override"
        fi
    elif [[ "$os" == linux* ]]; then
        # Check if explicitly set to null in YAML (yq returns "null" string)
        if [[ "$linux_override" == "null" ]]; then
            echo ""  # Skip on Linux
        elif [[ "$linux_override" == "NOOVERRIDES" || -z "$linux_override" ]]; then
            # No override field or empty, use default name
            echo "$name"
        else
            # Has an override value
            echo "$linux_override"
        fi
    fi
}

# Install single macOS brew package
install_macos_package_brew() {
    local package="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        if brew list --formula "$package" &>/dev/null; then
            log_info "  ✓ $package (already installed)"
        else
            log_dry_run "  [DRY-RUN] $package (would install)"
        fi
        return 0
    fi
    
    if brew list --formula "$package" &>/dev/null; then
        log_success "  ✓ $package (already installed)"
    else
        log_step "→ Installing $package..."
        if brew install "$package" &>/dev/null; then
            log_success "$package installed"
        else
            log_warning "  ✗ Failed to install $package"
        fi
    fi
}

# Install single macOS cask package
install_macos_package_cask() {
    local package="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        if brew list --cask "$package" &>/dev/null; then
            log_info "  ✓ $package (already installed)"
        else
            log_dry_run "  [DRY-RUN] $package (would install)"
        fi
        return 0
    fi
    
    if brew list --cask "$package" &>/dev/null; then
        log_success "  ✓ $package (already installed)"
    else
        log_step "→ Installing $package [cask]..."
        if brew install --cask "$package" &>/dev/null; then
            log_success "$package installed"
        else
            log_warning "  ✗ Failed to install $package"
        fi
    fi
}

# Install single Linux DNF package
install_linux_package_dnf() {
    local package="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        if rpm -q "$package" &>/dev/null; then
            log_info "  ✓ $package (already installed)"
        else
            log_dry_run "  [DRY-RUN] $package (would install)"
        fi
        return 0
    fi
    
    if rpm -q "$package" &>/dev/null; then
        log_success "  ✓ $package (already installed)"
    else
        log_step "→ Installing $package..."
        # Redirect stdin to /dev/null to prevent sudo/dnf from consuming the while loop's input
        if sudo dnf install -y "$package" </dev/null &>/dev/null; then
            log_success "$package installed"
        else
            log_warning "  ✗ Failed to install $package"
        fi
    fi
}

# Install single Linux Flatpak package
install_linux_package_flatpak() {
    local package="$1"  # Flatpak ID (e.g., com.spotify.Client)
    local description="$2"
    
    if ! command_exists flatpak; then
        log_warning "  ✗ Flatpak not available, skipping $package"
        return 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        if flatpak list --app 2>/dev/null | grep -q "$package"; then
            log_info "  ✓ $package (already installed)"
        else
            log_dry_run "  [DRY-RUN] $package (would install)"
        fi
        return 0
    fi
    
    if flatpak list --app 2>/dev/null | grep -q "$package"; then
        log_success "  ✓ $package (already installed)"
    else
        log_step "→ Installing $package [flatpak]..."
        if flatpak install -y flathub "$package" </dev/null &>/dev/null; then
            log_success "$package installed"
        else
            log_warning "  ✗ Failed to install $package"
        fi
    fi
}

# Install packages from unified schema
install_unified_packages() {
    local packages_file="$1"
    local os
    os=$(get_os)
    
    log_header "Installing packages"
    
    # Show filter status
    if [[ "$INCLUDE_WORK" == true ]]; then
        log_info "Filter: --work (including work packages)"
    fi
    echo ""
    
    # Get filtered packages
    local packages
    packages=$(get_unified_packages "$packages_file")
    
    log_debug "get_unified_packages returned: '$packages'"
    log_debug "Package count: $(echo "$packages" | wc -l)"
    
    if [[ -z "$packages" ]]; then
        log_info "No packages to install (filtered by --work flag)"
        return 0
    fi
    
    local cli_count=0
    local gui_count=0
    local skip_count=0
    
    log_debug "Starting package loop..."
    log_debug "First few lines of packages: $(echo "$packages" | head -3)"
    
    # Parse each package entry
    # Use process substitution to avoid stdin consumption by commands inside the loop
    while IFS='|' read -r name description gui work macos_override linux_override; do
        log_debug "Processing package: $name (gui='$gui', work='$work', os='$os')"
        log_debug "  macos_override='$macos_override', linux_override='$linux_override'"
        
        # Resolve package name for current OS
        local resolved_name
        resolved_name=$(resolve_package_name "$name" "$macos_override" "$linux_override")
        log_debug "  Resolved name for $name: '$resolved_name'"
        
        # Skip if null override for this OS
        if [[ -z "$resolved_name" ]]; then
            skip_count=$((skip_count + 1))
            log_debug "Skipping $name - not available on $os"
            if [[ "$DRY_RUN" == true ]]; then
                log_info "  ✗ $name (not available on $os)"
            fi
            continue
        fi
        
        log_debug "  About to enter OS-specific install logic (os='$os', gui='$gui')"
        
        # Determine installation method based on OS and gui flag
        if [[ "$os" == "macos" ]]; then
            if [[ "$gui" == "true" ]]; then
                log_debug "  → Installing macOS cask: $resolved_name"
                install_macos_package_cask "$resolved_name" "$description"
                gui_count=$((gui_count + 1))
            else
                log_debug "  → Installing macOS brew formula: $resolved_name"
                install_macos_package_brew "$resolved_name" "$description"
                cli_count=$((cli_count + 1))
            fi
        elif [[ "$os" == linux* ]]; then
            if [[ "$gui" == "true" ]]; then
                log_debug "  → Installing Linux flatpak: $resolved_name"
                install_linux_package_flatpak "$resolved_name" "$description"
                gui_count=$((gui_count + 1))
            else
                log_debug "  → Installing Linux DNF package: $resolved_name"
                install_linux_package_dnf "$resolved_name" "$description"
                cli_count=$((cli_count + 1))
            fi
        fi
    done < <(echo "$packages")
    
    # Summary
    echo ""
    log_success "Package installation complete"
    log_info "Installed: $cli_count CLI, $gui_count GUI | Skipped: $skip_count"
}

# =============================================================================
# OLD FUNCTIONS (KEPT FOR NOW, WILL BE REPLACED BY UNIFIED FUNCTIONS)
# =============================================================================

# Resolve a Linux CLI package entry to the correct package name for the current distro
# Input: JSON string (could be simple string or object with dnf/brew keys)
# Output: package name for current distro, or empty if not applicable
resolve_linux_package_old() {
    local entry="$1"
    local distro_key=""
    
    # Determine which key to use based on distro
    if is_fedora; then
        distro_key="dnf"
    else
        # Default to dnf for other Linux
        distro_key="dnf"
    fi
    
    # Check if entry is a simple string (starts with quote) or object (starts with brace)
    if [[ "$entry" == "{"* ]]; then
        # It's an object - extract the distro-specific package name
        # Use -p=json to tell yq the input is JSON format
        local package
        package=$(echo "$entry" | yq -p=json ".$distro_key" 2>/dev/null)
        # yq returns "null" for missing keys, convert to empty
        [[ "$package" == "null" ]] && package=""
        echo "$package"
    else
        # It's a simple string - remove quotes and return
        echo "$entry" | tr -d '"'
    fi
}

# =============================================================================
# MACOS INSTALLATION (Homebrew)
# =============================================================================

# Check if a brew formula is installed
is_brew_formula_installed() {
    local formula="$1"
    brew list --formula "$formula" &>/dev/null
}

# Check if a brew cask is installed
is_brew_cask_installed() {
    local cask="$1"
    brew list --cask "$cask" &>/dev/null
}

# Install a single brew formula
install_brew_formula() {
    local formula="$1"
    
    if is_brew_formula_installed "$formula"; then
        # Check if it was already there before this run
        if was_already_installed "$formula"; then
            log_success "$formula (already installed)"
        else
            log_success "$formula installed"
        fi
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "$formula would be installed"
        return 0
    fi
    
    log_step "Installing $formula..."
    
    if brew install "$formula" 2>&1; then
        log_success "$formula installed"
    else
        die "Failed to install $formula" \
            "Try running: brew install $formula"
    fi
}

# Install a single brew cask
install_brew_cask() {
    local cask="$1"
    
    if is_brew_cask_installed "$cask"; then
        # Check if it was already there before this run
        if was_already_installed "$cask"; then
            log_success "$cask (already installed)"
        else
            log_success "$cask installed"
        fi
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "$cask would be installed"
        return 0
    fi
    
    log_step "Installing $cask..."
    
    if brew install --cask "$cask" 2>&1; then
        log_success "$cask installed"
    else
        die "Failed to install $cask" \
            "Try running: brew install --cask $cask"
    fi
}

# Install all macOS CLI packages
install_macos_cli() {
    local category="$1"  # personal or work
    local packages
    
    packages=$(get_packages "macos.$category.cli")
    
    if [[ -z "$packages" ]]; then
        log_info "No CLI packages defined for macos.$category.cli"
        return 0
    fi
    
    local count
    count=$(get_package_count "macos.$category.cli")
    log_info "CLI packages ($count total)"
    
    # Snapshot what's already installed before we start
    snapshot_installed_packages "$packages"
    
    while IFS= read -r package; do
        [[ -z "$package" ]] && continue
        install_brew_formula "$package"
    done <<< "$packages"
}

# Install all macOS GUI packages
install_macos_gui() {
    local category="$1"  # personal or work
    local packages
    
    # Skip casks in containers (require actual macOS)
    if is_container; then
        log_warning "Skipping cask packages (running in container)"
        return 0
    fi
    
    packages=$(get_packages "macos.$category.gui")
    
    if [[ -z "$packages" ]]; then
        log_info "No GUI packages defined for macos.$category.gui"
        return 0
    fi
    
    local count
    count=$(get_package_count "macos.$category.gui")
    log_info "GUI packages ($count total)"
    
    # Snapshot what's already installed before we start
    snapshot_installed_packages "$packages"
    
    while IFS= read -r package; do
        [[ -z "$package" ]] && continue
        install_brew_cask "$package"
    done <<< "$packages"
}

# =============================================================================
# LINUX INSTALLATION (DNF + Flatpak)
# =============================================================================

# Check if a DNF package is installed
is_dnf_package_installed() {
    local package="$1"
    rpm -q "$package" &>/dev/null
}

# Check if a Linux CLI package is installed (auto-detects distro)
is_linux_package_installed() {
    local package="$1"
    
    if is_fedora; then
        is_dnf_package_installed "$package"
    else
        return 1
    fi
}

# Check if a Flatpak app is installed
is_flatpak_installed() {
    local app_id="$1"
    # Suppress errors if flatpak isn't available (e.g., in dry-run before prerequisites)
    flatpak list --app 2>/dev/null | grep -q "$app_id"
}

# Install a single DNF package
install_dnf_package() {
    local package="$1"
    
    if is_dnf_package_installed "$package"; then
        # Check if it was already there before this run
        if was_already_installed "$package"; then
            log_success "$package (already installed)"
        else
            log_success "$package installed"
        fi
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "$package would be installed"
        return 0
    fi
    
    log_step "Installing $package..."
    
    if sudo dnf install -y "$package" 2>&1; then
        log_success "$package installed"
    else
        die "Failed to install $package" \
            "Try running: sudo dnf install $package"
    fi
}

# Install a Linux CLI package (auto-detects distro)
install_linux_package() {
    local package="$1"
    
    if is_fedora; then
        install_dnf_package "$package"
    elif is_generic_linux; then
        log_warning "Package '$package' skipped (non-Fedora Linux)"
        log_info "Use --force-brew or install manually"
    else
        die "Unsupported Linux distribution for package installation" \
            "Try using --force-brew flag to install via Homebrew on Linux"
    fi
}

# Install a single Flatpak app
install_flatpak_app() {
    local app_id="$1"
    
    if is_flatpak_installed "$app_id"; then
        # Check if it was already there before this run
        if was_already_installed "$app_id"; then
            log_success "$app_id (already installed)"
        else
            log_success "$app_id installed"
        fi
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "$app_id would be installed"
        return 0
    fi
    
    log_step "Installing $app_id..."
    
    if flatpak install -y flathub "$app_id" 2>&1; then
        log_success "$app_id installed"
    else
        die "Failed to install flatpak $app_id" \
            "Try running: flatpak install flathub $app_id"
    fi
}

# Install all Linux CLI packages (handles distro-specific package names)
install_linux_cli() {
    local category="$1"  # personal or work
    local entries
    
    entries=$(get_packages_raw "linux.$category.cli")
    
    if [[ -z "$entries" ]]; then
        log_info "No CLI packages defined for linux.$category.cli"
        return 0
    fi
    
    local count
    count=$(get_package_count "linux.$category.cli")
    local distro_name="DNF"
    log_info "CLI packages ($count total, using $distro_name)"
    
    # First pass: resolve all packages and snapshot what's installed
    local resolved_packages=()
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        
        # Resolve to correct package name for this distro
        local package
        package=$(resolve_linux_package "$entry")
        
        if [[ -n "$package" ]]; then
            resolved_packages+=("$package")
        fi
    done <<< "$entries"
    
    # Snapshot what's already installed before we start
    snapshot_installed_packages "${resolved_packages[*]}"
    
    # Second pass: actually install
    for package in "${resolved_packages[@]}"; do
        install_linux_package "$package"
    done
}

# Install all Linux GUI packages (Flatpak - universal across distros)
install_linux_gui() {
    local category="$1"  # personal or work
    local packages
    
    # Skip Flatpak in containers (D-Bus not available)
    if is_container; then
        log_warning "Skipping Flatpak packages (running in container)"
        return 0
    fi
    
    packages=$(get_packages "linux.$category.gui")
    
    if [[ -z "$packages" ]]; then
        log_info "No GUI packages defined for linux.$category.gui"
        return 0
    fi
    
    local count
    count=$(get_package_count "linux.$category.gui")
    log_info "GUI packages ($count total, using Flatpak)"
    
    # Snapshot what's already installed before we start
    snapshot_installed_packages "$packages"
    
    while IFS= read -r package; do
        [[ -z "$package" ]] && continue
        install_flatpak_app "$package"
    done <<< "$packages"
}

# =============================================================================
# MAIN INSTALLATION FUNCTIONS
# =============================================================================

install_packages() {
    # Use unified package schema
    install_unified_packages "$PACKAGES_YAML"
}

# =============================================================================
# DRY-RUN PACKAGE CHECK
# =============================================================================

check_packages_dry_run() {
    log_header "PACKAGES"
    
    # Show filter status
    if [[ "$INCLUDE_WORK" == true ]]; then
        log_info "Filter: --work (including work packages)"
    else
        log_info "Filter: personal packages only (use --work to include work packages)"
    fi
    echo ""
    
    # Get filtered packages
    local packages
    packages=$(get_unified_packages "$PACKAGES_YAML")
    
    if [[ -z "$packages" ]]; then
        log_info "No packages matched filters"
        return 0
    fi
    
    local os
    os=$(get_os)
    
    # Cache installed packages for faster lookups (brew list is slow)
    local installed_formulas=""
    local installed_casks=""
    if [[ "$os" == "macos" ]] && command_exists brew; then
        installed_formulas=$(brew list --formula 2>/dev/null || true)
        installed_casks=$(brew list --cask 2>/dev/null || true)
    fi
    
    # Group by type for display
    echo "CLI Packages:"
    while IFS='|' read -r name description gui work macos_override linux_override; do
        if [[ "$gui" == "true" ]]; then
            continue  # Skip GUI packages in this section
        fi
        
        local resolved_name
        resolved_name=$(resolve_package_name "$name" "$macos_override" "$linux_override")
        
        if [[ -z "$resolved_name" ]]; then
            log_info "  ✗ $name (not available on $os)"
        else
            local work_tag=""
            [[ "$work" == "true" ]] && work_tag=" [work]"
            
            # Check if installed (using cached list)
            local status=""
            if [[ "$os" == "macos" ]]; then
                if echo "$installed_formulas" | grep -q "^${resolved_name}$"; then
                    status="✓ installed"
                else
                    status="[DRY-RUN] would install"
                fi
            elif [[ "$os" == linux* ]]; then
                if rpm -q "$resolved_name" &>/dev/null; then
                    status="✓ installed"
                else
                    status="[DRY-RUN] would install"
                fi
            fi
            
            log_info "  $status: $resolved_name - $description$work_tag"
        fi
    done <<< "$packages"
    
    echo ""
    echo "GUI Packages:"
    while IFS='|' read -r name description gui work macos_override linux_override; do
        if [[ "$gui" == "false" ]]; then
            continue  # Skip CLI packages in this section
        fi
        
        local resolved_name
        resolved_name=$(resolve_package_name "$name" "$macos_override" "$linux_override")
        
        if [[ -z "$resolved_name" ]]; then
            log_info "  ✗ $name (not available on $os)"
        else
            local work_tag=""
            [[ "$work" == "true" ]] && work_tag=" [work]"
            local method=""
            [[ "$os" == "macos" ]] && method=" [cask]"
            [[ "$os" == linux* ]] && method=" [flatpak]"
            
            # Check if installed (using cached list)
            local status=""
            if [[ "$os" == "macos" ]]; then
                if echo "$installed_casks" | grep -q "^${resolved_name}$"; then
                    status="✓ installed"
                else
                    status="[DRY-RUN] would install"
                fi
            elif [[ "$os" == linux* ]]; then
                if command_exists flatpak && flatpak list --app 2>/dev/null | grep -q "$resolved_name"; then
                    status="✓ installed"
                else
                    status="[DRY-RUN] would install"
                fi
            fi
            
            log_info "  $status: $resolved_name - $description$work_tag$method"
        fi
    done <<< "$packages"
}

check_macos_packages_dry_run() {
    local category="$1"
    local packages
    local installed_count=0
    local would_install_count=0
    
    log_info "Category: $category"
    
    # CLI packages
    packages=$(get_packages "macos.$category.cli")
    if [[ -n "$packages" ]]; then
        echo ""
        log_info "CLI (brew install):"
        while IFS= read -r package; do
            [[ -z "$package" ]] && continue
            if is_brew_formula_installed "$package"; then
                log_success "$package (installed)"
                installed_count=$((installed_count + 1))
            else
                log_dry_run "$package (would install)"
                would_install_count=$((would_install_count + 1))
            fi
        done <<< "$packages"
    fi
    
    # GUI packages
    packages=$(get_packages "macos.$category.gui")
    if [[ -n "$packages" ]]; then
        echo ""
        log_info "GUI (brew install --cask):"
        while IFS= read -r package; do
            [[ -z "$package" ]] && continue
            if is_brew_cask_installed "$package"; then
                log_success "$package (installed)"
                installed_count=$((installed_count + 1))
            else
                log_dry_run "$package (would install)"
                would_install_count=$((would_install_count + 1))
            fi
        done <<< "$packages"
    fi
    
    echo ""
    log_info "Summary: $installed_count installed, $would_install_count would install"
}

check_linux_packages_dry_run() {
    local category="$1"
    local entries
    local installed_count=0
    local would_install_count=0
    
    local distro_name="DNF"
    
    log_info "Category: $category"
    
    # CLI packages (with distro-specific name resolution)
    entries=$(get_packages_raw "linux.$category.cli")
    if [[ -n "$entries" ]]; then
        echo ""
        log_info "CLI ($distro_name):"
        while IFS= read -r entry; do
            [[ -z "$entry" ]] && continue
            
            # Resolve to correct package name for this distro
            local package
            package=$(resolve_linux_package "$entry")
            
            if [[ -z "$package" ]]; then
                log_warning "No package defined for current distro: $entry"
                continue
            fi
            
            if is_linux_package_installed "$package"; then
                log_success "$package (installed)"
                installed_count=$((installed_count + 1))
            else
                log_dry_run "$package (would install)"
                would_install_count=$((would_install_count + 1))
            fi
        done <<< "$entries"
    fi
    
    # GUI packages (Flatpak - universal)
    # Skip in containers where Flatpak doesn't work
    if is_container; then
        echo ""
        log_warning "GUI (Flatpak): skipped (running in container)"
    else
        local packages
        packages=$(get_packages "linux.$category.gui")
        if [[ -n "$packages" ]]; then
            echo ""
            log_info "GUI (Flatpak):"
            while IFS= read -r package; do
                [[ -z "$package" ]] && continue
                if is_flatpak_installed "$package"; then
                    log_success "$package (installed)"
                    installed_count=$((installed_count + 1))
                else
                    log_dry_run "$package (would install)"
                    would_install_count=$((would_install_count + 1))
                fi
            done <<< "$packages"
        fi
    fi
    
    echo ""
    log_info "Summary: $installed_count installed, $would_install_count would install"
}
