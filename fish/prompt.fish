# -*- fish -*- #

set -g __fish_prompt_prefix ">"
set -g __fish_git_prompt_showdirtystate 1
set -g __fish_git_prompt_showuntrackedfiles 1
set -g __fish_git_prompt_showstashstate 1
set -g __fish_git_prompt_show_informative_status 1
set -g __fish_git_prompt_char_stagedstate '+'
set -g __fish_git_prompt_char_dirtystate '*'
set -g __fish_git_prompt_char_untrackedfiles '?'
set -g __fish_git_prompt_char_stashstate '$'

if not set -q __fish_prompt_hostname
    if [ $COMPUTERNAME ]
        set -g __fish_prompt_hostname $COMPUTERNAME
    else
        set -g __fish_prompt_hostname (hostname | cut -d . -f 1)
    end
end

function shell_level -d "get SHLVL"
    if [ $SHLVL -ne 1 ]
        echo $SHLVL" "
    end
end

## Defined embedded:functions/fish_prompt.fish @ line 4
function fish_prompt --description 左侧提示符
    set -l last_pipestatus $pipestatus
    set -lx __fish_last_status $status # Export for __fish_print_pipestatus.
    set -l normal (set_color normal)
    # Color the prompt differently when we're root
    set -l color_cwd $fish_color_cwd
    set -l suffix $__fish_prompt_prefix
    if functions -q fish_is_root_user; and fish_is_root_user
        if set -q fish_color_cwd_root
            set color_cwd $fish_color_cwd_root
        end
        set suffix '#'
    end

    # Write pipestatus
    # If the status was carried over (if no command is issued or if `set` leaves the status untouched), don't bold it.
    set -l bold_flag --bold
    set -q __fish_prompt_status_generation; or set -g __fish_prompt_status_generation $status_generation
    if test $__fish_prompt_status_generation = $status_generation
        set bold_flag
    end
    set __fish_prompt_status_generation $status_generation
    set -l status_color (set_color $fish_color_status)
    set -l statusb_color (set_color $bold_flag $fish_color_status)

    set -l prompt_status (__fish_print_pipestatus "[" "]" "|" "$status_color" "$statusb_color" $last_pipestatus)

    echo -n -s (set_color bryellow) (shell_level) $normal (set_color $color_cwd) (prompt_pwd) $normal (fish_vcs_prompt) $normal" "$prompt_status
    if test $__fish_last_status -eq 0
        echo -n -s (set_color brgreen)' '$suffix' '(set_color normal)
    else
        echo -n -s (set_color brred)' '$suffix' '(set_color normal)
    end
end

## Right prompt (fish_right_prompt)
## ============================================================
## Original zsh: '%F{yellow}%j %F{grey}%*%f %F{3}%n@%m'
function fish_right_prompt --description 右侧提示符
    set -l elapsed (math -s0 "$CMD_DURATION / 1000")
    set_color brblack
    if test $elapsed -ge 4
        if test $elapsed -ge 60
            set -l minutes (math -s0 $elapsed / 60)
            set -l seconds (math -s0 $elapsed % 60)
            if test $minutes -ge 60
                set -l hours (math -s0 $minutes / 60)
                set -l remain_mins (math -s0 $minutes % 60)
                echo -n $hours"h"$remain_mins"m"$seconds"s "
            else
                echo -n $minutes"m"$seconds"s "
            end
        else
            echo -n $elapsed"s "
        end
    end
    set_color normal

    ## ------ Background job count (cyan) ------
    set -l job_count (jobs -p | count)
    if test $job_count -gt 0
        echo -n -s (set_color cyan) "%$job_count "
    end
    ## ------ Current time (grey) and user@hostname ------
    echo -n -s (set_color white) (date +%H:%M:%S) ' ' (set_color normal)
    echo -n -s (prompt_login) (set_color normal)
end
