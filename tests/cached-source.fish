set -l root (path resolve (path dirname (status filename))/..)
source $root/home/.config/fish/functions/__cached_source.fish

set -lx USER "__cached_source_test_$fish_pid"
set -l work "/tmp/$USER"
set -l generator "$work/generator.fish"
set -l counter "$work/count"
set -l dependency "$work/dependency"
command mkdir -m 700 -- "$work"
command touch "$dependency"
printf '%s\n' \
    "#!"(status fish-path) \
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
echo "cached source checks passed"
