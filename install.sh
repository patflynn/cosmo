#!/bin/bash

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install -y git emacs tmux i3 rofi curl zsh stow golang
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# configure git
git config --global user.name "Patrick Flynn"
git config --global credential.helper cache
git config --global credential.helper "cache --timeout=31540000000"
git config --global alias.lg "log --color --graph --pretty=format:'%C(auto)%h -%d %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'"
git config --global alias.st 'status'
git config --global alias.br 'branch --all'
git config --global alias.cm 'checkout main'
git config --global alias.co 'checkout'
git config --global alias.rbm 'rebase main'
git config --global alias.rbu 'pull --rebase upstream main'
git config --global alias.recommit 'commit -a --reuse-message=HEAD@{1}'
git config --global alias.uncommit 'reset --soft HEAD^'
git config --global alias.last 'log -1 HEAD'
git config --global commit.gpgsign true  # Sign all commits
git config --global tag.gpgsign true  # Sign all tags
git config --global gpg.x509.program gitsign  # Use gitsign for signing
git config --global gpg.format x509  # gitsign expects x509 args
git config --global commit.gpgsign true  # Sign all commits
git config --global tag.gpgsign true  # Sign all tags
git config --global gpg.x509.program gitsign  # Use gitsign for signing
git config --global gpg.format x509  # gitsign expects x509 args
go install github.com/sigstore/gitsign@latest
cd ~
git clone https://github.com/patflynn/cosmo.git
cd cosmo

# configure for chromoting with X34 and i3
stow X

# configure the always stuff


mv ~/.emacs.d ~/tmp/.
mv ~/.config/i3 ~/tmp/.
mv ~/.tmux.conf ~/tmp/.
mv ~/.zshrc ~/tmp/.

stow --target =/home/${USER} X emacs tmux zsh i3








