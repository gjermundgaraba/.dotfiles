function __osc52_copy --description 'Set the terminal clipboard via OSC 52, which also works over SSH'
    printf '\e]52;c;%s\a' (printf '%s' $argv[1] | base64 | string join '') >/dev/tty
end

function yp --description 'Yank a path to the clipboard (defaults to cwd), no trailing newline'
    set -l target
    if set -q argv[1]
        set target (path resolve -- $argv)
    else
        set target $PWD
    end
    set -l text (string join \n -- $target | string collect)
    __osc52_copy $text
    or return
    printf 'copied: %s\n' (string join ', ' -- $target) >&2
end
