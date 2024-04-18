# export TERM=xterm-256color

## source: manjaro-zsh-prompt [begin]
#set -x
real_location=`readlink -f "$0"`

cur_dir=`cd $(dirname "$real_location");pwd`
plugins=$cur_dir/plugins

plug_arr=(
"$plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
"$plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
)
# "$plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
for i in ${plug_arr[*]}; do
  if [ -r $i ]; then
    source $i
  fi
done

plugsfile=$cur_dir/plugsfile
if [ -d $plugsfile ]; then
  for i in $plugsfile/*.zsh; do
    if [ -r $i ]; then
      source $i
    fi
  done
fi

unset real_dir plugins plug_arr plugsfile i

# exit

() {
  emulate -L zsh

  # Determine terminal capabilities.
  {
    if ! zmodload zsh/langinfo zsh/terminfo ||
       [[ $langinfo[CODESET] != (utf|UTF)(-|)8 || $TERM == (dumb|linux) ]] ||
       (( terminfo[colors] < 256 )); then
      # Don't use the powerline config. It won't work on this terminal.
      local USE_POWERLINE=false
      # Define alias `x` if our parent process is `login`.
      local parent
      if { parent=$(</proc/$PPID/comm) } && [[ ${parent:t} == login ]]; then
        alias x='startx ~/.xinitrc'
      fi
    fi
  } 2>/dev/null

  if [[ $USE_POWERLINE == false ]]; then
    # Use 8 colors and ASCII.
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=black,bold'
  else
    # Use 256 colors and UNICODE.
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=246'
  fi
}
## source: manjaro-zsh-prompt [end]


## https://github.com/skywind3000/z.lua depend: lua
# eval "$(lua /usr/local/src/z.lua/z.lua --init zsh enhanced once echo)"
# export _ZL_DATA=~/.local/zlua.list

### config
source ${cur_dir}/zsh-config
source ${cur_dir}/zba.sh
unset cur_dir 
