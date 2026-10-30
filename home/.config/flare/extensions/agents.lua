-- Agents in Rex on this Mac and every Rex host, the ones waiting on you first.
-- Follows rex-state (macos/Library/LaunchAgents/local.rex-state.plist); ↩ jumps
-- to the agent's pane. Also tells Flare's snippets which agent the focused Rex
-- pane runs, for their app-specific text.

local HOME = os.getenv("HOME")
-- Flare runs with launchd's PATH, so name commands in full
local REX_STATE = HOME .. "/.cargo/bin/rex-state"
local REX = HOME .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/"
  .. "Rex Server.app/Contents/MacOS/rex"
local REX_APP = "com.superlogical.rex"

local AGENTS = { ["claude-code"] = true, codex = true, pi = true, opencode = true }
-- The states rows show, the most pressing first, with the color of their border
-- (make-icons.swift draws the same). Seen done agents and idle ones are both
-- just waiting, so both are done, which has no border.
local STATES = {
  blocked = { rank = 1, color = 0xFF3B30 },
  error = { rank = 2, color = 0xAF52DE },
  unread = { rank = 3, color = 0x30B0C7 },
  working = { rank = 4, color = 0xFF9500 },
  done = { rank = 5 },
}
-- Each agent's icons, by its app and state, in agents/ beside this file:
-- claude-code.png when done, the animated claude-code-blocked.webp and so on
-- otherwise (a .png serves a state without one)
local ICONS = debug.getinfo(1, "S").source:match("^@(.*/)") .. "agents/"
-- rex-state rewrites its snapshot every 30 s, so an older one means it stopped
local STALE_AFTER = 120

flare.mode{
  name = "Agents",
  icon = { symbol = "sparkles", color = 0x5E5CE6 },
  placeholder = "Search agents…",
  actions = { primary = "Jump" },
  -- Where it runs and its directory
  columns = { { width = 160 }, { width = 220, truncate = "start" } },
}

local snapshot -- rex-state's last snapshot
local problem = "Waiting for rex-state…"
local jump_failed -- why the last jump failed, shown the next time the mode opens
local rows = {} -- by item id

