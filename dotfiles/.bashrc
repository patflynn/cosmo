if [ -f $HOME/dotfiles/.bash_aliases ]; then
    . $HOME/dotfiles/.bash_aliases
fi

export TERM=xterm-256color
export EDITOR=emacsclient
export ALTERNATE_EDITOR=""

# Set git autocompletion and PS1 integration                            
if [ -f /usr/local/git/contrib/completion/git-completion.bash ]; then
  . /usr/local/git/contrib/completion/git-completion.bash
fi
if [ -f /opt/local/share/doc/git-core/contrib/completion/git-prompt.sh ]; then
  . /opt/local/share/doc/git-core/contrib/completion/git-prompt.sh
fi
GIT_PS1_SHOWDIRTYSTATE=true                          

if [ -f /opt/local/etc/bash_completion ]; then
    . /opt/local/etc/bash_completion
fi

#PS1="\${debian_chroot:+(\$debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\] \[$txtcyn\]\$git_branch\[$txtred\]\$git_dirty\[$txtrst\]\$ "
PS1="\${debian_chroot:+(\$debian_chroot)}\[\033[01;32m\]\[\033[00m\]\[\033[01;34m\]\w\[\033[00m\] \[$txtcyn\]\$git_branch\[$txtred\]\$git_dirty\[$txtrst\]\$ "

#if command -v tmx2>/dev/null; then
#    [[ ! $TERM =~ screen ]] && [ -z $TMUX ] && exec tmx2
#fi

alias e='emacsclient -t'
alias ec='emacsclient -c'
