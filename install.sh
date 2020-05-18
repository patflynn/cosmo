#!/bin/bash

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install -y git emacs tmux i3 rofi curl zsh stow
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# configure git
git config --global user.name "Patrick Flynn"
git config --global credential.helper cache
git config --global credential.helper "cache --timeout=31540000000"
git config --global alias.lg "log --color --graph --pretty=format:'%C(auto)%h -%d %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'"
git config --global alias.st 'status'
git config --global alias.br 'branch --all'
git config --global alias.cm 'checkout master'
git config --global alias.co 'checkout'
git config --global alias.rbm 'rebase master'
git config --global alias.recommit 'commit -a --reuse-message=HEAD@{1}'
git config --global alias.uncommit 'reset --soft HEAD^'
git config --global alias.last 'log -1 HEAD'

cd ~
git clone https://github.com/patflynn/cosmo.git
cd cosmo

# configure for chromoting with X34 and i3
stow X

# configure the always stuff
stow i3 emacs tmux zsh








