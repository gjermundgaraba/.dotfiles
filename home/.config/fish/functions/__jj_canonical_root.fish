function __jj_canonical_root --argument-names workspace_root
    set -l repo_ref $workspace_root/.jj/repo

    if path is -d $repo_ref
        path dirname -- (path dirname -- (path resolve -- $repo_ref))
    else if path is -f $repo_ref
        set -l shared_repo_ref (string trim -- (cat $repo_ref))
        path dirname -- (path dirname -- (path resolve -- (path dirname -- $repo_ref)/$shared_repo_ref))
    else
        echo $workspace_root
    end
end
