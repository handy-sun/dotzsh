# Copies the path of given directory or file to the system or X Windows clipboard.
# Copy current directory if no parameter.

if which xclip &>/dev/null; then
    copycmd="xclip -r -sel clip"
elif which xsel &>/dev/null; then
    copycmd="xsel -ib"
elif which clipcopy &>/dev/null; then
    copycmd="clipcopy"
elif which wl-copy &>/dev/null; then
    copycmd="wl-copy"
fi;

copypath () {
    # If no argument passed, use current directory
    local file="${1:-.}"

    # If argument is not an absolute path, prepend $PWD
    [[ $file = /* ]] || file="$PWD/$file"

    # Copy the absolute path without resolving symlinks
    # If clipcopy fails, exit the function with an error
    print -n "${file:a}" | eval $copycmd || return 1

    echo ${(%):-"%B${file:a}%b copied to clipboard."}
}

