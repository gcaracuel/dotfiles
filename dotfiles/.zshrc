
# ohMyZSH
export ZSH="$HOME/.oh-my-zsh"
plugins=(git zoxide dotenv eza zsh-interactive-cd)

export PATH="$PATH:/sbin/:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:$HOME/.local/bin:$HOME/bin:$HOME/.asdf/bin"

# Editor
export EDITOR="nvim"

# Homebrew
HOMEBREW_PREFIX=$(brew --prefix)

# Theme configuration
eval "$(starship init zsh)"
# ZSH_THEME="spaceship"
export STARSHIP_CONFIG=~/.starship.toml
SPACESHIP_KUBECTL_SHOW="true"

# -- ZSH plugins ---
source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh


# history setup
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history 
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# completion using arrow keys (based on history)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# ----- thefuck (correct last wrong command) -----
eval $(thefuck --alias)

# ----- asdf -----
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# ----- fzf -----
eval "$(fzf --zsh)"
export FZF_DEFAULT_OPTS="
	--color=fg:#908caa,bg:#232136,hl:#ea9a97
	--color=fg+:#e0def4,bg+:#393552,hl+:#ea9a97
	--color=border:#44415a,header:#3e8fb0,gutter:#232136
	--color=spinner:#f6c177,info:#9ccfd8
	--color=pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa"

# ----- Atuin (better history) -----
eval "$(atuin init zsh)"

# ----- Bat (better cat) -----
export BAT_THEME=base16

# ---- Eza (better ls) -----
alias ls="eza --icons=always"

# ---- Zoxide (better cd) ----
eval "$(zoxide init zsh)"
alias cd="z"

# --- Yazi Setup ---
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# --- Kubectl Krew --- #
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"C

# --- Kubeswitch Setup ---
INSTALLATION_PATH=$(brew --prefix switch) && source $INSTALLATION_PATH/switch.sh

source $ZSH/oh-my-zsh.sh