set -l root (path resolve (path dirname (status filename))/..)
set -l tmp (mktemp -d)

function cleanup --on-event fish_exit
    rm -rf $tmp
end

source $root/home/.config/fish/functions/delete-git-worktree.fish
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

string match --quiet '*git branch -d*' (git config --file $root/home/.config/git/config --get alias.delete-untracked)
and test (git config --file $root/home/.config/git/config --get alias.delete-gone-branches) = '!$HOME/.config/git/delete-gone-branches'
and test -x $root/home/.config/git/delete-gone-branches
or exit 1

set -l repo $tmp/worktrees/repo
set -l base_sha (git -C $repo rev-parse main)
git -C $repo switch --quiet -c pr-head main
printf 'if True:\n    print("safe")\n' >$repo/code.py
git -C $repo add code.py
git -C $repo commit --quiet -m 'PR head'
set -l pr_sha (git -C $repo rev-parse HEAD)
git -C $repo switch --quiet -c whitespace main
printf 'if True:\nprint("safe")\n' >$repo/code.py
git -C $repo add code.py
git -C $repo commit --quiet -m 'different whitespace'
set -l local_sha (git -C $repo rev-parse HEAD)
git -C $repo switch --quiet main

git -C $repo branch exact $pr_sha
git -C $repo tag exact $base_sha
git -C $repo branch retained $local_sha
git -C $repo branch race $pr_sha
for branch in exact whitespace retained race
    git -C $repo config branch.$branch.remote origin
    git -C $repo config branch.$branch.merge refs/heads/$branch
end
git -C $repo push --quiet origin $local_sha:refs/heads/retainer
string match --quiet -- '- *' (git -C $repo cherry $pr_sha $local_sha)
or exit 1

mkdir $tmp/bin
printf '%s\n' '#!/bin/sh' \
    'if [ "$1" = repo ]; then printf "owner/repo\n"; exit; fi' \
    'for arg do case "$arg" in head=owner:*) branch=${arg#head=owner:};; esac; done' \
    'case "$branch" in' \
    '  exact|whitespace) head=$PR_SHA;;' \
    '  retained) head=$BASE_SHA;;' \
    '  race) git -C "$TEST_REPO" update-ref refs/heads/race "$LOCAL_SHA"; head=$PR_SHA;;' \
    '  *) printf "[]\n"; exit;;' \
    esac \
    'printf "[{\"number\":1,\"html_url\":\"https://example.test/1\",\"head\":{\"sha\":\"%s\"},\"merged_at\":\"2025-01-01T00:00:00Z\",\"state\":\"closed\"}]\n" "$head"' >$tmp/bin/gh
chmod +x $tmp/bin/gh

set -lx PATH $tmp/bin $PATH
set -lx TEST_REPO $repo
set -lx BASE_SHA $base_sha
set -lx PR_SHA $pr_sha
set -lx LOCAL_SHA $local_sha
pushd $repo >/dev/null
set -l output ($root/home/.config/git/delete-gone-branches --dry-run)
set -l delete_gone_status $status
popd >/dev/null
test $delete_gone_status -eq 0
and string match --quiet 'WOULD DELETE exact:*' $output
and string match --quiet 'SKIP   whitespace:*' $output
and string match --quiet 'SKIP   retained:*' $output
and string match --quiet 'SKIP   race:*' $output
and test (git -C $repo rev-parse refs/heads/race) = $local_sha
or exit 1

echo "safety checks passed"
