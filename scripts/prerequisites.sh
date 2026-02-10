#!/usr/bin/env bash
# prerequisites.sh - Install required dependencies
# Installs Homebrew (macOS), gum, yq, stow, and asdf

# Source utils if not already sourced
if [[ -z "${UTILS_SOURCED:-}" ]]; then
    PREREQ_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=utils.sh
    source "$PREREQ_SCRIPT_DIR/utils.sh"
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

# asdf version - can be a specific version tag (e.g., "v0.17.0") or "latest"
# Note: Pre-built binaries are only available from v0.15.0 onwards
ASDF_VERSION="v0.17.0"

# =============================================================================
# HOMEBREW INSTALLATION (macOS)
# =============================================================================

install_homebrew() {
    if command_exists brew; then
        log_success "Homebrew already installed"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would install Homebrew"
        return 0
    fi
    
    log_step "Installing Homebrew..."
    
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        die "Failed to install Homebrew" \
            "Visit https://brew.sh for manual installation instructions"
    }
    
    # Add Homebrew to PATH for this session (needed on Apple Silicon)
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    log_success "Homebrew installed"
}

# =============================================================================
# FEDORA COPR REPOSITORIES
# =============================================================================

# COPR repos required for packages not in default Fedora repos
FEDORA_COPR_REPOS=(
    "atim/lazygit"       # lazygit
    "che/nerd-fonts"     # Nerd Fonts (all nerd fonts)
    "atim/starship"      # starship prompt
    "lihaohong/yazi"     # yazi file manager
    "scottames/ghostty"  # ghostty terminal emulator
)

