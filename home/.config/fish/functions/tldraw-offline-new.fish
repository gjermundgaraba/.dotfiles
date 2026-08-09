function tldraw-offline-new --description 'Create a new empty <name>.tldraw in the current directory via tldraw Desktop'
    if test (count $argv) -ne 1
        echo "usage: tldraw-offline-new <name>" >&2
        return 1
    end
    sh "$HOME/skills/tldraw-offline/tq" POST /api/docs/create \
        (jq -nc --arg name $argv[1] --arg directory $PWD '{$name, $directory}')
end
