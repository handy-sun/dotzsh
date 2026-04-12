# -*- fish -*- #

function fish_greeting
    set -l drv_info ""
    if test -n "$IN_NIX_SHELL"
        set drv_info "nix-shell ($name)"
    else if test -n "$DIRENV_DIR"
        set drv_info "direnv environment"
    else
        ## Otherwise, read the host's NixOS derivation (strip the /nix/store/ hash prefix)
        set -l sys_path (readlink -f /run/current-system)
        set drv_info (string replace -r '^/nix/store/[a-z0-9]+-' "" $sys_path)
    end

    set -l profile_link (readlink /nix/var/nix/profiles/system)
    set -l cur_ver (string replace -r '.*-(\d+)-link$' '$1' $profile_link)

    set -l nix_ver (nix --version | string replace 'nix ' "")

    echo -s (set_color blue) "❄️ Derivation: " \
            (set_color cyan) "$drv_info" \
            (set_color normal) " | " \
            (set_color blue) "Profile-System: " \
            (set_color yellow) "$cur_ver" \
            (set_color normal) " | " \
            (set_color brblack) "$nix_ver" \
            (set_color normal)
end