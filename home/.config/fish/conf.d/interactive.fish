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
abbr -a cfgpi "cd ~/.pi/agent/ && nve"

## misc
abbr -a codx-luna "codex -c 'model_reasoning_effort=xhigh' --model gpt-5.6-luna"
abbr -a codx-terra "codex -c 'model_reasoning_effort=xhigh' --model gpt-5.6-terra"
abbr -a codx-ultra "codex -c 'model_reasoning_effort=ultra' --model gpt-5.6-sol"
abbr -a oc "OPENCODE_ENABLE_EXA=1 opencode"
abbr -a cc "claude"
abbr -a cc-opus "claude --model opus"
abbr -a cc-sonnet "claude --model sonnet"
abbr -a cc-workflows 'claude --settings \'{"disableWorkflows": false}\''

### pi
abbr -a pi-cheap "pi --model openai-codex/gpt-5.6-luna --thinking xhigh"
abbr -a pi-fast "pi --model openai-codex/gpt-5.6-luna --thinking low"
abbr -a pi-terra "pi --model openai-codex/gpt-5.6-terra --thinking xhigh"
abbr -a pi-grok "pi --model xai/grok-4.5 --thinking high"


## actua aliases
alias pa-agent "cd /Users/gg/.pa-agent && ./start.fish"
alias restart-process-composer "/Users/gg/.config/process-compose/restart.sh"
alias librarian-checkout "/Users/gg/.agents/skills/librarian/checkout.sh"

if test "$PWD" = "$HOME"
    fastfetch
end
