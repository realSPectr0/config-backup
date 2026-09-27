#-----------------------------------------------------
# CUSTOMIZATION
# -----------------------------------------------------
POSH=agnoster

plugins=(
    git
    sudo
    web-search
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
    fast-syntax-highlighting
    copyfile
    copybuffer
    dirhistory
)

[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

export PATH="$HOME/.local/bin:$PATH"

setopt HIST_IGNORE_DUPS
HISTSIZE=1000
SAVEHIST=1000
bindkey -e
HISTFILE=~/.zsh_history

setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY

if [[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=green"
fi

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
command -v exa >/dev/null 2>&1 && alias ls='exa -la'
command -v eza >/dev/null 2>&1 && alias ls='eza -la'

zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
autoload -Uz compinit && compinit

export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init - zsh)"

command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v fastfetch >/dev/null 2>&1 && fastfetch

# Optional local secrets or machine-specific exports live here.
[[ -r "$HOME/.config/shell/private.env" ]] && source "$HOME/.config/shell/private.env"
