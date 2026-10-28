if test -d /opt/homebrew
    set -gx HOMEBREW_PREFIX /opt/homebrew
    set -gx HOMEBREW_REPOSITORY /opt/homebrew
else if test -d /home/linuxbrew/.linuxbrew
    set -gx HOMEBREW_PREFIX /home/linuxbrew/.linuxbrew
    set -gx HOMEBREW_REPOSITORY /home/linuxbrew/.linuxbrew/Homebrew
end
if set -q HOMEBREW_PREFIX
    set -gx HOMEBREW_CELLAR $HOMEBREW_PREFIX/Cellar
    fish_add_path --global --move --path $HOMEBREW_PREFIX/bin $HOMEBREW_PREFIX/sbin
    if test -n "$MANPATH[1]"
        set -gx MANPATH '' $MANPATH
    end
    if not contains $HOMEBREW_PREFIX/share/info $INFOPATH
        set -gx INFOPATH $HOMEBREW_PREFIX/share/info $INFOPATH
    end
end
