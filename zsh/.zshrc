# NOTE: profiling zsh
# uncomment the following line to print out profiling info. Also see the
# `zprop` command at the end of the file:
# zmodload zsh/zprof

# NOTE: how to avoid env: node: No such file or directory at the start of new session?
# TLDR: run this:sudo ln -s "$(which node)" /System/Volumes/Data/usr/local/bin
# See: https://github.com/nvm-sh/nvm/issues/1702

ls "$HOME/dotfiles/arts"|sort -R |tail -1 |while read file; do
  cat "$HOME/dotfiles/arts/$file"
done


# In secretes file still do not save the passwords directly. Instead:
# 1. add to keychain: security add-generic-password -a "$USER" -s "my-password" -w "super-secret"
# 2. in .zsh_secrets: export ANTHROPIC_API_KEY="$(security find-generic-password -a "$USER" -s "my-password" -w)"
source "$HOME/.zsh_secrets"

# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH="$PATH:$HOME/Library/PackageManager/bin"
# NOTE: `$(yarn global bin)` spawned node+yarn on every shell start (~0.2-1s),
# just to resolve a static path. Hardcode it instead. Run `yarn global bin`
# manually if the location ever changes.
export PATH="/opt/homebrew/bin:$PATH"

export ZSH_TMUX_ITERM2=true
# export EDITOR=nvim
# export EDITOR='nvim --cmd "let g:no_tree=1"'
# NOTE: run the nvim without nvimtree at homepage. see bin/.local/bin/nvim-notree and init.lua
export EDITOR=nvim-quick-insert
export OPENCODE_DISABLE_CLAUDE_CODE=1
export OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1 # ignore ~/.claude/CLAUDE.md
export OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1 # ignore ~/.claude/skills
export OPENCODE_ENABLE_EXA=1

# eval "$(_PIPENV_COMPLETE=zsh_source pipenv)"

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Speed up startup: skip oh-my-zsh's update check (git fetch + version compare)
# and skip the slow compinit security audit (compaudit), which dominated startup.
DISABLE_AUTO_UPDATE=true
DISABLE_UPDATE_PROMPT=true
ZSH_DISABLE_COMPFIX=true

# Cache completion init: compinit rebuilds the ~50KB dump on every launch
# (~450ms). Run a full compinit only once a day; otherwise reuse the cached
# dump with `compinit -C` (skips the slow scan/freshness checks).
#
# NOTE: we do NOT call compinit ourselves and then stub it into a no-op.
# OMZ's own compinit call (further down, in oh-my-zsh.sh) is what manages
# the dump's metadata (an "#omz revision"/"#omz fpath" comment appended to
# the dump) and deletes+rebuilds the dump whenever OMZ itself or the plugin
# list changes. Stubbing compinit made OMZ delete the dump on every single
# launch (metadata never matched) and then silently do nothing, leaving
# only a 2-line dump with no completions in it -- breaking all completion,
# including plain path/file completion.
# Instead we redefine `compinit` to transparently inject `-C` into whatever
# call OMZ makes when the dump is still fresh, and otherwise let it run for
# real. `builtin autoload -XUz` loads+runs the *real* compinit from $fpath,
# which self-removes and re-autoloads itself when done (see its last line),
# so this wrapper only ever affects the single call OMZ makes below.
ZSH_COMPDUMP="$HOME/.zcompdump"
compinit() {
  if [[ -n ${ZSH_COMPDUMP}(#qN.mh-24) ]]; then
    set -- -C "$@"
  fi
  builtin autoload -XUz
}

# fpath+=$HOME/pure
export fpath=( "$HOME/.zfunctions" $fpath )

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME=""

# activates when using it
# zstyle ':omz:plugins:nvm' lazy yes
# only in folder with .nvmrc:
zstyle ':omz:plugins:nvm' autoload yes

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  git-extras
#  dotenv
  vi-mode
  tmux
  jsontools
  yarn
  zsh-syntax-highlighting
  zsh-autosuggestions
	# nvm
)

source $ZSH/oh-my-zsh.sh

# eval "$(wt config shell init zsh)"


# # # replaced with oh-my-zsh plugin
# # must be after oh-my-zsh
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# HIST
# set history size
export HISTSIZE=10000

# save history after logout
export SAVEHIST=10000

# history file
export HISTFILE=~/.zhistory

# for sensitive commands containing passwords just add space at the start of the line
setopt HIST_IGNORE_SPACE

# append into history file
setopt INC_APPEND_HISTORY

# save only one command if 2 common are same and consistent
setopt HIST_IGNORE_DUPS

#add timestamp for each entry
setopt EXTENDED_HISTORY

autoload -U promptinit; promptinit
prompt pure

source ~/.zprofile

# added by travis gem
# [ -f /Users/tommmyy/.travis/travis.sh ] && source /Users/tommmyy/.travis/travis.sh


export PATH=/Users/tommmyy/.local/bin:$PATH
test -e /Users/tommmyy/.iterm2_shell_integration.zsh && source /Users/tommmyy/.iterm2_shell_integration.zsh || true

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh


# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# bun completions
# [ -s "/Users/tommmyy/.bun/_bun" ] && source "/Users/tommmyy/.bun/_bun"

# Zoxide - https://github.com/ajeetdsouza/zoxide
eval "$(zoxide init zsh)"

# see beginning of the file. This runs zsh profiling:
# zprof

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
