# copy the active line from the command line buffer 
# onto the system clipboard

#detect os
if [[ -f /proc/version ]] && grep -iq Microsoft /proc/version; then
  os=WSL
else
  case "$(uname -s)" in
    Linux*)     os=LINUX;;
    Darwin*)    os=MAC;;
    CYGWIN*)    os=CYGWIN;;
  esac
fi

case $os in
  LINUX)
    if which xclip &>/dev/null; then
      copycmd="xclip -r -sel clip"
    elif which xsel &>/dev/null; then
      copycmd="xsel -ib"
    elif which clipcopy &>/dev/null; then
      copycmd="clipcopy"
    elif which wl-copy &>/dev/null; then
      copycmd="wl-copy"
    fi;;
  MAC)
    if which pbcopy &>/dev/null; then
      copycmd="pbcopy"
    fi;;
  CYGWIN)
    copycmd="cat > /dev/clipboard";;
  WSL)
    if test -f "/mnt/c/Windows/System32/clip.exe"; then
      copycmd="/mnt/c/Windows/System32/clip.exe"
    fi;;
esac

copybuffer () {
  # If line is empty, get the last run command from history
  if test -z $BUFFER; then
    buf=$(fc -ln -1)
  else
    buf=$BUFFER
  fi

  if test -n $copycmd; then
    printf "%s" "$buf" | eval $copycmd
  else
    zle -M "clipboard copy program not found. Please make sure you have one installed (example: xclip/xsel/wl-clipboard)."
  fi
}

zle -N copybuffer

bindkey -M emacs "^O" copybuffer
bindkey -M viins "^O" copybuffer
bindkey -M vicmd "^O" copybuffer

