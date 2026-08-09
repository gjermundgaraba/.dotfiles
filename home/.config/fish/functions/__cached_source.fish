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

    set -l cache_user (string replace -ra '[^A-Za-z0-9_.-]' _ -- "$USER")
    set -l cache_dir "/tmp/fish-init-cache-$cache_user"
    if not test -e "$cache_dir"
        command mkdir -m 700 -- "$cache_dir" 2>/dev/null
    end

    if test -L "$cache_dir"; or not test -d "$cache_dir"; or not test -O "$cache_dir"
        echo "__cached_source: unsafe cache directory: $cache_dir; running uncached" >&2
        $argv | source
        set -l statuses $pipestatus
        for code in $statuses
            test "$code" -eq 0; or return "$code"
        end
        return 0
    end

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

if test "$argv[1]" = --self-test
    set -lx USER "__cached_source_test_$fish_pid"
    set -l work "/tmp/$USER"
    set -l generator "$work/generator.fish"
    set -l counter "$work/count"
    set -l dependency "$work/dependency"
    command mkdir -m 700 -- "$work"
    command touch "$dependency"
    printf '%s\n' \
        '#!/opt/homebrew/bin/fish' \
        'set -l count 0' \
        'test -f "$argv[1]"; and read count <"$argv[1]"' \
        'set count (math "$count" + 1)' \
        'echo "$count" >"$argv[1]"' \
        'if test "$argv[2]" = invalid' \
        '    echo "function broken ("' \
        else \
        '    echo "set -g __cached_source_test_loaded $count"' \
        end >"$generator"
    command chmod +x "$generator"

    set -l failed 0
    __cached_source test --dependency "$dependency" -- "$generator" "$counter"
    test "$__cached_source_test_loaded" = 1; or set failed 1
    __cached_source test --dependency "$dependency" -- "$generator" "$counter"
    read -l generated_count <"$counter"
    test "$generated_count" = 1; or set failed 1
    command sleep 0.01
    command touch "$dependency"
    __cached_source test --dependency "$dependency" -- "$generator" "$counter"
    read -l generated_count <"$counter"
    test "$generated_count" = 2; or set failed 1
    __cached_source test --dependency "$dependency" -- "$generator" "$counter" invalid 2>/dev/null
    read -l generated_count <"$counter"
    test "$generated_count" = 3; or set failed 1
    test "$__cached_source_test_loaded" = 2; or set failed 1

    command rm -rf -- "$work" "/tmp/fish-init-cache-$USER"
    test "$failed" -eq 0; or exit 1
    echo "__cached_source self-check passed"
end
