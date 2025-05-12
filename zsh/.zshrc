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

source "$HOME/.zsh_secrets"

# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH="$PATH:$HOME/Library/PackageManager/bin"
export PATH="$(yarn global bin):$PATH"

export ZSH_TMUX_ITERM2=true

# eval "$(_PIPENV_COMPLETE=zsh_source pipenv)"

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

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
	nvm
)

source $ZSH/oh-my-zsh.sh


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
[ -s "/Users/tommmyy/.bun/_bun" ] && source "/Users/tommmyy/.bun/_bun"

# see beginning of the file. This runs zsh profiling:
# zprof
