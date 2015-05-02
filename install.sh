#!/bin/bash

sudo apt-get install -y git
sudo apt-get install -y emacs24
sudo apt-get install -y tmux

cd ~
git clone https://github.com/patflynn/cosmo.git
echo ". ~/cosmo/dotfiles/.bashrc" >> ~/.bashrc
ln -s /home/${USER}/cosmo/dotfiles/.tmux.conf /home/${USER}/.tmux.conf
# install prelude for emacs
curl -L http://git.io/epre | sh
rm -rf /home/${USER}/.emacs.d/personal
ln -s /home/${USER}/cosmo/prelude /home/${USER}/.emacs.d/personal

