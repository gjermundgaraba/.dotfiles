if command -q carapace
    __cached_source carapace -- carapace _carapace fish
end

set -gx EDITOR nvim

fish_add_path -g $HOME/.opencode/bin

fish_add_path -g $HOME/Library/pnpm/bin

fish_add_path -g $HOME/.bend/bin

fish_add_path -g $HOME/.ascii/bin

if test -f "$HOME/.vite-plus/env.fish"
    source "$HOME/.vite-plus/env.fish"
end

set -l deduped_path
for p in $PATH
    contains -- $p $deduped_path; or set -a deduped_path $p
end
set -gx PATH $deduped_path
