source ~/.zprojects

#  Aliases
# For a full list of active aliases, run `alias`.
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"
alias reloadZshconfig=". ~/.zshrc"

alias vimconfig="vim ~/.vimrc"
alias cls="clear"
alias lsa="ls -a"
alias rmrf="rm -rf"
# alias vim="vim --servername VIM"
# alias v="vim --servername VIM"
alias v="vim"
alias fig="lein figwheel"
alias gmu="git fetch upstream && git merge upstream/master"
alias initGitignore="git ignore-io -r node vim sublimetext intellij visualstudiocode webstorm"
alias back="cd $OLDPWD"
alias gcu="git checkout unstable"

alias removeVimJunk="find . -type f -name '*.sw[klmnop]' -delete"

alias lynx="lynx -vikeys --display_charset=utf-8"
alias vpnLunde='osascript -e "tell application \"/Applications/Tunnelblick.app\"" -e "connect \"Lundegaard\"" -e "end tell"'
alias vpnDisconnect='osascript -e "tell application \"/Applications/Tunnelblick.app\"" -e "disconnect all" -e "end tell"'

