ls "$HOME/.dotfiles/arts"|sort -R |tail -1 |while read file; do
  cat "$HOME/.dotfiles/arts/$file" 
done

# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH="$PATH:$HOME/Library/PackageManager/bin"
export PATH="$(yarn global bin):$PATH"		

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

source $ZSH/oh-my-zsh.sh

export fpath=( "$HOME/.zfunctions" $fpath )

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME=""

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  git-extras
  dotenv
  vi-mode
  tmux
  jsontools
  yarn
  zsh-syntax-highlighting
  zsh-autosuggestions
)

ZSH_TMUX_ITERM2=true
source $ZSH/oh-my-zsh.sh

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

#  Aliases
# For a full list of active aliases, run `alias`.
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"
alias reloadZshconfig=". ~/.zshrc"

alias ctags="`brew --prefix`/bin/ctags"
alias vimconfig="vim ~/.vimrc"
alias cls="clear"
alias lsa="ls -a"
alias rmrf="rm -rf"
alias vim="vim --servername VIM"
alias v="vim --servername VIM"	
alias fig="lein figwheel"
alias gmu="git fetch upstream && git merge upstream/master"
alias initGitignore="git ignore-io -r node vim sublimetext intellij visualstudiocode webstorm"
alias back="cd $OLDPWD"

alias removeVimJunk="find . -type f -name '*.sw[klmnop]' -delete"

eval $(thefuck --alias)
autoload -U promptinit; promptinit
prompt pure

source ~/.zprofile
source ~/.zprojects

# added by travis gem
[ -f /Users/tomas.konrady/.travis/travis.sh ] && source /Users/tomas.konrady/.travis/travis.sh
