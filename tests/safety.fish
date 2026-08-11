set -l root (path resolve (path dirname (status filename))/..)
set -l tmp (mktemp -d)

function cleanup --on-event fish_exit
    rm -rf $tmp
end

source $root/home/.config/fish/functions/delete-git-worktree.fish
source $root/home/.config/fish/functions/link-agents-md.fish

mkdir -p $tmp/links/{managed,foreign,broken}
touch $tmp/links/{managed,broken}/AGENTS.md $tmp/links/foreign/README.md
ln -s README.md $tmp/links/foreign/CLAUDE.md
ln -s missing.md $tmp/links/broken/CLAUDE.md
link-agents-md $tmp/links >/dev/null
test (readlink $tmp/links/managed/CLAUDE.md) = AGENTS.md
and test (readlink $tmp/links/foreign/CLAUDE.md) = README.md
and test (readlink $tmp/links/broken/CLAUDE.md) = missing.md
or exit 1

git init --bare --quiet --initial-branch=main $tmp/origin.git
git init --quiet --initial-branch=main $tmp/seed
git -C $tmp/seed config user.email test@example.com
git -C $tmp/seed config user.name Test
touch $tmp/seed/README
git -C $tmp/seed add README
git -C $tmp/seed commit --quiet -m initial
git -C $tmp/seed remote add origin $tmp/origin.git
git -C $tmp/seed push --quiet -u origin main
mkdir $tmp/worktrees
git clone --quiet $tmp/origin.git $tmp/worktrees/repo
git -C $tmp/worktrees/repo config user.email test@example.com
git -C $tmp/worktrees/repo config user.name Test
git -C $tmp/worktrees/repo switch --quiet -c unpublished
touch $tmp/worktrees/repo/unpublished
git -C $tmp/worktrees/repo add unpublished
git -C $tmp/worktrees/repo commit --quiet -m unpublished
git -C $tmp/worktrees/repo switch --quiet main
set -gx WANNABE_WORKTREES_BASE $tmp/worktrees
pushd $tmp/worktrees/repo >/dev/null
delete-git-worktree </dev/null >/dev/null 2>&1
set -l delete_status $status
popd >/dev/null
test $delete_status -ne 0
and test -d $tmp/worktrees/repo
or exit 1

git -C $tmp/worktrees/repo -c include.path=$root/home/.config/git/config delete-untracked >/dev/null 2>&1
git -C $tmp/worktrees/repo show-ref --verify --quiet refs/heads/unpublished
or exit 1

for alias in delete-untracked delete-gone-branches
    string match --quiet '*git branch -d*' (git config --file $root/home/.config/git/config --get alias.$alias)
    or exit 1
end

echo "safety checks passed"
