ZSH=$HOME/.oh-my-zsh

# starship theme
eval "$(starship init zsh)"

export DIRENV_LOG_FORMAT=""

# zsh-syntax-highlighting catppuccino theme
source ~/.zsh/catppuccin_mocha-zsh-syntax-highlighting.zsh

#oh-my-zsh plugins
plugins=(
    # zsh-autosuggestions
    copypath
    direnv
    dirhistory
    git
    gitfast
    history-substring-search
    jsontools
    last-working-dir
    # poetry
    python
    ssh-agent
    autoswitch_virtualenv
    zsh-bat
    zsh-syntax-highlighting
    azure
    common-aliases
)

# (macOS-only) Prevent Homebrew from reporting - https://github.com/Homebrew/brew/blob/master/docs/Analytics.md
export HOMEBREW_NO_ANALYTICS=1

if [[ "$(uname -s)" == "Linux" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Disable warning about insecure completion-dependent directories
ZSH_DISABLE_COMPFIX=true

# ssh-agent settings
zstyle :omz:plugins:ssh-agent quiet yes
zstyle :omz:plugins:ssh-agent lazy yes


# Load rbenv if installed (to manage your Ruby versions)
export PATH="${HOME}/.rbenv/bin:${PATH}" # Needed for Linux/WSL
type -a rbenv > /dev/null && eval "$(rbenv init -)"

# Load pyenv (to manage your Python versions)
export AUTOSWITCH_SILENT=1
export PYENV_VIRTUALENV_DISABLE_PROMPT=0
type -a pyenv > /dev/null && eval "$(pyenv init -)" && eval "$(pyenv virtualenv-init - 2> /dev/null)"

# add and load poetry
export PATH="$HOME/.local/bin:$PATH"

# Load autocompletion and built cache only once a day
autoload -Uz compinit
if [ "$(date +'%j')" != "$(stat -f '%Sm' -t '%j' ~/.zcompdump 2>/dev/null)" ]; then
    compinit
else
    compinit -C
fi

# Autocompletion by caraspace
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense' # optional
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
source <(carapace _carapace)

# Actually load Oh-My-Zsh
source "${ZSH}/oh-my-zsh.sh"
unalias rm # No interactive rm by default (brought by plugins/common-aliases)
unalias lt # we need `lt` for https://github.com/localtunnel/localtunnel

# Load nvm (to manage your node versions)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm


# Rails and Ruby uses the local `bin` folder to store binstubs.
# So instead of running `bin/rails` like the doc says, just run `rails`
# Same for `./node_modules/.bin` and nodejs
export PATH="./bin:./node_modules/.bin:${PATH}:/usr/local/sbin"

# Store your own aliases in the ~/.aliases file and load the here.
[[ -f "$HOME/.aliases" ]] && source "$HOME/.aliases"

# Encoding stuff for the terminal
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

export BUNDLER_EDITOR=nvim
export EDITOR=nvim

# Set ipdb as the default Python debugger
export PYTHONBREAKPOINT=ipdb.set_trace
export GOOGLE_APPLICATION_CREDENTIALS=/Users/tim/code/gcp/gcloud_credentials.json

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# zoxide
eval "$(zoxide init zsh)"

# fzf
eval "$(fzf --zsh)"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--preview 'bat -n --color=always {}' \
--preview-window=right,60% \
--layout=reverse \
--height=80% \
--multi"

export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"

export FZF_ALT_C_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'tree -C {}'"

ZSH_THEME_TERM_TITLE_IDLE="%n@%m: %1~"
ZSH_THEME_TERM_TAB_TITLE_IDLE="%n@%m: %1~"
# deno
if [[ "$(uname)" == "Darwin" ]]; then
  . "/Users/tim/.deno/env"
fi

timezsh() {
  shell=${1-$SHELL}
  for i in $(seq 1 10); do /usr/bin/time $shell -i -c exit; done
}

# sesh
function sesh-sessions() {
  {
    exec </dev/tty
    exec <&1
    local session
    session=$(sesh list -t -c | fzf --height 40% --reverse --border-label ' sesh ' --border --prompt '⚡  ')
    zle reset-prompt > /dev/null 2>&1 || true
    [[ -z "$session" ]] && return
    sesh connect $session
  }
}

zle     -N             sesh-sessions
bindkey -M emacs '^S' sesh-sessions
bindkey -M vicmd '^S' sesh-sessions
bindkey -M viins '^S' sesh-sessions
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/tim/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac


# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/tim/.lmstudio/bin"
export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"

# atuin
. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"

# Add a newline between commands
# https://github.com/starship/starship/issues/560
precmd() { precmd() { echo "" } }
alias clear="precmd() { precmd() { echo } } && clear"

# transient prompt
# https://github.com/starship/starship/pull/4205#issuecomment-2230335985
source ~/dotfiles/transient-prompt.zsh

# opencode
export PATH=/Users/tim/.opencode/bin:$PATH

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc' ]; then . '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc' ]; then . '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc'; fi

# Vi mode
# ANSI cursor escape codes:
# \e[0 q: Reset to the default cursor style.
# \e[1 q: Blinking block cursor.
# \e[2 q: Steady block cursor (non-blinking).
# \e[3 q: Blinking underline cursor.
# \e[4 q: Steady underline cursor (non-blinking).
# \e[5 q: Blinking bar cursor.
# \e[6 q: Steady bar cursor (non-blinking).

bindkey -v # Enable vi keybindings
export KEYTIMEOUT=1 # Makes switching modes quicker
export VI_MODE_SET_CURSOR=true # trigger cursor shape changes when switching modes

# Gets called every time the keymap changes (insert <-> normal mode)
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]]; then
    echo -ne '\e[2 q' # block
  else
    echo -ne '\e[6 q' # beam
  fi
}
# Register this function as a ZLE (Zsh Line Editor) widget
zle -N zle-keymap-select

# Runs once when a new ZLE session starts (e.g. when a prompt appears)
zle-line-init() {
  zle -K viins # initiate 'vi insert' as keymap (can be removed if 'binkey -V has been set elsewhere')
  echo -ne '\e[6 q'
}
zle -N zle-line-init
echo -ne '\e[6 q' # Use beam shape cursor on startup

# Yank to the system clipboard
function vi-yank-xclip {
  zle vi-yank
  echo "$CUTBUFFER" | pbcopy -i
}

zle -N vi-yank-xclip
bindkey -M vicmd 'y' vi-yank-xclip

# Press 'v' in normal mode to launch Vim with current line
autoload edit-command-line
zle -N edit-command-line
bindkey -M vicmd o edit-command-line

# colors when using "ls" and completion
export LS_COLORS=$(vivid generate catppuccin-mocha)
