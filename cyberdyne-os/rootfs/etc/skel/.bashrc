# Cyberdyne OS default shell setup.
case $- in *i*) ;; *) return ;; esac

HISTCONTROL=ignoreboth
HISTSIZE=5000
shopt -s histappend checkwinsize

if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi

# Prompt:  [user@host dir] >>
PS1='\[\e[1;31m\][\[\e[0;33m\]\u@\h \[\e[1;37m\]\W\[\e[1;31m\]]\[\e[0m\] >> '

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias scan='hud'
