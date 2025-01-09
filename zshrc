# Resolve symbolic link if present and get the directory this script lives in.
# NOTE: "readlink -f" is best but works on Linux only, "readlink" will only work if your PWD
# contains the link you are calling (which is the best we can do on macOS), and the "echo" is the 
# fallback, which doesn't attempt to do anything with links.
real_location="$(readlink -f "$0" 2>/dev/null || readlink "$0" 2>/dev/null || echo "$0")"

cur_dir=`cd $(dirname "$real_location");pwd`

if [[ $_en_xtrc -eq 1 ]]; then
  zmodload zsh/datetime
  PS4='+$EPOCHREALTIME %N:%i> '

  logfile=$(mktemp /tmp/zsh_xtrace.$$.XXXXXX.log)
  echo "Logging to $logfile"
  exec 3>&2 2>$logfile

  setopt XTRACE
fi

# local pre
localpre=$cur_dir/localpre
if [ -d $localpre ]; then
  for i in $localpre/*sh; do
    if [ -r $i ]; then
      source $i
    fi
  done
fi

# zsh-prompt {{{1
plugins=$cur_dir/plugins
plug_arr=(
  "$plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
  "$plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
)

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

() {
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
# zsh-prompt }}}1

### config
source ${cur_dir}/zsh-config.zsh
# source ${cur_dir}/zba.sh ## decrapated after v1.0.0
test -e ${cur_dir}/common.sh && source ${cur_dir}/common.sh

unset real_location cur_dir

if [[ $_en_xtrc -eq 1 ]]; then
  unsetopt XTRACE
  exec 2>&3 3>&-
fi
# vim:fdm=marker
