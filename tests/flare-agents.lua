-- Tests home/.config/flare/extensions/agents.lua with a stand-in for Flare's
-- `flare` table: its rows, its notice, and which agent it says Rex shows.
-- Run with Lua 5.4 or later: lua tests/flare-agents.lua

local root = arg[0]:match("^(.*)/tests/") or "."
local handlers, items, notice, title, follower = {}, nil, nil, nil, nil

flare = {
  mode = function() end,
  items = function(list) items = list end,
  notice = function(text) notice = text end,
  on = function(event, handler) handlers[event] = handler end,
  spawn = function(_, options) follower = options; return {} end,
  every = function() return { cancel = function() end } end,
  after = function() end,
  exec = function() return nil, "not here" end,
  window_title = function() return title end,
  -- Snapshots are handed over as tables
  json = { decode = function(value) return value end, encode = function(value) return value end },
}
dofile(root .. "/home/.config/flare/extensions/agents.lua")

local failures = 0
local function check(what, got, want)
  if got ~= want then
    failures = failures + 1
    print(("FAIL %s: got %s, want %s"):format(what, tostring(got), tostring(want)))
  end
end

local function record(state, app, updated, extra)
  local r = { state = state, effective_app = app, updated_at = updated }
  for k, v in pairs(extra or {}) do r[k] = v end
  return r
end

-- A session whose active window's focused pane runs `foreground`
local function session(label, foreground, status, block_title)
  return {
    id = "session:" .. label, label = label, active_window = "w-" .. label,
    windows = { { id = "w-" .. label, focused_block = "b-" .. label } },
    blocks = { { id = "b-" .. label, window = "w-" .. label, title = block_title,
      foreground = foreground, status = status or {} } },
  }
end

local claude = { argv0 = "claude", path = "/x/claude/versions/2.1" }
local codex = { argv0 = "node", script = "/l/@openai/codex/bin/codex.js" }
local fish = { argv0 = "-fish", path = "/opt/homebrew/bin/fish" }

follower.line({ servers = {
  { server = "local", connected = true, sessions = {
    session("flare", claude, { record("done", "claude-code", "2026-10-29T18:00:00+01:00",
      { unread = true, msg = "" }) }, "Fix\tthe\nbug"),
    session("notes", fish),
    session("twin", claude),
  } },
  { server = "box.example.ts.net", connected = true, sessions = {
    session("review", codex, { record("blocked", "codex", "2026-10-29T17:30:00Z",
      { kind = "permission", msg = "Allow rm?" }) }),
    session("twin", codex),
  } },
  { server = "slow.example.ts.net", connected = false },
  { server = "gone.example.ts.net", connected = false, error = "refused" },
} })

-- Rows: the most pressing first, titled by message, else by the pane's title
check("rows", #items, 2)
check("first row", items[1].title, "Allow rm?")
check("first subtitle", items[1].subtitle, "codex · box/review")
check("first accessory", items[1].accessory:match("^[^·]+"), "blocked: permission ")
check("second row", items[2].title, "Fix the bug")
check("second accessory", items[2].accessory:match("^[^·]+"), "unread ")
check("notice", notice, "Can't reach gone")

-- Which agent Rex shows, by the session its window title names
local function agent(window)
  title = window
  return handlers.agent({ bundle_id = "com.superlogical.rex", pid = 1 })
end
check("claude", agent("Fix the bug - flare"), "claude")
check("codex by script", agent("Review - review"), "codex")
check("a shell", agent("~ - notes"), nil)
check("same label, different agents", agent("x - twin"), nil)
check("unknown session", agent("x - nowhere"), nil)
check("another app", handlers.agent({ bundle_id = "com.apple.Notes", pid = 1 }), nil)

follower.line({ servers = { { server = "local", connected = true, sessions = { session("only", codex) } } } })
check("no title, the only session", agent(nil), "codex")

-- A message of control characters only falls back to the pane's title
follower.line({ servers = { { server = "local", connected = true, sessions = {
  session("only", codex, { record("working", "codex", "2026-10-29T17:30:00Z", { msg = "\27" }) }, "Real title"),
} } } })
check("control-only message", items[1].title, "Real title")

-- The preview reads only the end of the pane's output, in parts
local output = string.rep("x", 40000) .. "\nline one\nline two\n\n"
flare.exec = function(argv)
  local method, request = argv[#argv - 1], argv[#argv]
  if method:match("format$") then
    return { ok = true, stdout = { content = "x", id = 7, total = #output } }
  end
  local offset = request.args.offset
  local data = output:sub(offset + 1, offset + 5000)
  return { ok = true, stdout = { id = 7, data = data, eof = offset + #data >= #output } }
end
check("preview", handlers.preview(items[1].id).text, "line one\nline two")

-- A jump that can't bring Rex forward says so
flare.exec = function(argv)
  if argv[1] == "/usr/bin/open" then return nil, "no open" end
  if argv[#argv] == "--json" then
    return { ok = true, stdout = { clients = { { client_id = "c1", connected_at = "2026-10-29T17:00:00Z",
      connection_state = "connected", info = { kind = "app", platform = "macos" } } } } }
  end
  return { ok = true, stdout = {} }
end
handlers.run(items[1].id)
check("jump notice", notice, "Couldn't jump: Couldn't bring Rex forward: no open")
-- Shown once
handlers.close()

-- A snapshot rex-state stopped rewriting says so and answers nothing
follower.line({ written_at = "2020-01-01T00:00:00Z", servers = { { server = "local", connected = true,
  sessions = { session("only", codex) } } } })
check("stopped daemon's agent", agent("x - only"), nil)
check("stopped daemon's notice", notice and notice:match("^rex%-state stopped") ~= nil, true)

if failures > 0 then os.exit(1) end
print("ok")
