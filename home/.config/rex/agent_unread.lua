-- Rex has no API for unread. Rex.app keeps a receipt of when it last showed each pane, and a done
-- program status report (OSC 7501) newer than that is unread. Rex.app counts the pane as shown
-- while it is on screen, even under Flare's panel, so the report has to wait until you are
-- elsewhere.

local M = {}

local terminal = "com.superlogical.terminal"
local state_dir = os.getenv("HOME") .. "/.local/state/rex"
local FOCUS_SETTLE_SECONDS = 0.5
M.PENDING = state_dir .. "/mark-unread"

local function base64(text)
  local encoded, err = rex.exec({ "base64" }, { stdin = text })
  if not encoded then error(err, 0) end
  if not encoded.ok then error("base64: " .. encoded.stderr, 0) end
  return (encoded.stdout:gsub("%s", ""))
end

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

local function write(ctx, text)
  local proc = rex.block.call(terminal, "process", { block_id = ctx.block_id }) or {}
  local pid = proc.foreground and proc.foreground.pid
  if not pid then error("No process in this pane", 0) end
  local ps, err = rex.exec({ "ps", "-o", "tty=", "-p", tostring(pid) })
  if not ps then error(err, 0) end
  local tty = ps.stdout:gsub("%s", "")
  if not ps.ok or tty == "" or tty:find("?", 1, true) then error("No tty for this pane", 0) end

  local started, start_err = rex.exec.start(
    { "sh", "-c", 'sleep "$1" && printf %s "$2" > "$3"', "sh", tostring(FOCUS_SETTLE_SECONDS), text, "/dev/" .. tty },
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
