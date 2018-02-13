#!/bin/bash

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install -y git
sudo apt-get install -y emacs
sudo apt-get install -y tmux
sudo apt-get install -y i3

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
echo ". ~/cosmo/dotfiles/.bashrc" >> ~/.bashrc
echo ". ~/cosmo/dotfiles/.profile" >> ~/.profile
ln -s ${HOME}/cosmo/dotfiles/.tmux.conf ${HOME}/.tmux.conf
ln -s ${HOME}/cosmo/.local/share/applications/emacsclient.desktop ${HOME}/.local/share/applications/emacsclient.desktop
ln -s ${HOME}/cosmo/dotfiles/.Xresources ${HOME}/.Xresources
# rodete: ln -s ${HOME}/cosmo/dotfiles/.xsessionrc ${HOME}/.xsessionrc
ln -s ${HOME}/cosmo/dotfiles/.xinitrc ${HOME}/.xinitrc
mkdir -p ${HOME}/.config/i3/
ln -s ${HOME}/cosmo/i3config ${HOME}/.config/i3/config

# install prelude for emacs
curl -L http://git.io/epre | sh
rm -rf ${HOME}/.emacs.d/personal
ln -s ${HOME}/cosmo/prelude ${HOME}/.emacs.d/personal

# install bins
ln -s ${HOME}/cosmo/bin/gitcb ${HOME}/bin/gitcb

# install git aware prompt
mkdir ~/.bash
cd ~/.bash
git clone git://github.com/jimeh/git-aware-prompt.git
