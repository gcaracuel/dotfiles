# test.just — container testing targets
# Imported by justfile. Run with: just test-arch, just test-brew, etc.

# Build and run tests interactively (choose: arch or brew)
test:
    @echo "Select test environment:"
    @echo "  1) Arch Linux"
    @echo "  2) Homebrew (macOS simulation)"
    @read -p "Choice [1/2]: " choice; \
      case "$$choice" in \
        1) just test-arch ;; \
        2) just test-brew ;; \
        *) echo "Invalid choice" ;; \
      esac

# Run Arch Linux container test
# Note: --platform linux/amd64 required (Arch has no arm64 image, runs via Rosetta on Apple Silicon)
# --config-data supplies work=false so promptBoolOnce is skipped in non-interactive containers.
test-arch: test-build-arch
    docker run --rm \
      --platform linux/amd64 \
      -v {{REPO_DIR}}:/workspace \
      -w /workspace \
      dotfiles-test-arch \
      bash -c "just init-ci"

# Run Homebrew container test
# --config-data supplies work=false so promptBoolOnce is skipped in non-interactive containers.
test-brew: test-build-brew
    docker run --rm \
      -v {{REPO_DIR}}:/workspace \
      -w /workspace \
      dotfiles-test-brew \
      bash -c "just init-ci"

# Open interactive shell in Arch container (for debugging)
test-arch-shell: test-build-arch
    docker run --rm -it \
      --platform linux/amd64 \
      -v {{REPO_DIR}}:/workspace \
      -w /workspace \
      dotfiles-test-arch \
      bash

# Open interactive shell in Homebrew container (for debugging)
test-brew-shell: test-build-brew
    docker run --rm -it \
      -v {{REPO_DIR}}:/workspace \
      -w /workspace \
      dotfiles-test-brew \
      bash

# Build Arch Linux test image (x86_64 only — runs via Rosetta on Apple Silicon)
test-build-arch:
    docker build --platform linux/amd64 -t dotfiles-test-arch {{REPO_DIR}}/.devcontainer/arch/

# Build Homebrew test image
test-build-brew:
    docker build -t dotfiles-test-brew {{REPO_DIR}}/.devcontainer/homebrew/

# Remove test containers and images
test-clean:
    docker rmi -f dotfiles-test-arch dotfiles-test-brew 2>/dev/null || true
    docker container prune -f

# Remove images and Docker build cache
test-clean-all: test-clean
    docker builder prune -f
