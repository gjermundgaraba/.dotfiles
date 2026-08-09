function new-jj-checkout --description 'Create or refresh a jj workspace for checking out a remote branch'
    if not set -q argv[1]
        echo "usage: new-jj-checkout <branch_name>" >&2
        return 1
    end

    set -l branch_name $argv[1]
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
    set -l safe_branch (string replace -a / - $branch_name)
    set -l workspace_dir $workspaces_base/$repo_name/$safe_branch

    mkdir -p (path dirname -- $workspace_dir)
    or return 1

    if test -d $workspace_dir
        cd $workspace_dir
        or return 1

        set -l workspace_changes (jj diff --summary -r @ 2>/dev/null)

        if set -q workspace_changes[1]
            echo "there are uncommitted changes in the workspace" >&2
            return 1
        end

        jj git fetch --remote origin -b $branch_name
        or return 1

        jj new $branch_name@origin
        or return 1
    else
        jj git fetch --remote origin -b $branch_name
        or return 1

        jj workspace add --name $branch_name -r $branch_name@origin $workspace_dir
        or return 1

        cd $workspace_dir
        or return 1
    end

    link-agents-md .
end
