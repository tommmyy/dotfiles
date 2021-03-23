export JAVA_HOME="/Library/Java/JavaVirtualMachines/openjdk-11.0.2.jdk/Contents/Home"
# export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.8.0_161.jdk/Contents/Home"

zoom_join() {
    # param $1   - room number
    # [param $2] - room password
    open "zoommtg://zoom.us/join?action=join&confno=$1&pwd=$2"
}

alias zoomstandup='zoom_join 377931564 123'
alias zoom3='zoom_join 9599590003'
alias docker_clean_images='docker rmi $(docker images -a --filter=dangling=true -q)'
alias docker_clean_ps='docker rm $(docker ps --filter=status=exited --filter=status=created -q)'
alias whatsonport='sudo lsof -i tcp:'

# killonport() {
# if [ "$1" != "" ]
# then
# 	sudo lsof -ti tcp:$1 | sudo xargs kill
# }

alias killonport='f() { sudo lsof -ti tcp:$1 | sudo xargs kill };f'
