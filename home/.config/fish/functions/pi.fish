function pi --description "pi with pinned Node version and V8 compile cache"
    if not test -r "$HOME/.node-version"
        echo "pi: missing $HOME/.node-version" >&2
        return 1
    end
    set -lx VP_NODE_VERSION (string trim <"$HOME/.node-version")
    set -lx NODE_COMPILE_CACHE ~/.cache/node-compile-cache
    command pi $argv
end
