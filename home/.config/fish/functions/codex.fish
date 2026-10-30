function codex --wraps codex --description "codex, run in-process inside Rex so its hooks see the pane"
    # Rex's Fork Agent Session action needs Codex's SessionStart hook to record the pane's session.
    # The shared daemon runs hooks without the pane's REX_BLOCK, and the hook only fires at the
    # first prompt, so forget the pane's previous session until then
    if set -q REX_BLOCK
        ~/.config/rex/agent-session clear
        command codex --no-daemon $argv
    else
        command codex $argv
    end
end
