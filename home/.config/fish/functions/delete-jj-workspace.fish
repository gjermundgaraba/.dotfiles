function delete-jj-workspace --description 'Delete the current jj workspace after safety checks'
    set -l workspaces_base /Users/gg/code/jj-ws

    if set -q JJ_WORKSPACES_BASE
        set workspaces_base $JJ_WORKSPACES_BASE
    end

    set -l workspace_dir (jj workspace root 2>/dev/null)
    or begin
        echo "not inside a jj repository" >&2
        return 1
    end

    set -l expected_base (path resolve -- $workspaces_base)
    set -l workspace_dir (path resolve -- $workspace_dir)
    set -l expected_base_pattern (string join '' '^' (string escape --style=regex -- $expected_base) '(/|$)')

    if not string match -qr -- $expected_base_pattern $workspace_dir
        echo "current directory is not inside $workspaces_base" >&2
        return 1
    end

    set -l workspace_changes (jj diff --summary -r @ 2>/dev/null)

    if set -q workspace_changes[1]
        echo "there are uncommitted changes in the workspace" >&2
        return 1
    end

    read -P "Delete jj workspace: $workspace_dir? [y/N] " -l confirm

    if test "$confirm" != y
        echo "aborted" >&2
        return 1
    end

    cd $expected_base
    or return 1

    jj -R $workspace_dir workspace forget
    or return 1

    trash $workspace_dir
    or return 1

    echo "Deleted $workspace_dir"
end
