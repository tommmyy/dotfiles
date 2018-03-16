cat art

# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

source $ZSH/oh-my-zsh.sh

export fpath=( "$HOME/.zfunctions" $fpath )

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME=""

# Set list of themes to load
# Setting this variable when ZSH_THEME=random
# cause zsh load theme from this variable instead of
# looking in ~/.oh-my-zsh/themes/
# An empty array have no effect
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  yarn
  dotenv
  vi-mode
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

#  Aliases
# For a full list of active aliases, run `alias`.
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"
alias ohmyzsh="vim ~/.oh-my-zsh"
alias reloadZshconfig=". ~/.zshrc"

alias vimconfig="vim ~/.vimrc"
alias cls="clear"
alias ls="ls -a"
alias v="vim"	

# Projects
alias nel="~/Workspaces/NeL/frontend/react-union/"
alias eliska="~/Workspaces/NeL/frontend/react-union/src/modules/EliskaPrototypeEntry"
alias setupeliska="cp -R ~/Workspaces/reactPermissions ~/Workspaces/NeL/frontend/react-union/src/modules && rm -r ~/Workspaces/NeL/frontend/react-union/node_modules/.cache"
alias reseteliska="git checkout HEAD -- ~/Workspaces/NeL/frontend/react-union/src/modules/reactPermissions/Permissions.js ~/Workspaces/NeL/frontend/react-union/src/modules/reactPermissions/withPermissions.js ~/Workspaces/NeL/frontend/react-union/src/public/eliskaPrototypeEntry/index.ejs"

alias sanalytics="cd ~/Workspaces/sdp/s-analytics"

alias union="~/Workspaces/react-union/"
alias unionbasic="~/Workspaces/react-union/boilerplates/react-union-boilerplate-basic/"
alias unionredux="~/Workspaces/react-union/boilerplates/react-union-boilerplate-redux/"
	
alias mptrasy="cd ~/Workspaces/mp-trasy/admin"


autoload -U promptinit; promptinit
prompt pure

source ~/.zprofile
