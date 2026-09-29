stow bin bash zsh opencode tmux editorconfig ack nvim worktrunk linear-session linear-workmux finicky launchd
# Gitignored secrets package (Google service-account key for the personal-kids
# skill); present only on machines where it was set up.
[ -d personal-kids ] && stow personal-kids

# launchd only reads ~/Library/LaunchAgents at login, so stowing a plist is not
# enough on a machine that is already running.
for label in com.tommmyy.worklog-standup com.tommmyy.worklog-cycle com.tommmyy.kids-meal-sync; do
	launchctl bootout "gui/$(id -u)/$label" 2>/dev/null
	launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$label.plist"
done
# stow bin bash zsh opencode vim tmux editorconfig ack skhd yabai nvim mcphub
# touch $HOME/.zfunctions/prompt_pure_setup
# touch $HOME/.zfunctions/async

ln -s "$PWD/pure/pure.zsh" "$HOME/.zfunctions/prompt_pure_setup"
ln -s "$PWD/pure/async.zsh" "$HOME/.zfunctions/async"
ln -s "$PWD/limelight/bin/limelight" "/usr/local/bin/limelight"

defaults write com.apple.finder AppleShowAllFiles TRUE
killall Finder

# git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
# git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# https://github.com/koekeishiya/skhd/issues/139#issuecomment-1114305242
# brew services stop skhd
# brew services start skhd --file=$HOME/.skhd/homebrew.mxcl.skhd.plist
