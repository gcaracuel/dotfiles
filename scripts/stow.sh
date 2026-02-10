#!/usr/bin/env bash
# stow.sh - Backup existing dotfiles and run GNU Stow
# Creates timestamped backups before stowing

# Source utils if not already sourced
if [[ -z "${UTILS_SOURCED:-}" ]]; then
    STOW_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=utils.sh
    source "$STOW_SCRIPT_DIR/utils.sh"
fi

# =============================================================================
# DOTFILE DISCOVERY
# =============================================================================

# Get list of all files in dotfiles/ directory (relative paths)
get_dotfiles_list() {
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        return
    fi
    
    # Find all files (not directories) in dotfiles/
    # Output relative paths from dotfiles/ directory
    (cd "$DOTFILES_DIR" && find . -type f -o -type l | sed 's|^\./||')
}

# Get list of all top-level items in dotfiles/ (for stow)
get_stow_items() {
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        return
    fi
    
    # Get immediate children of dotfiles/
    ls -A "$DOTFILES_DIR" 2>/dev/null || true
}

# =============================================================================
# BACKUP SYSTEM
# =============================================================================

# Check if a file exists in $HOME (could be file, symlink, or directory)
home_file_exists() {
    local relative_path="$1"
    local home_path="$HOME/$relative_path"
    
    [[ -e "$home_path" ]] || [[ -L "$home_path" ]]
}

