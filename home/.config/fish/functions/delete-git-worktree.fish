function delete-git-worktree --description 'Delete the current worktree after safety checks'
    if not set -q WANNABE_WORKTREES_BASE
        echo "WANNABE_WORKTREES_BASE is required" >&2
        return 1
    end

    set -l worktree_dir (git rev-parse --show-toplevel 2>/dev/null)
    or begin
        echo "not inside a git repository" >&2
        return 1
    end

    set -l expected_base (path resolve -- $WANNABE_WORKTREES_BASE)
    set -l worktree_dir (path resolve -- $worktree_dir)
    set -l expected_base_pattern (string join '' '^' (string escape --style=regex -- $expected_base) '(/|$)')

    if not string match -qr -- $expected_base_pattern $worktree_dir
        echo "current directory is not inside $WANNABE_WORKTREES_BASE" >&2
        return 1
    end

    set -l git_status (git -C $worktree_dir status --porcelain)

    if set -q git_status[1]
        echo "there are uncommitted changes in the worktree" >&2
        return 1
    end

    set -l unpushed (git -C $worktree_dir rev-list --all --not --remotes)
    or begin
        echo "could not check for unpushed commits" >&2
        return 1
    end

    if set -q unpushed[1]
        echo "there are commits not reachable from any remote" >&2
        return 1
    end

    read -P "Delete git worktree: $worktree_dir? [y/N] " -l confirm

    if test "$confirm" != y
        echo "aborted" >&2
        return 1
    end

    cd $expected_base
    or return 1

    trash $worktree_dir
    or return 1

    echo "Deleted $worktree_dir"
end
