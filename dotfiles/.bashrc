if [ -f $HOME/dotfiles/.bash_aliases ]; then
    . $HOME/dotfiles/.bash_aliases
fi

export TERM=xterm-256color
export EDITOR=emacsclient
export ALTERNATE_EDITOR=""

if command -v tmux>/dev/null; then
    [[ ! $TERM =~ screen ]] && [ -z $TMUX ] && exec tmux
fi

alias e='emacsclient -t'
alias ec='emacsclient -c'

emacs --daemon