# Check if file in $HOME is already a symlink to our dotfiles
is_already_stowed() {
    local relative_path="$1"
    local home_path="$HOME/$relative_path"
    local dotfile_path="$DOTFILES_DIR/$relative_path"
    
    if [[ -L "$home_path" ]]; then
        local link_target
        link_target=$(readlink "$home_path")
        
        # Check if it points to our dotfiles (could be absolute or relative)
        if [[ "$link_target" == "$dotfile_path" ]]; then
            return 0
        fi
        
        # Check for relative path match
        local resolved_link
        resolved_link=$(cd "$(dirname "$home_path")" && realpath "$link_target" 2>/dev/null || echo "")
        local resolved_dotfile
        resolved_dotfile=$(realpath "$dotfile_path" 2>/dev/null || echo "")
        
        if [[ "$resolved_link" == "$resolved_dotfile" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Compare file content (returns 0 if identical)
files_are_identical() {
    local file1="$1"
    local file2="$2"
    
    diff -q "$file1" "$file2" &>/dev/null
}

# Get file state for dry-run comparison
# Returns: new, modified, identical, symlinked, conflict
get_file_state() {
    local relative_path="$1"
    local home_path="$HOME/$relative_path"
    local dotfile_path="$DOTFILES_DIR/$relative_path"
    
    # File doesn't exist in $HOME
    if [[ ! -e "$home_path" ]] && [[ ! -L "$home_path" ]]; then
        echo "new"
        return
    fi
    
    # Already symlinked to our dotfiles
    if is_already_stowed "$relative_path"; then
        echo "symlinked"
        return
    fi
    
    # Is a symlink to somewhere else
    if [[ -L "$home_path" ]]; then
        echo "conflict"
        return
    fi
    
    # Is a directory (conflict - we expect stow to handle this)
    if [[ -d "$home_path" ]] && [[ ! -d "$dotfile_path" ]]; then
        echo "conflict"
        return
    fi
    
    # Is a regular file - check content
    if [[ -f "$home_path" ]] && [[ -f "$dotfile_path" ]]; then
        if files_are_identical "$home_path" "$dotfile_path"; then
            echo "identical"
        else
            echo "modified"
        fi
        return
    fi
    
    echo "conflict"
}

# =============================================================================
# BACKUP SYSTEM
# =============================================================================

# Backup all files that exist in $HOME that stow will manage
# This backs up EVERY file before stow runs, regardless of conflict status
# When FORCE_STOW is enabled, files are NOT removed (--adopt handles them)
backup_existing_dotfiles() {
    local backup_dir
    backup_dir=$(get_backup_dir)
    
    # Get list of all dotfiles that stow will manage
    local dotfiles
    dotfiles=$(get_dotfiles_list)
    
    if [[ -z "$dotfiles" ]]; then
        log_info "No dotfiles to process"
        return 0
    fi
    
    # Find which files actually exist in $HOME (need backup)
    local files_to_backup=()
    
    while IFS= read -r relative_path; do
        [[ -z "$relative_path" ]] && continue
        
        local home_path="$HOME/$relative_path"
        
        # Only backup if file exists in $HOME
        if [[ -e "$home_path" ]] || [[ -L "$home_path" ]]; then
            files_to_backup+=("$relative_path")
        fi
    done <<< "$dotfiles"
    
    if [[ ${#files_to_backup[@]} -eq 0 ]]; then
        log_info "No existing files to backup"
        return 0
    fi
    
    # Skip backup if FORCE_STOW is enabled (--adopt will handle files)
    if [[ "$FORCE_STOW" == true ]]; then
        log_info "Skipping backup (--force enabled: stow --adopt will import files)"
        return 0
    fi
    
    log_step "Backing up ${#files_to_backup[@]} existing file(s) to $backup_dir"
    
    if [[ "$DRY_RUN" != true ]]; then
        # Create backup directory
        mkdir -p "$backup_dir"
    fi
    
    # Backup each file
    local backed_up_count=0
    local failed_count=0
    
    for relative_path in "${files_to_backup[@]}"; do
        local home_path="$HOME/$relative_path"
        local backup_path="$backup_dir/$relative_path"
        
        if [[ "$DRY_RUN" == true ]]; then
            log_dry_run "Would backup: ~/$relative_path"
        else
            # Create parent directory in backup
            local backup_parent
            backup_parent=$(dirname "$backup_path")
            mkdir -p "$backup_parent"
            
            # Copy file content (follow symlinks to get actual content)
            local backup_success=false
            if [[ -L "$home_path" ]]; then
                # Follow symlink and copy actual content
                if cp -L "$home_path" "$backup_path" 2>/dev/null; then
                    log_debug "Backed up: ~/$relative_path (followed symlink)"
                    backup_success=true
                else
                    log_debug "Failed to backup ~/$relative_path (broken symlink?)"
                    failed_count=$((failed_count + 1))
                fi
            elif [[ -d "$home_path" ]]; then
                # Copy directory recursively
                if cp -a "$home_path" "$backup_path"; then
                    log_debug "Backed up: ~/$relative_path (directory)"
                    backup_success=true
                else
                    log_warning "Failed to backup ~/$relative_path"
                    failed_count=$((failed_count + 1))
                fi
            else
                # Regular file
                if cp -a "$home_path" "$backup_path"; then
                    log_debug "Backed up: ~/$relative_path"
                    backup_success=true
                else
                    log_warning "Failed to backup ~/$relative_path"
                    failed_count=$((failed_count + 1))
                fi
            fi
            
            # Remove original so stow can create symlink (only if backup succeeded)
            if [[ "$backup_success" == true ]]; then
                rm -rf "$home_path"
                backed_up_count=$((backed_up_count + 1))
            fi
        fi
    done
    
    if [[ "$DRY_RUN" != true ]]; then
        if [[ $failed_count -gt 0 ]]; then
            log_success "Backup complete: $backup_dir ($backed_up_count backed up, $failed_count failed)"
        else
            log_success "Backup complete: $backup_dir ($backed_up_count files)"
        fi
    fi
}

# =============================================================================
# STOW EXECUTION
# =============================================================================

# Run stow to symlink dotfiles
execute_stow() {
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_warning "Dotfiles directory not found: $DOTFILES_DIR"
        return 0
    fi
    
    local items
    items=$(get_stow_items)
    
    if [[ -z "$items" ]]; then
        log_warning "No dotfiles found in $DOTFILES_DIR"
        return 0
    fi
    
    log_step "Running stow..."
    
    # Build stow command
    local stow_cmd=(stow --no-folding --target="$HOME" --verbose=1)
    
    # Add --adopt flag if FORCE_STOW is enabled
    if [[ "$FORCE_STOW" == true ]]; then
        stow_cmd+=(--adopt)
        log_warning "Using --adopt: existing files will be imported into dotfiles/"
    fi
    
    stow_cmd+=(.)
    
    # Run stow from the dotfiles directory
    # Using --no-folding to prevent directory folding (symlinking entire directories)
    # This ensures individual file/subdirectory symlinks, preventing untracked files in .config/
    if (cd "$DOTFILES_DIR" && "${stow_cmd[@]}" 2>&1); then
        log_success "Stow complete"
        
        # If --adopt was used, remind user to check git diff
        if [[ "$FORCE_STOW" == true ]]; then
            log_warning "Check 'git diff' to review files imported into dotfiles/"
        fi
    else
        local exit_code=$?
        die "Stow failed" \
            "Check for conflicting files in your home directory"
        return $exit_code
    fi
}

# =============================================================================
# MAIN STOW FUNCTION
# =============================================================================

run_stow() {
    log_header "Setting up dotfiles"
    
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_warning "Dotfiles directory not found: $DOTFILES_DIR"
        log_info "Create your dotfiles in: $DOTFILES_DIR"
        return 0
    fi
    
    local items
    items=$(get_stow_items)
    
    if [[ -z "$items" ]]; then
        log_warning "No dotfiles found in $DOTFILES_DIR"
        return 0
    fi
    
    # Step 1: Backup existing files
    backup_existing_dotfiles
    
    # Step 2: Run stow
    if [[ "$DRY_RUN" != true ]]; then
        execute_stow
    fi
    
    log_success "Dotfiles setup complete"
}

# =============================================================================
# DRY-RUN COMPARISON
# =============================================================================

check_stow_dry_run() {
    log_header "DOTFILES"
    
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_warning "Dotfiles directory not found: $DOTFILES_DIR"
        return 0
    fi
    
    local dotfiles
    dotfiles=$(get_dotfiles_list)
    
    if [[ -z "$dotfiles" ]]; then
        log_warning "No dotfiles found in $DOTFILES_DIR"
        return 0
    fi
    
    log_info "Comparing dotfiles/ with \$HOME:"
    echo ""
    
    local new_count=0
    local modified_count=0
    local identical_count=0
    local symlinked_count=0
    local conflict_count=0
    local backup_count=0
    
    while IFS= read -r relative_path; do
        [[ -z "$relative_path" ]] && continue
        
        local state
        state=$(get_file_state "$relative_path")
        
        case "$state" in
            new)
                log_info "+ $relative_path (new file)"
                new_count=$((new_count + 1))
                ;;
            modified)
                log_warning "~ $relative_path (content differs)"
                modified_count=$((modified_count + 1))
                backup_count=$((backup_count + 1))
                ;;
            identical)
                log_success "= $relative_path (identical)"
                identical_count=$((identical_count + 1))
                backup_count=$((backup_count + 1))
                ;;
            symlinked)
                log_success "@ $relative_path (already symlinked)"
                symlinked_count=$((symlinked_count + 1))
                ;;
            conflict)
                log_error "! $relative_path (conflict - manual intervention needed)"
                conflict_count=$((conflict_count + 1))
                ;;
        esac
    done <<< "$dotfiles"
    
    echo ""
    
    # Show diff for modified files if requested (could add --verbose flag)
    if [[ $modified_count -gt 0 ]]; then
        log_info "Modified files will be backed up before stowing."
    fi
    
    if [[ $backup_count -gt 0 ]]; then
        log_info "Files to backup: $backup_count"
        log_info "Backup location: $(get_backup_dir)/"
    fi
    
    echo ""
    log_info "Summary:"
    log_info "  New files:      $new_count"
    log_info "  Modified:       $modified_count"
    log_info "  Identical:      $identical_count"
    log_info "  Already linked: $symlinked_count"
    if [[ $conflict_count -gt 0 ]]; then
        log_error "  Conflicts:      $conflict_count"
    fi
}
