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

PS1='\[\033[32m\]\u@\h\[\033[00m\]:\[\033[34m\]\w\[\033[31m\]$(__git_ps1)\[\033[00m\]\$ '

if command -v tmux>/dev/null; then
    [[ ! $TERM =~ screen ]] && [ -z $TMUX ] && exec tmux
fi

alias e='emacsclient -t'
alias ec='emacsclient -c'
