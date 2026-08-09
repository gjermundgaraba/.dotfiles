function yp --description 'Yank a path to the clipboard (defaults to cwd), no trailing newline'
    set -l target
    if set -q argv[1]
        set target (path resolve -- $argv)   # like realpath; works even if it doesn't exist yet
    else
        set target $PWD                       # bare `yp` == `pwd | pbcopy`
    end
    printf '%s' (string join \n -- $target) | pbcopy
    printf 'copied: %s\n' (string join ', ' -- $target) >&2
end
