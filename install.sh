#!/bin/bash

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install -y git
sudo apt-get install -y emacs24
sudo apt-get install -y tmux

# configure git
git config --global user.name "Patrick Flynn"
git config --global credential.helper cache
git config --global credential.helper "cache --timeout=31540000000"

cd ~
git clone https://github.com/patflynn/cosmo.git
echo ". ~/cosmo/dotfiles/.bashrc" >> ~/.bashrc
ln -s /home/${USER}/cosmo/dotfiles/.tmux.conf /home/${USER}/.tmux.conf
ln -s /home/${USER}/cosmo/.local/share/applications/emacsclient.desktop /home/${USER}/.local/share/applications/emacsclient.desktop
# install prelude for emacs
curl -L http://git.io/epre | sh
rm -rf /home/${USER}/.emacs.d/personal
ln -s /home/${USER}/cosmo/prelude /home/${USER}/.emacs.d/personal

