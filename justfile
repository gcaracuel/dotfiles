# justfile for dotfiles bootstrap testing
# Provides container-based testing for different OS environments
# Requires: just command runner (https://github.com/casey/just)

# Container image names
fedora_image := "dotfiles-test-fedora"
homebrew_image := "dotfiles-test-homebrew"

# List all available recipes
default:
    @just --list

# =============================================================================
# PRIMARY TARGETS - Full test runs with verification
# =============================================================================

# Interactive test selection
test:
    #!/usr/bin/env bash
    echo ""
    echo "Select test environment:"
    echo "  1) Fedora (native Linux/DNF)"
    echo "  2) Homebrew (forced on Linux)"
    echo ""
    read -p "Choice [1-2]: " choice
    case $choice in
        1) just test-fedora ;;
        2) just test-brew ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac

# Run full bootstrap in Fedora container
test-fedora: build-fedora
    @echo ""
    @echo "=== Running full bootstrap in Fedora container ==="
    @echo ""
    docker run --rm \
        -v "{{justfile_directory()}}:/workspace" \
        {{fedora_image}} \
        bash -c "./main.sh --verbose && ./scripts/verify-install.sh"

# Run full bootstrap in Homebrew container (simulates macOS)
test-brew: build-homebrew
    @echo ""
    @echo "=== Running full bootstrap in Homebrew container (--force-brew) ==="
    @echo ""
    docker run --rm \
        -v "{{justfile_directory()}}:/workspace" \
        {{homebrew_image}} \
        bash -c "./main.sh --force-brew --verbose && ./scripts/verify-install.sh"

# =============================================================================
# DEBUG TARGETS - Keep container running for inspection
# =============================================================================

# Run Fedora container with container kept alive for debugging
test-fedora-debug: build-fedora
    @echo ""
    @echo "=== Running Fedora container (kept alive for debugging) ==="
    @echo ""
    docker run -it \
        -v "{{justfile_directory()}}:/workspace" \
        --name dotfiles-fedora-debug \
        {{fedora_image}} \
        bash -c "./main.sh --verbose; echo ''; echo 'Container kept alive. Exit shell to stop.'; exec bash"
    -docker rm dotfiles-fedora-debug 2>/dev/null

# Run Homebrew container with container kept alive for debugging
test-brew-debug: build-homebrew
    @echo ""
    @echo "=== Running Homebrew container (kept alive for debugging) ==="
    @echo ""
    docker run -it \
        -v "{{justfile_directory()}}:/workspace" \
        --name dotfiles-brew-debug \
        {{homebrew_image}} \
        bash -c "./main.sh --force-brew --verbose; echo ''; echo 'Container kept alive. Exit shell to stop.'; exec bash"
    -docker rm dotfiles-brew-debug 2>/dev/null

# =============================================================================
# SHELL TARGETS - Open shell in container for manual testing
# =============================================================================

# Open bash shell in Fedora container for manual testing
test-fedora-shell: build-fedora
    @echo ""
    @echo "=== Opening shell in Fedora container ==="
    @echo "Run './main.sh' or './main.sh --dry-run' to test"
    @echo ""
    docker run --rm -it \
        -v "{{justfile_directory()}}:/workspace" \
        {{fedora_image}} \
        bash

# Open bash shell in Homebrew container for manual testing
test-brew-shell: build-homebrew
    @echo ""
    @echo "=== Opening shell in Homebrew container ==="
    @echo "Run './main.sh --force-brew' or './main.sh --force-brew --dry-run' to test"
    @echo ""
    docker run --rm -it \
        -v "{{justfile_directory()}}:/workspace" \
        {{homebrew_image}} \
        bash

# =============================================================================
# BUILD TARGETS
# =============================================================================

# Build Fedora test Docker image
build-fedora:
    @echo "Building Fedora test image..."
    docker build -t {{fedora_image}} -f .devcontainer/fedora/Dockerfile .

# Build Homebrew test Docker image
build-homebrew:
    @echo "Building Homebrew test image..."
    docker build -t {{homebrew_image}} -f .devcontainer/homebrew/Dockerfile .

# =============================================================================
# CLEANUP
# =============================================================================

# Remove test container images and debug containers
clean:
    @echo "Removing test container images..."
    -docker rmi {{fedora_image}} 2>/dev/null
    -docker rmi {{homebrew_image}} 2>/dev/null
    @echo "Removing any leftover debug containers..."
    -docker rm dotfiles-fedora-debug 2>/dev/null
    -docker rm dotfiles-brew-debug 2>/dev/null
    @echo "Clean complete."

# Remove test images and Docker build cache
clean-all: clean
    @echo "Removing Docker build cache..."
    docker builder prune -f
    @echo "All clean (images + build cache removed)."

# =============================================================================
# HELP
# =============================================================================

# Show detailed help information
help:
    @echo ""
    @echo "Dotfiles Bootstrap - Test Commands (using just)"
    @echo ""
    @echo "Primary targets:"
    @echo "  just test              Interactive test selection"
    @echo "  just test-fedora       Run full bootstrap in Fedora container"
    @echo "  just test-brew         Run full bootstrap in Homebrew container (forced on Linux)"
    @echo ""
    @echo "Debug targets:"
    @echo "  just test-fedora-debug Run Fedora, keep container for inspection"
    @echo "  just test-brew-debug   Run Homebrew, keep container for inspection"
    @echo ""
    @echo "Shell targets:"
    @echo "  just test-fedora-shell Open bash shell in Fedora container"
    @echo "  just test-brew-shell   Open bash shell in Homebrew container"
    @echo ""
    @echo "Cleanup:"
    @echo "  just clean             Remove test container images"
    @echo "  just clean-all         Remove images + Docker build cache"
    @echo ""
    @echo "Tip: Run 'just' or 'just --list' to see all available recipes"
    @echo ""
