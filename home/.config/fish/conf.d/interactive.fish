# Only for interactive sessions
status is-interactive; or return

source /opt/homebrew/opt/fzf/shell/key-bindings.fish
__cached_source atuin --dependency "$HOME/.config/atuin/config.toml" --dependency "$HOME/.config/atuin/atuin-receipt.json" -- atuin init fish --disable-up-arrow
__cached_source zoxide -- zoxide init fish

# Keybindings
# Shift+Tab: accept whole autosuggestion
bind shift-tab accept-autosuggestion
# Cmd+Shift+L: accept next word (via ghostty remap)
bind \e\[108\;10u forward-word

# Abbreviations
## terminal stuff
abbr -a ll "ls -alh"

## git
## Additional Git aliases live in ~/.config/git/config.
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

## jj
abbr -a js "jj st"
abbr -a jd "jj diff"

## dotfiles
abbr -a ds "dotfiles status"
abbr -a da "dotfiles add"
abbr -a dc "dotfiles commit"
abbr -a dp "dotfiles push"
abbr -a dl "dotfiles log"
abbr -a dd "dotfiles diff"
abbr -a dds "dotfiles diff --staged"
abbr -a dr "dotfiles restore"

## teleporters
abbr -a telpers "cd ~/ws/pers"
abbr -a telpi "cd ~/.pi/agent/"

## configs
abbr -a cfgclaude "nvim ~/.claude/settings.json"
abbr -a cfgpi "cd ~/.pi/agent/ && nvim"

## misc
abbr -a cb clankerbox
alias librarian-checkout "$HOME/.agents/skills/librarian/checkout.sh"
abbr -a codx-luna "codex -c 'model_reasoning_effort=xhigh' --model gpt-6.1-luna"
abbr -a codx-ultra "codex -c 'model_reasoning_effort=ultra' --model gpt-6-astra"

abbr -a oc "opencode"

abbr -a cc "claude"
abbr -a cc-opus "claude --model opus"
abbr -a cc-sonnet "claude --model sonnet"
abbr -a cc-fable "claude --model fable"
abbr -a cc-workflows 'claude --settings \'{"disableWorkflows": false}\''
abbr -a cc-artifacts 'claude --settings \'{"enableArtifact": true}\''

### pi
abbr -a pi-grok "pi --model xai/grok-4.6 --thinking xhigh"
abbr -a pi-glm "pi --model zai/glm-5.3 --thinking max"
abbr -a pi-flash "pi --model radius/deepseek-v4.1-flash --thinking high"
abbr -a pi-astra "pi --model openai/gpt-6-astra --thinking high"
