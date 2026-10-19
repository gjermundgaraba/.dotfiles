function yp --description 'Yank a path to the clipboard (defaults to cwd), no trailing newline'
    set -l target
    if set -q argv[1]
        set target (path resolve -- $argv)   # like realpath; works even if it doesn't exist yet
    else
        set target $PWD                       # bare `yp` copies the cwd
    end
    set -l text (string join \n -- $target | string collect)
    # OSC 52 asks the terminal to set its clipboard, which also works over SSH.
    printf '\e]52;c;%s\a' (printf '%s' $text | base64 | string join '') >/dev/tty
    or return
    printf 'copied: %s\n' (string join ', ' -- $target) >&2
end
