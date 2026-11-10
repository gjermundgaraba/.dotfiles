function __cached_source
    if test (count $argv) -lt 3
        echo "usage: __cached_source NAME [--dependency FILE] -- COMMAND [ARG ...]" >&2
        return 2
    end

    set -l name $argv[1]
    set -e argv[1]
    set -l dependencies

    while test "$argv[1]" != --
        if test "$argv[1]" != --dependency; or test (count $argv) -lt 3
            echo "__cached_source: expected --dependency FILE or --" >&2
            return 2
        end
        set -a dependencies $argv[2]
        set -e argv[1..2]
    end
    set -e argv[1]

    set -l binary (command -s -- $argv[1])
    if test -z "$binary"
        echo "__cached_source: command not found: $argv[1]" >&2
        return 127
    end
    set binary (path resolve "$binary")

    set -l cache_dir "$HOME/.cache/fish-init"
    test -n "$XDG_CACHE_HOME"; and set cache_dir "$XDG_CACHE_HOME/fish-init"
    command mkdir -p -- "$cache_dir"; or return

    set -l key_parts 1 "$binary" $argv
    for dependency in $dependencies
        set -a key_parts "$dependency"
        if test -e "$dependency"
            set -a key_parts present
        else
            set -a key_parts missing
        end
    end
    set -l escaped_key (string join ' ' -- (string escape -- $key_parts))
    set -l expected_header "# fish-init-cache: $escaped_key"
    set -l cache "$cache_dir/$name.fish"
    set -l refresh 0

    if not test -s "$cache"
        set refresh 1
    else
        read -l cached_header <"$cache"
        test "$cached_header" = "$expected_header"; or set refresh 1
        test "$binary" -nt "$cache"; and set refresh 1
        for dependency in $dependencies
            test -e "$dependency"; and test "$dependency" -nt "$cache"; and set refresh 1
        end
    end

    if test "$refresh" -eq 1
        set -l temporary "$cache.$fish_pid"
        printf '%s\n' "$expected_header" >"$temporary"
        $argv >>"$temporary"
        set -l generate_status $status
        if test "$generate_status" -eq 0
            set -l fish_path (status fish-path)
            "$fish_path" -n "$temporary"
            set generate_status $status
        end
        if test "$generate_status" -eq 0
            command mv -f -- "$temporary" "$cache"
            set generate_status $status
        end
        if test "$generate_status" -ne 0
            command rm -f -- "$temporary"
            test -s "$cache"; or return "$generate_status"
            echo "__cached_source: refresh failed for $name; using previous cache" >&2
        end
    end

    source "$cache"
end