-- Seconds since the epoch of an RFC 3339 time, such as 2026-10-29T19:04:00.99+01:00
local function epoch(stamp)
  local y, mo, d, h, mi, s, zone = (stamp or ""):match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):([%d.]+)(.*)$")
  if not y then return nil end
  y, mo, d = tonumber(y), tonumber(mo), tonumber(d)
  -- Days from the civil date (Howard Hinnant's algorithm)
  if mo <= 2 then y = y - 1 end
  local era = y // 400
  local yoe = y - era * 400
  local doy = (153 * (mo > 2 and mo - 3 or mo + 9) + 2) // 5 + d - 1
  local days = era * 146097 + yoe * 365 + yoe // 4 - yoe // 100 + doy - 719468
  local t = days * 86400 + tonumber(h) * 3600 + tonumber(mi) * 60 + tonumber(s)
  local sign, oh, om = zone:match("^([+-])(%d+):(%d+)$")
  if sign then t = t - (sign == "+" and 1 or -1) * (tonumber(oh) * 3600 + tonumber(om) * 60) end
  return t
end

local function age(seconds)
  seconds = math.max(math.floor(seconds), 0)
  for _, unit in ipairs{ { "d", 86400 }, { "h", 3600 }, { "m", 60 } } do
    if seconds >= unit[2] then return (seconds // unit[2]) .. unit[1] end
  end
  return seconds .. "s"
end

-- A host by the first label of its name
local function short(server)
  if server == "local" then return nil end
  return server:match("^[^.]+") or server
end

-- Text for a row: control characters as spaces, nil when blank
local function clean(text)
  if type(text) ~= "string" then return nil end
  text = text:gsub("%c", " ")
  if text:match("^%s*$") then return nil end
  return text
end

-- An agent's icon in a state: its image, if there is one, else a terminal in
-- the state's color
local function agent_icon(app, state)
  local name = ICONS .. app .. (state == "done" and "" or ("-" .. state))
  for _, path in ipairs{ name .. ".webp", name .. ".png" } do
    local file = io.open(path)
    if file then
      file:close()
      return { image = path }
    end
  end
  return { symbol = "terminal.fill", color = STATES[state].color }
end

-- A directory on this Mac with its home as ~
local function home(cwd)
  if cwd == HOME or cwd:sub(1, #HOME + 1) == HOME .. "/" then return "~" .. cwd:sub(#HOME + 1) end
  return cwd
end

-- A directory as fish's prompt shows it: each folder but the last two by its
-- first letter, with a hidden one's dot
local function fish(cwd)
  local names = {}
  for name in cwd:gmatch("[^/]+") do table.insert(names, name) end
  for i = 1, #names - 2 do names[i] = names[i]:match("^%.?" .. utf8.charpattern) or names[i] end
  return (cwd:sub(1, 1) == "/" and "/" or "") .. table.concat(names, "/")
end

-- Seconds since rex-state last wrote, if it stopped writing
local function stopped_for()
  local written = snapshot and epoch(snapshot.written_at)
  local since = written and os.time() - written
  if since and since > STALE_AFTER then return since end
end

-- A block's most pressing agent record: its state, the record, and when it changed
local function status(block)
  local best
  for _, record in ipairs(block.status or {}) do
    local updated = epoch(record.updated_at)
    local state = record.state
    if state == "done" and record.unread then state = "unread" end
    if state == "idle" then state = "done" end
    local rank = STATES[state] and STATES[state].rank
    if AGENTS[record.effective_app] and updated and rank then
      if not best or rank < best.rank or (rank == best.rank and updated > best.updated) then
        best = { state = state, rank = rank, record = record, updated = updated }
      end
    end
  end
  return best
end

local function render()
  local found = {}
  local down = {}
  rows = {}
  for _, server in ipairs(snapshot and snapshot.servers or {}) do
    -- A host still connecting has no error yet
    if not server.connected and server.error then table.insert(down, short(server.server) or "this Mac") end
    for _, session in ipairs(server.sessions or {}) do
      for _, block in ipairs(session.blocks or {}) do
        local best = status(block)
        if best then
          local host = short(server.server)
          local place = host and (host .. "/" .. session.label) or session.label
          local id = server.server .. "\t" .. block.id
          local app = best.record.effective_app
          local cwd = clean((block.foreground or {}).cwd)
          if cwd and server.server == "local" then cwd = home(cwd) end
          cwd = cwd and fish(cwd)
          rows[id] = { server = server.server, session = session.id, window = block.window, block = block.id }
          table.insert(found, {
            rank = best.rank,
            updated = best.updated,
            item = {
              id = id,
              title = clean(block.title) or app,
              -- What the agent is doing, while it says
              subtitle = clean(best.record.msg),
              icon = agent_icon(app, best.state),
              columns = { place, cwd },
              match = app .. " " .. best.state .. " " .. server.server,
            },
          })
        end
      end
    end
  end
  table.sort(found, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.updated > b.updated
  end)
  local items = {}
  for i, row in ipairs(found) do items[i] = row.item end
  flare.items(items)
  local stopped = stopped_for()
  -- An unreachable host's agents can't be jumped to, so its rows are gone
  flare.notice(problem or jump_failed
    or (stopped and ("rex-state stopped writing " .. age(stopped) .. " ago; these rows may be old"))
    or (#down > 0 and ("Can't reach " .. table.concat(down, ", ")) or nil))
end

local function follow()
  local _, err = flare.spawn({ REX_STATE, "watch" }, {
    line = function(line)
      local ok, decoded = pcall(flare.json.decode, line)
      if ok and type(decoded) == "table" then
        snapshot, problem = decoded, nil
        render()
      end
    end,
    exit = function(code)
      snapshot, problem = nil, "rex-state watch stopped (" .. tostring(code) .. "); retrying"
      render()
      flare.after(5, follow)
    end,
  })
  if err then
    problem = "Can't run " .. REX_STATE .. ": " .. err
    render()
    flare.after(30, follow)
  end
end

-- A rex command for SERVER ("local" for this Mac's)
local function rex(server, ...)
  local argv = { REX, "--autostart=false" }
  if server ~= "local" then
    table.insert(argv, "--server")
    table.insert(argv, server)
  end
  for _, arg in ipairs{ ... } do table.insert(argv, arg) end
  return argv
end

-- Runs a rex command, raising its error
local function call(argv)
  local out, err = flare.exec(argv, { timeout = 5 })
  if not out then error(err, 0) end
  if not out.ok then error((out.stderr:gsub("%s+$", "")), 0) end
  return out.stdout
end

-- Rex.app's client on this Mac's server, which shows sessions on every host:
-- the one connected last
local function app_client()
  local clients = flare.json.decode(call(rex("local", "client", "ls", "--json"))).clients or {}
  local newest, newest_at
  for _, client in ipairs(clients) do
    local info = client.info or {}
    local at = epoch(client.connected_at) or 0
    if info.kind == "app" and info.platform == "macos" and client.connection_state == "connected"
      and (not newest or at > newest_at) then
      newest, newest_at = client, at
    end
  end
  return newest and newest.client_id
end

flare.on("open", render)

flare.on("close", function()
  -- Shown once; a jump after this closing sets it again
  jump_failed = nil
end)

local function jump(row)
  if not row then error("That agent is gone", 0) end
  local client = app_client()
  if not client then error("Rex isn't running", 0) end
  call(rex("local", "--client", client, "do", "session.select",
    "session_id=" .. row.session, "window_id=" .. row.window))
  -- Rex comes forward on its session even if the pane can't be focused
  local focused, err = pcall(call, rex(row.server, "api", "call", "session.focus_block",
    flare.json.encode{ session_id = row.session, block_id = row.block }))
  local opened, open_err = flare.exec{ "/usr/bin/open", "-b", REX_APP }
  if not focused then error(err, 0) end
  if not opened then error("Couldn't bring Rex forward: " .. open_err, 0) end
  if not opened.ok then error("Couldn't bring Rex forward: " .. opened.stderr:gsub("%s+$", ""), 0) end
end

flare.on("run", function(id)
  local ok, err = pcall(jump, rows[id])
  jump_failed = not ok and ("Couldn't jump: " .. tostring(err)) or nil
  render()
end)

-- The agent a terminal's foreground process is, by its argv0, executable, or script
local function classify(foreground)
  for _, key in ipairs{ "argv0", "invoked_path", "path", "script" } do
    local name = type(foreground[key]) == "string" and foreground[key]:match("([^/]+)$")
    name = name and name:gsub("%.[^.]*$", "")
    if name == "claude" or name == "codex" or name == "pi" then return name end
  end
end

-- The agent in the focused pane of a session's active window: false for none,
-- nil when unknown, as the session's last read failed and its focus may be old
local function front(session)
  if session.stale then return nil end
  for _, window in ipairs(session.windows or {}) do
    if window.id == session.active_window then
      for _, block in ipairs(session.blocks or {}) do
        if block.id == window.focused_block then return block.foreground and classify(block.foreground) or false end
      end
    end
  end
  return false
end

-- Rex's window title ends in " - " and the session's label, with no sign of the
-- host, so sessions of that label on several hosts answer only when they agree
flare.on("agent", function(app)
  -- An old snapshot may name another pane than the one focused now
  if app.bundle_id ~= REX_APP or not snapshot or stopped_for() then return nil end
  local title = flare.window_title(app.pid)
  local sessions = {}
  for _, server in ipairs(snapshot.servers or {}) do
    for _, session in ipairs(server.sessions or {}) do table.insert(sessions, session) end
  end
  if not title then return #sessions == 1 and front(sessions[1]) or nil end
  local agent
  for _, session in ipairs(sessions) do
    if title:sub(-(#session.label + 3)) == " - " .. session.label then
      local this = front(session)
      if this == nil or (agent ~= nil and agent ~= this) then return nil end
      agent = this
    end
  end
  return agent or nil
end)

follow()
render()
