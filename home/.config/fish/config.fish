set -gx HOMEBREW_PREFIX /opt/homebrew
set -gx HOMEBREW_CELLAR /opt/homebrew/Cellar
set -gx HOMEBREW_REPOSITORY /opt/homebrew
fish_add_path --global --move --path /opt/homebrew/bin /opt/homebrew/sbin
fish_add_path --global --move --path "$HOME/.vite-plus/bin"
if test -n "$MANPATH[1]"
    set -gx MANPATH '' $MANPATH
end
if not contains /opt/homebrew/share/info $INFOPATH
    set -gx INFOPATH /opt/homebrew/share/info $INFOPATH
end

if command -q carapace
    __cached_source carapace -- carapace _carapace fish
end

set -gx EDITOR nvim

# Raindrop CLI
fish_add_path -g /Users/gg/.raindrop/bin
fish_add_path -g /Users/gg/.opencode/bin

# pnpm global bin (pnpm refuses -g commands unless this is in PATH)
fish_add_path -g /Users/gg/Library/pnpm/bin

# Keep PATH stable after installers and shell hooks have adjusted it.
set -l deduped_path
for p in $PATH
    contains -- $p $deduped_path; or set -a deduped_path $p
end
set -gx PATH $deduped_path
