# export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-15.0.2.jdk/Contents/Home"
# export JAVA_HOME="/Library/Java/JavaVirtualMachines/openjdk-11.0.2.jdk/Contents/Home"
# export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.8.0_161.jdk/Contents/Home"

# For compilers to find openjdk you may need to set:
#  export CPPFLAGS="-I/usr/local/opt/openjdk/include"
#
 # export PATH="/opt/homebrew/opt/openjdk@11/bin:$PATH"
 # export JAVA_HOME="/opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home"

 # export PATH="/opt/homebrew/opt/openjdk@18/bin:$PATH"
 # export JAVA_HOME="/opt/homebrew/opt/openjdk@18/libexec/openjdk.jdk/Contents/Home"

 # brew install --cask adoptopenjdk/openjdk/adoptopenjdk8
 # export PATH="/Library/Java/JavaVirtualMachines/adoptopenjdk-8.jdk/Contents/Home/bin:$PATH"
 # export JAVA_HOME="/Library/Java/JavaVirtualMachines/adoptopenjdk-8.jdk/Contents/Home"
 #
 #
 # export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
 # export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"

export PATH=$HOME/.tmux/plugins/tmux-session-wizard/bin:$PATH

alias pinentry='pinentry-mac'

alias docker_clean_images='docker rmi $(docker images -a --filter=dangling=true -q)'
alias docker_clean_ps='docker rm $(docker ps --filter=status=exited --filter=status=created -q)'
alias whatsonport='f() { sudo lsof -ti tcp:$1};f'


# killonport() {
# if [ "$1" != "" ]
# then
# 	sudo lsof -ti tcp:$1 | sudo xargs kill
# }

alias killonport='f() { sudo lsof -ti tcp:$1 | sudo xargs kill };f'

bindkey -s ^f "tmux-sessionizer\n"

export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"
#https://unix.stackexchange.com/questions/222901/caret-square-bracket-square-bracket-a-a-what-does-it-mean
# https://github.com/jinzhu/configure/blob/master/.shell/zsh/bindkey
user-complete(){
    case $BUFFER in
        "" )
        BUFFER="cd "
        zle end-of-line
        zle expand-or-complete
        ;;
        * )
        zle expand-or-complete
        ;;
    esac
}
zle -N user-complete
bindkey "\t" user-complete

