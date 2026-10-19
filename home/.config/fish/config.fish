if command -q carapace
    __cached_source carapace -- carapace _carapace fish
end

set -gx EDITOR nvim

# Pi reports its state to Herdr (OSC 7501) without asking whether the
# terminal supports it; Herdr does not answer that query.
if test "$HERDR_ENV" = 1
    set -gx PI_PROGRAM_STATUS 1
end

fish_add_path -g $HOME/.opencode/bin

# pnpm global bin (pnpm refuses -g commands unless this is in PATH)
fish_add_path -g $HOME/Library/pnpm/bin

# Bend (https://bend-lang.com)
fish_add_path -g $HOME/.bend/bin

# Boat
fish_add_path -g $HOME/.ascii/bin

# Vite+ owns Node and JavaScript package managers (see ~/.config/mise/config.toml).
if test -f "$HOME/.vite-plus/env.fish"
    source "$HOME/.vite-plus/env.fish"
end

# Keep PATH stable after installers and shell hooks have adjusted it.
set -l deduped_path
for p in $PATH
    contains -- $p $deduped_path; or set -a deduped_path $p
end
set -gx PATH $deduped_path
