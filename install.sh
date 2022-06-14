stow bin bash zsh vim tmux editorconfig ack skhd yabai nvim
# touch $HOME/.zfunctions/prompt_pure_setup
# touch $HOME/.zfunctions/async

ln -s "$PWD/pure/pure.zsh" "$HOME/.zfunctions/prompt_pure_setup"
ln -s "$PWD/pure/async.zsh" "$HOME/.zfunctions/async"
ln -s "$PWD/limelight/bin/limelight" "/usr/local/bin/limelight"

defaults write com.apple.finder AppleShowAllFiles TRUE
killall Finder

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# https://github.com/koekeishiya/skhd/issues/139#issuecomment-1114305242
# brew services stop skhd
# brew services start skhd --file=$HOME/.skhd/homebrew.mxcl.skhd.plist
