#!/bin/bash

sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install -y git
sudo apt-get install -y emacs24
sudo apt-get install -y tmux

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
ln -s /home/${USER}/cosmo/dotfiles/.tmux.conf /home/${USER}/.tmux.conf
ln -s /home/${USER}/cosmo/.local/share/applications/emacsclient.desktop /home/${USER}/.local/share/applications/emacsclient.desktop
# install prelude for emacs
curl -L http://git.io/epre | sh
rm -rf /home/${USER}/.emacs.d/personal
ln -s /home/${USER}/cosmo/prelude /home/${USER}/.emacs.d/personal

# install bins
ln -s /home/${USER}/cosmo/bin/gitcb /home/${USER}/bin/gitcb

# install Golang

mkdir ~/tmp
curl -o ~/tmp/go1.4.3.tar.gz https://storage.googleapis.com/golang/go1.4.3.linux-amd64.tar.gz
tar xvzf ~/tmp/go1.4.3.tar.gz -C ~/go1.4
rm -rf tmp
mkdir ~/lang
cd ~/lang
git clone https://go.googlesource.com/go
cd go
git checkout go1.5.3
cd src
./all.bash
mkdir bin
ln -s ~/lang/go/bin/go ~/bin/go
ln -s ~/lang/go/bin/gofmt ~/bin/gofmt

# install git aware prompt
mkdir ~/.bash
cd ~/.bash
git clone git://github.com/jimeh/git-aware-prompt.git