# Check if a COPR repo is enabled
is_copr_enabled() {
    local repo="$1"
    # Convert owner/name to the format used in repo files: _copr:copr.fedorainfracloud.org:owner:name
    local repo_id
    repo_id=$(echo "$repo" | tr '/' ':')
    dnf repolist --enabled 2>/dev/null | grep -qi "copr.*$repo_id" || \
    ls /etc/yum.repos.d/*copr*"${repo_id//:/_}"* &>/dev/null 2>&1
}

# Enable COPR repositories for Fedora
setup_fedora_copr_repos() {
    if [[ "$DRY_RUN" == true ]]; then
        for repo in "${FEDORA_COPR_REPOS[@]}"; do
            log_dry_run "Would enable COPR: $repo"
        done
        return 0
    fi
    
    log_step "Setting up COPR repositories..."
    
    for repo in "${FEDORA_COPR_REPOS[@]}"; do
        if is_copr_enabled "$repo"; then
            log_success "COPR $repo (already enabled)"
        else
            log_step "Enabling COPR: $repo..."
            if sudo dnf copr enable -y "$repo" 2>&1; then
                log_success "COPR $repo enabled"
            else
                log_warning "Failed to enable COPR: $repo (some packages may not install)"
            fi
        fi
    done
}

# =============================================================================
# LINUX PACKAGE MANAGER CHECK
# =============================================================================

check_linux_package_manager() {
    if is_fedora; then
        if ! command_exists dnf; then
            die "DNF package manager not found" \
                "This script requires Fedora with DNF"
        fi
        log_success "DNF package manager available"
        
        # Setup COPR repos for packages not in default repos
        setup_fedora_copr_repos
        
        # Install Flatpak via DNF on Fedora
        if ! command_exists flatpak; then
            if [[ "$DRY_RUN" == true ]]; then
                log_dry_run "Would install flatpak via DNF"
                log_dry_run "Would add Flathub remote"
            else
                log_step "Installing Flatpak..."
                sudo dnf install -y flatpak || {
                    die "Failed to install Flatpak" \
                        "Try: sudo dnf install flatpak"
                }
                log_success "Flatpak installed"
            fi
        else
            log_success "Flatpak already installed"
        fi
    elif is_generic_linux; then
        log_warning "Non-Fedora Linux detected"
        
        # Check if Flatpak is available
        if ! command_exists flatpak; then
            log_warning "Flatpak not found"
            log_info "Install Flatpak via your distro's package manager:"
            log_info "  Debian/Ubuntu: sudo apt install flatpak"
            log_info "  Arch: sudo pacman -S flatpak"
            log_info "  OpenSUSE: sudo zypper install flatpak"
        else
            log_success "Flatpak already installed"
        fi
    fi
    
    # Add Flathub remote (generic, works on all distros if Flatpak is installed)
    if command_exists flatpak; then
        if ! flatpak remotes 2>/dev/null | grep -q flathub; then
            if [[ "$DRY_RUN" == true ]]; then
                log_dry_run "Would add Flathub remote"
            else
                log_step "Adding Flathub remote..."
                flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || {
                    log_warning "Failed to add Flathub remote"
                }
                log_success "Flathub remote added"
            fi
        fi
    fi
}

# =============================================================================
# TOOL INSTALLATION
# =============================================================================

install_gum() {
    if command_exists gum; then
        log_success "gum already installed"
        GUM_AVAILABLE=true
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would install gum"
        return 0
    fi
    
    log_step "Installing gum..."
    
    # If force-brew or macOS, use Homebrew
    if [[ "$FORCE_BREW" == true ]] || is_macos; then
        brew install gum || {
            die "Failed to install gum" \
                "Try: brew install gum"
        }
    elif is_fedora; then
        # gum is available in Fedora repos
        sudo dnf install -y gum || {
            die "Failed to install gum" \
                "Try: sudo dnf install gum"
        }
    else
        die "gum installation not supported on this system" \
            "Try using --force-brew or install manually: https://github.com/charmbracelet/gum"
    fi
    
    GUM_AVAILABLE=true
    log_success "gum installed"
}

install_yq() {
    if command_exists yq; then
        log_success "yq already installed"
        return 0
    fi
    
    # NOTE: yq is always installed (even in dry-run mode) because it's required
    # for the script to parse packages.yaml and show what would be installed
    log_step "Installing yq (required for script operation)..."
    
    # If force-brew or macOS, use Homebrew
    if [[ "$FORCE_BREW" == true ]] || is_macos; then
        brew install yq || {
            die "Failed to install yq" \
                "Try: brew install yq"
        }
    elif is_fedora; then
        sudo dnf install -y yq || {
            die "Failed to install yq" \
                "Try: sudo dnf install yq"
        }
    else
        die "yq installation not supported on this system" \
            "Try using --force-brew or install manually: https://github.com/mikefarah/yq"
    fi
    
    log_success "yq installed"
}

install_stow() {
    if command_exists stow; then
        log_success "GNU Stow already installed"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would install GNU Stow"
        return 0
    fi
    
    log_step "Installing GNU Stow..."
    
    # If force-brew or macOS, use Homebrew
    if [[ "$FORCE_BREW" == true ]] || is_macos; then
        brew install stow || {
            die "Failed to install GNU Stow" \
                "Try: brew install stow"
        }
    elif is_fedora; then
        sudo dnf install -y stow || {
            die "Failed to install GNU Stow" \
                "Try: sudo dnf install stow"
        }
    else
        die "GNU Stow installation not supported on this system" \
            "Try using --force-brew or install manually"
    fi
    
    log_success "GNU Stow installed"
}

# =============================================================================
# ASDF INSTALLATION
# =============================================================================

# Detect system architecture for asdf binary download
# Note: This detects the *actual* OS, not the effective OS (--force-brew)
get_system_arch() {
    local os
    local arch
    
    # Check actual OS (uname), not effective OS (get_os())
    case "$(uname -s)" in
        Darwin*)
            os="darwin"
            ;;
        Linux*)
            os="linux"
            ;;
        *)
            die "Unsupported OS: $(uname -s)" \
                "asdf supports macOS and Linux only"
            ;;
    esac
    
    # Get CPU architecture
    case "$(uname -m)" in
        x86_64|amd64)
            arch="amd64"
            ;;
        arm64|aarch64)
            arch="arm64"
            ;;
        *)
            die "Unsupported architecture: $(uname -m)" \
                "asdf supports x86_64 and arm64 only"
            ;;
    esac
    
    echo "${os}-${arch}"
}

# Get asdf download URL based on version
get_asdf_download_url() {
    local version="$ASDF_VERSION"
    
    # If "latest", fetch the latest release tag from GitHub
    if [[ "$version" == "latest" ]]; then
        log_step "Fetching latest asdf version..."
        version=$(curl -fsSL https://api.github.com/repos/asdf-vm/asdf/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') || {
            die "Failed to fetch latest asdf version" \
                "Check your internet connection or set ASDF_VERSION to a specific version"
        }
        log_info "Latest asdf version: $version"
    fi
    
    local arch
    arch=$(get_system_arch)
    
    echo "https://github.com/asdf-vm/asdf/releases/download/${version}/asdf-${version}-${arch}.tar.gz"
}

# Install asdf version manager
install_asdf() {
    local asdf_dir="$HOME/.asdf"
    local asdf_bin="$asdf_dir/bin/asdf"
    
    # Check if asdf is already installed
    if [[ -f "$asdf_bin" ]]; then
        log_success "asdf already installed"
        # Ensure it's in PATH for this session
        if [[ ! "$PATH" =~ "$asdf_dir/bin" ]]; then
            export PATH="$asdf_dir/bin:$PATH"
        fi
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would install asdf $ASDF_VERSION to $asdf_dir"
        return 0
    fi
    
    log_step "Installing asdf $ASDF_VERSION..."
    
    # Check dependencies
    if ! command_exists git; then
        log_step "Installing git (required for asdf)..."
        if is_macos || [[ "$FORCE_BREW" == true ]]; then
            brew install git || die "Failed to install git"
        elif is_fedora; then
            sudo dnf install -y git || die "Failed to install git"
        else
            die "git is required for asdf" \
                "Install git via your package manager: sudo apt install git"
        fi
        log_success "git installed"
    fi
    
    if ! command_exists bash; then
        die "bash is required for asdf" \
            "bash should be installed by default on most systems"
    fi
    
    # Download asdf binary
    local download_url
    download_url=$(get_asdf_download_url)
    
    log_step "Downloading asdf from $download_url..."
    local temp_file
    temp_file=$(mktemp)
    
    if ! curl -fsSL "$download_url" -o "$temp_file"; then
        rm -f "$temp_file"
        die "Failed to download asdf" \
            "Check your internet connection or verify the version exists: $ASDF_VERSION"
    fi
    
    # Extract to ~/.asdf
    log_step "Extracting asdf to $asdf_dir..."
    mkdir -p "$asdf_dir/bin"
    
    # Extract the binary (tarball contains just the "asdf" file)
    if ! tar -xzf "$temp_file" -C "$asdf_dir/bin"; then
        rm -f "$temp_file"
        die "Failed to extract asdf" \
            "The downloaded file may be corrupted"
    fi
    
    rm -f "$temp_file"
    
    # Make executable
    chmod +x "$asdf_bin"
    
    # Verify installation
    if [[ ! -f "$asdf_bin" ]]; then
        die "asdf installation failed" \
            "Binary not found at $asdf_bin"
    fi
    
    # Add to PATH temporarily for this session
    if [[ ! "$PATH" =~ "$asdf_dir/bin" ]]; then
        export PATH="$asdf_dir/bin:$PATH"
    fi
    
    # Verify asdf command works
    if ! asdf version &>/dev/null; then
        die "asdf installation verification failed" \
            "asdf binary exists but cannot execute"
    fi
    
    log_success "asdf installed: $(asdf version | head -n1)"
    log_info "Add to your shell config: export PATH=\"\$HOME/.asdf/bin:\$PATH\""
}

# =============================================================================
# MAIN PREREQUISITES FUNCTION
# =============================================================================

install_prerequisites() {
    log_header "Installing prerequisites"
    
    local os
    os="$(get_os)"
    log_info "Detected OS: $os"
    
    # If --force-brew is set, always use Homebrew workflow
    if [[ "$FORCE_BREW" == true ]]; then
        log_info "Force-brew mode: using Homebrew on Linux"
        install_homebrew
    elif is_macos; then
        install_homebrew
    elif is_linux; then
        check_linux_package_manager
    else
        die "Unsupported operating system: $os" \
            "This script supports macOS and Linux (Fedora/Debian)"
    fi
    
    # Install gum first so we get nice output for the rest
    install_gum
    
    # Re-check gum availability after installation
    check_gum
    
    # Install remaining tools
    install_yq
    install_stow
    install_asdf
    
    log_success "All prerequisites installed"
}

# =============================================================================
# DRY-RUN PREREQUISITES CHECK
# =============================================================================

check_prerequisites_dry_run() {
    log_header "PREREQUISITES"
    
    local os
    os="$(get_os)"
    
    # Check Homebrew / package manager
    if is_macos; then
        if command_exists brew; then
            log_info "Homebrew         installed"
        else
            log_info "Homebrew         would install"
        fi
    elif is_fedora; then
        if command_exists dnf; then
            log_info "DNF              installed"
        else
            log_info "DNF              not available (required)"
        fi
        # Show COPR repos status
        for repo in "${FEDORA_COPR_REPOS[@]}"; do
            if is_copr_enabled "$repo"; then
                log_info "COPR $repo  enabled"
            else
                log_info "COPR $repo  would enable"
            fi
        done
        if command_exists flatpak; then
            log_info "Flatpak          installed"
        else
            log_info "Flatpak          would install"
        fi
    fi
    
    # Check tools
    if command_exists gum; then
        log_info "gum              installed"
    else
        log_info "gum              would install"
    fi
    
    if command_exists yq; then
        log_info "yq               installed"
    else
        log_info "yq               would install"
    fi
    
    if command_exists stow; then
        log_info "stow             installed"
    else
        log_info "stow             would install"
    fi
    
    if [[ -f "$HOME/.asdf/bin/asdf" ]]; then
        log_info "asdf             installed"
    else
        log_info "asdf             would install ($ASDF_VERSION)"
    fi
}
