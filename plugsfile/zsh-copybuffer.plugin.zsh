# copy the active line from the command line buffer 
# onto the system clipboard

copybuffer () {
  # If line is empty, get the last run command from history
  local buf
  if test -z $BUFFER; then
    buf=$(fc -ln -1)
  else
    buf=$BUFFER
  fi

  local copycmd
  if copycmd=$(getcopycmd); then
    printf "%s" "$buf" | eval $copycmd
  else
    zle -M "clipboard copy program not found. Please make sure you have one installed."
  fi
}

zle -N copybuffer

bindkey -M emacs "^O" copybuffer
bindkey -M viins "^O" copybuffer
bindkey -M vicmd "^O" copybuffer

