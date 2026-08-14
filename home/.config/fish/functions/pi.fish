function pi --description "pi with pinned node major and V8 compile cache"
    set -lx VP_NODE_VERSION 26
    set -lx NODE_COMPILE_CACHE ~/.cache/node-compile-cache
    command pi $argv
end
