export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-15.0.2.jdk/Contents/Home"
# export JAVA_HOME="/Library/Java/JavaVirtualMachines/openjdk-11.0.2.jdk/Contents/Home"
# export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.8.0_161.jdk/Contents/Home"

# For compilers to find openjdk you may need to set:
#  export CPPFLAGS="-I/usr/local/opt/openjdk/include"
#
 export PATH="/opt/homebrew/opt/openjdk@11/bin:$PATH"
 export JVA_HOME="/opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home"

zoom_join() {
    # param $1   - room number
    # [param $2] - room password
    open "zoommtg://zoom.us/join?action=join&confno=$1&pwd=$2"
}

alias zoom3='zoom_join 9599590003'
alias zoommilan='zoom_join 4631653088 Rll2SENtU0VyOGFGTmt1TkoxRGRsUT09'
alias zoomfastai='zoom_join 377931564 123'
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

eval "$(/opt/homebrew/bin/brew shellenv)"
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


