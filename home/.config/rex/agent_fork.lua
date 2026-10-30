-- Fork Agent Session and Copy Agent Session ID, for Claude Code, Codex and pi.
--
--   require("agent_fork").setup{ copy = function(text, title) ... end }  -- copy is optional
--   rex.bind("f20>f", "fork_agent")
--   rex.bind("f20>i", "copy_agent_session_id")
--
-- Each agent records its session for the Rex pane it runs in with ~/.config/rex/agent-session:
--   Claude Code: a SessionStart hook in ~/.claude/settings.json running
--     agent-session record claude-code
--   Codex: a SessionStart hook in ~/.codex/hooks.json running agent-session record codex, trusted
--     once in Codex, and ~/.config/fish/functions/codex.fish, which runs Codex without its shared
--     daemon so the hook sees the pane. The hook fires at the first prompt, so a new session can
--     be forked once it has one; after /new, until then, Fork still picks the previous session
--   pi: the extension ~/.pi/agent/extensions/rex-agent-session.ts

local M = {}

local terminal = "com.superlogical.terminal"
local script = os.getenv("HOME") .. "/.config/rex/agent-session"

-- Keyed by the app name in the pane's program status
local agents = {
  ["claude-code"] = { name = "Claude Code", fork = function(id) return "claude --resume " .. id .. " --fork-session" end },
  codex           = { name = "Codex",       fork = function(id) return "codex fork " .. id end },
  pi              = { name = "pi",          fork = function(id) return "pi --fork " .. id end },
}

local function session_id(ctx)
  local status = rex.block.call(terminal, "program_status", { block_id = ctx.block_id }) or {}
  for _, record in ipairs(status.records or {}) do
    local agent = agents[record.app]
    if agent then
      local found, err = rex.exec({ script, "id", record.app, ctx.block_id })
      if not found then error(err, 0) end
      if not found.ok then error(agent.name .. ": " .. (found.stderr:gsub("%s+$", "")), 0) end
      return (found.stdout:gsub("%s+$", "")), agent
    end
  end
  error("No Claude Code, Codex or pi session in this pane", 0)
end

function M.setup(opts)
  opts = opts or {}

  rex.action{
    name  = "fork_agent",
    title = "Fork Agent Session",
    run   = function(ctx)
      local id, agent = session_id(ctx)
      local proc = rex.block.call(terminal, "process", { block_id = ctx.block_id }) or {}
      local parent = (proc.ancestors or {})[1] or {}
      local _, err = rex.session.new_split{
        anchor_id = ctx.block_id,
        direction = "horizontal",
        side      = "after",
        focus     = true,
        layout    = rex.layout.block{
          flavor  = "com.superlogical.terminal.shell",
          options = {
            shell         = parent.invoked_path or parent.path,
            cwd           = proc.foreground and proc.foreground.cwd,
            initial_input = agent.fork(id) .. "\n",
          },
        },
      }
      if err then error(err, 0) end
      rex.client.queue("pane.balance")
    end,
  }

  rex.action{
    name  = "copy_agent_session_id",
    title = "Copy Agent Session ID",
    run   = function(ctx)
      local id = session_id(ctx)
      if opts.copy then return opts.copy(id, "Copied agent session ID") end
      rex.exec({ "pbcopy" }, { stdin = id })
      return id
    end,
  }
end

return M
