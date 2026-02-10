#!/usr/bin/env bash
# verify-install.sh - Verify dotfiles bootstrap completed successfully
# Used by container tests to validate installation

set -euo pipefail

ERRORS=0
CHECKS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    CHECKS=$((CHECKS + 1))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ERRORS=$((ERRORS + 1))
    CHECKS=$((CHECKS + 1))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo ""
echo "=== Verification Checks ==="
echo ""

# =============================================================================
# 1. Check dotfiles were stowed (symlinks created)
# =============================================================================

echo "--- Dotfiles (stow) ---"

if [[ -L "$HOME/.gitconfig" ]]; then
    check_pass ".gitconfig symlinked"
else
    check_fail ".gitconfig not symlinked"
fi

if [[ -L "$HOME/.zshrc" ]]; then
    check_pass ".zshrc symlinked"
else
    check_fail ".zshrc not symlinked"
fi

# Verify symlink points to correct location
if [[ -L "$HOME/.zshrc" ]]; then
    target=$(readlink "$HOME/.zshrc")
    if [[ "$target" == *"dotfiles/.zshrc"* ]]; then
        check_pass ".zshrc points to dotfiles directory"
    else
        check_fail ".zshrc points to wrong location: $target"
    fi
fi

# =============================================================================
# 2. Check at least one package was installed
# =============================================================================

echo ""
echo "--- Packages ---"

# Detect OS and check appropriate packages
if command -v brew &>/dev/null; then
    # macOS/Homebrew mode
    if brew list gum &>/dev/null; then
        check_pass "gum installed (brew)"
    else
        check_fail "gum not installed"
    fi
    
    if brew list yq &>/dev/null; then
        check_pass "yq installed (brew)"
    else
        check_fail "yq not installed"
    fi
    
    if brew list stow &>/dev/null; then
        check_pass "stow installed (brew)"
    else
        check_fail "stow not installed"
    fi
    
    # Check at least one CLI package from packages.yaml
    if brew list ripgrep &>/dev/null || brew list fzf &>/dev/null || brew list bat &>/dev/null; then
        check_pass "At least one CLI package installed"
    else
        check_warn "No CLI packages from packages.yaml found (may be expected)"
    fi

elif command -v dnf &>/dev/null; then
    # Fedora mode
    if rpm -q gum &>/dev/null || command -v gum &>/dev/null; then
        check_pass "gum installed"
    else
        check_fail "gum not installed"
    fi
    
    if command -v yq &>/dev/null; then
        check_pass "yq installed"
    else
        check_fail "yq not installed"
    fi
    
    if rpm -q stow &>/dev/null || command -v stow &>/dev/null; then
        check_pass "stow installed"
    else
        check_fail "stow not installed"
    fi
    
    # Check at least one CLI package from packages.yaml
    if rpm -q ripgrep &>/dev/null || rpm -q fzf &>/dev/null || rpm -q bat &>/dev/null; then
        check_pass "At least one CLI package installed"
    else
        check_warn "No CLI packages from packages.yaml found (may be expected)"
    fi
else
    check_warn "Unknown package manager - skipping package checks"
fi

# =============================================================================
# 3. Check stow command works
# =============================================================================

echo ""
echo "--- Tools ---"

if command -v stow &>/dev/null; then
    check_pass "stow command available"
else
    check_fail "stow command not found"
fi

if command -v gum &>/dev/null; then
    check_pass "gum command available"
else
    check_fail "gum command not found"
fi

if command -v yq &>/dev/null; then
    check_pass "yq command available"
else
    check_fail "yq command not found"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=== Summary ==="
echo ""

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}All $CHECKS checks passed!${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS of $CHECKS checks failed${NC}"
    exit 1
fi
