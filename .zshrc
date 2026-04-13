alias gs='git status'
alias gl='git log'
export ROOTPATH="$(git rev-parse --show-toplevel)"
export PATH=$PATH:$ROOTPATH
export PROMPT="Starting work on $ROOTPATH"