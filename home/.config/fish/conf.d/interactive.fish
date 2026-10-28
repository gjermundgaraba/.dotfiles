status is-interactive; or return

source $HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.fish
__cached_source atuin --dependency "$HOME/.config/atuin/config.toml" --dependency "$HOME/.config/atuin/atuin-receipt.json" -- atuin init fish --disable-up-arrow
__cached_source zoxide -- zoxide init fish

bind shift-tab accept-autosuggestion
bind super-shift-l forward-word

abbr -a ll "ls -alh"

abbr -a gs "git status"
abbr -a ga "git add"
abbr -a gc "git commit"
abbr -a gp "git push"
abbr -a gl "git log"
abbr -a gd "git diff"
abbr -a gds "git diff --staged"
abbr -a gr "git restore"
abbr -a gsw "git switch"
function gmain
    git switch (git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | string split -m1 -f2 /; or echo main) && git pull
end
function gmainb
    gmain && git switch -
end

abbr -a js "jj st"
abbr -a jd "jj diff"

abbr -a ds "dotfiles status"
abbr -a da "dotfiles add"
abbr -a dc "dotfiles commit"
abbr -a dp "dotfiles push"
abbr -a dl "dotfiles log"
abbr -a dd "dotfiles diff"
abbr -a dds "dotfiles diff --staged"
abbr -a dr "dotfiles restore"

abbr -a telpers "cd ~/ws/pers"
abbr -a telpi "cd ~/.pi/agent/"

abbr -a cfgclaude "nvim ~/.claude/settings.json"
abbr -a cfgpi "cd ~/.pi/agent/ && nvim"

abbr -a cb clankerbox
alias librarian-checkout "$HOME/.agents/skills/librarian/checkout.sh"
abbr -a codx-luna "codex -c 'model_reasoning_effort=xhigh' --model gpt-6.1-luna"
abbr -a codx-ultra "codex -c 'model_reasoning_effort=ultra' --model gpt-6-astra"
abbr -a codx-daybreak "codex -c 'model_reasoning_effort=xhigh' --model gpt-daybreak-blue-latest"

abbr -a oc "opencode"

abbr -a cc "claude"
abbr -a cc-opus "claude --model opus"
abbr -a cc-sonnet "claude --model sonnet"
abbr -a cc-fable "claude --model fable"
abbr -a cc-workflows 'claude --settings \'{"disableWorkflows": false}\''
abbr -a cc-artifacts 'claude --settings \'{"enableArtifact": true}\''

abbr -a pi-grok "pi --model xai/grok-4.6 --thinking xhigh"
abbr -a pi-glm "pi --model zai/glm-5.3 --thinking max"
abbr -a pi-flash "pi --model radius/deepseek-v4.1-flash --thinking high"
abbr -a pi-astra "pi --model openai/gpt-6-astra --thinking high"
