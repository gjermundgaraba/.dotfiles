function new-jj-workspace --description 'Create a new jj workspace for the current repo'
    if not set -q argv[1]
        echo "usage: new-jj-workspace <workspace_name> [revset]" >&2
        return 1
    end

    if set -q argv[3]
        echo "usage: new-jj-workspace <workspace_name> [revset]" >&2
        return 1
    end

    set -l workspace_name $argv[1]
    set -l workspace_revset '@-'

    if set -q argv[2]
        set workspace_revset $argv[2]
    end

    set -l workspaces_base /Users/gg/code/jj-ws

    if set -q JJ_WORKSPACES_BASE
        set workspaces_base $JJ_WORKSPACES_BASE
    end

    set -l workspace_root (jj root 2>/dev/null)
    or begin
        echo "current directory must be inside a jj repo" >&2
        return 1
    end

    set -l canonical_root (__jj_canonical_root $workspace_root)

    set -l repo_name (path basename -- $canonical_root)
    set -l safe_workspace (string replace -a / - $workspace_name)
    set -l workspace_parent $workspaces_base/$repo_name
    set -l workspace_dir $workspace_parent/$safe_workspace

    if contains -- $workspace_name (jj workspace list -T 'name ++ "\n"' 2>/dev/null)
        echo "workspace '$workspace_name' already exists" >&2
        return 1
    end

    if test -e $workspace_dir
        echo "workspace directory '$workspace_dir' already exists" >&2
        return 1
    end

    mkdir -p $workspace_parent
    or return 1

    jj workspace add --name $workspace_name -r $workspace_revset $workspace_dir
    or return 1

    cd $workspace_dir
    or return 1

    link-agents-md .
end
