-- Mark Agent Unread: puts Rex's unread dot back on an idle or finished agent's pane, once you
-- have picked somewhere else to go.
--
--   require("agent_unread").setup{ pick = function() ... end }
--   rex.bind("f20>u", "mark_agent_unread")
--
-- Rex has no API for unread. Rex.app keeps a receipt of when it last showed each pane, and a done
-- program status report (OSC 7501) newer than that is unread. Rex.app counts the pane as shown
-- while it is on screen, even under Flare's panel, so the report has to wait until you are
-- elsewhere. The action checks the agent, saves the pane in PENDING below, and calls pick, which
-- opens Flare's Agents mode (home/.config/flare/extensions/agents.lua). After Flare jumps to
-- another pane it runs this action with now = true on the pending pane's own server, which writes
-- the report to the pane's tty, as if the agent had sent it, repeating its app, title and message.
-- The agent's next report replaces it. A remote host's server writes to its own panes, so it
-- needs this file too.

local M = {}

local terminal = "com.superlogical.terminal"
local state_dir = os.getenv("HOME") .. "/.local/state/rex"
-- When it was saved, in seconds since the epoch, then the session and block, a line each
M.PENDING = state_dir .. "/mark-unread"

local function base64(text)
  local encoded, err = rex.exec({ "base64" }, { stdin = text })
  if not encoded then error(err, 0) end
  if not encoded.ok then error("base64: " .. encoded.stderr, 0) end
  return (encoded.stdout:gsub("%s", ""))
end

-- The done report for the pane's agent, repeating its app, title and message
local function report(ctx)
  local status = rex.block.call(terminal, "program_status", { block_id = ctx.block_id }) or {}
  local root = (status.records or {})[1]
  if not root or root.id then error("No program status in this pane", 0) end
  if root.state == "working" or root.state == "blocked" then
    error("The agent is " .. root.state .. ", and a done report would hide that", 0)
  end

  local fields = { "state=" .. (root.state == "error" and "error" or "done") }
  if root.app then fields[#fields + 1] = "app=" .. root.app end
  if root.title then fields[#fields + 1] = "title=" .. base64(root.title) end
  if root.msg then fields[#fields + 1] = "msg=" .. base64(root.msg) end
  return "\27]7501;" .. table.concat(fields, ":") .. "\27\\"
end

-- Writes text to the pane's tty, on this server's host, which must run the pane. Half a second
-- later, so Rex.app has finished showing where Flare jumped
local function write(ctx, text)
  local proc = rex.block.call(terminal, "process", { block_id = ctx.block_id }) or {}
  local pid = proc.foreground and proc.foreground.pid
  if not pid then error("No process in this pane", 0) end
  local ps, err = rex.exec({ "ps", "-o", "tty=", "-p", tostring(pid) })
  if not ps then error(err, 0) end
  local tty = ps.stdout:gsub("%s", "")
  if not ps.ok or tty == "" or tty:find("?", 1, true) then error("No tty for this pane", 0) end

  local started, start_err = rex.exec.start(
    { "sh", "-c", 'sleep 0.5 && printf %s "$1" > "$2"', "sh", text, "/dev/" .. tty },
    { detach = true }
  )
  if not started then error(start_err, 0) end
end

local function save_pending(ctx)
  rex.exec({ "mkdir", "-p", state_dir })
  local file, err = io.open(M.PENDING, "w")
  if not file then error(err, 0) end
  file:write(os.time(), "\n", ctx.session_id, "\n", ctx.block_id, "\n")
  file:close()
end

function M.setup(opts)
  rex.action{
    name     = "mark_agent_unread",
    title    = "Mark Agent Unread",
    keywords = "agent unread done claude codex pi inbox later",
    args     = { now = "boolean?" },
    run      = function(ctx, args)
      local text = report(ctx)
      if args and args.now then return write(ctx, text) end
      save_pending(ctx)
      opts.pick()
    end,
  }
end

return M
