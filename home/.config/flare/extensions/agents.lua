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
-- Seen done agents and idle ones are both just waiting, so both are done
local ORDER = { "blocked", "error", "unread", "working", "done" }
local ICONS = {
  blocked = { symbol = "hand.raised.fill", color = 0xFF3B30 },
  error = { symbol = "exclamationmark.triangle.fill", color = 0xAF52DE },
  unread = { symbol = "bell.badge.fill", color = 0x30B0C7 },
  working = { symbol = "hourglass", color = 0xFF9500 },
  done = { symbol = "checkmark", color = 0x34C759 },
}
-- How long the list keeps refreshing (ages, previews) after the mode opens
local LIVE_FOR, LIVE_EVERY = 120, 2
local PREVIEW_LINES = 30

flare.mode{
  name = "Agents",
  icon = { symbol = "sparkles", color = 0x5E5CE6 },
  placeholder = "Search agents…",
  hotkey = "ctrl+cmd+a",
  previews = true,
  actions = { primary = "Jump" },
}

local snapshot -- rex-state's last snapshot
local problem = "Waiting for rex-state…"
local rows = {} -- by item id
local ticker -- refreshes the list while the mode is likely open

local rank = {}
for i, state in ipairs(ORDER) do rank[state] = i end

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

-- The end of a host's first DNS label tells similar hosts apart, as in mac-dev-1-1
local function short(server)
  if server == "local" then return nil end
  return ((server:match("^[^.]+") or server):sub(-12):gsub("^[-_.]+", ""))
end

-- A block's most pressing agent record: its state, the record, and when it changed
local function status(block)
  local best
  for _, record in ipairs(block.status or {}) do
    local updated = epoch(record.updated_at)
    local state = record.state
    if state == "done" and record.unread then state = "unread" end
    if state == "idle" then state = "done" end
    if AGENTS[record.effective_app] and updated and rank[state] then
      if not best or rank[state] < rank[best.state]
        or (rank[state] == rank[best.state] and updated > best.updated) then
        best = { state = state, record = record, updated = updated }
      end
    end
  end
  return best
end

local function render()
  local now = os.time()
  local found = {}
  local down = {}
  rows = {}
  for _, server in ipairs(snapshot and snapshot.servers or {}) do
    if not server.connected then table.insert(down, short(server.server) or "this Mac") end
    for _, session in ipairs(server.sessions or {}) do
      for _, block in ipairs(session.blocks or {}) do
        local best = status(block)
        if best then
          local host = short(server.server)
          local place = host and (host .. "/" .. session.label) or session.label
          local id = table.concat({ server.server, session.id, block.window, block.id }, "\t")
          local label = best.state .. (best.record.kind and (": " .. best.record.kind) or "")
          rows[id] = {
            server = server.server, session = session.id, window = block.window, block = block.id,
            app = best.record.effective_app, place = place, state = label,
            cwd = block.foreground and block.foreground.cwd,
          }
          table.insert(found, {
            rank = rank[best.state],
            updated = best.updated,
            item = {
              id = id,
              title = best.record.msg or block.title or best.record.effective_app,
              subtitle = best.record.effective_app .. " · " .. place,
              accessory = label .. " · " .. age(now - best.updated),
              icon = ICONS[best.state],
              match = label .. " " .. (server.server or ""),
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
  -- An unreachable host's agents can't be jumped to, so its rows are gone
  flare.notice(problem or (#down > 0 and ("Can't reach " .. table.concat(down, ", ")) or nil))
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

-- Rex.app's client on this Mac's server, which shows sessions on every host
local function app_client()
  local clients = flare.json.decode(call(rex("local", "client", "ls", "--json"))).clients or {}
  local newest
  for _, client in ipairs(clients) do
    local info = client.info or {}
    if info.kind == "app" and info.platform == "macos"
      and (not newest or client.connected_at > newest.connected_at) then
      newest = client
    end
  end
  return newest and newest.client_id
end

flare.on("open", function()
  render()
  if ticker then ticker:cancel() end
  local ticks = 0
  ticker = flare.every(LIVE_EVERY, function()
    ticks = ticks + 1
    if ticks * LIVE_EVERY >= LIVE_FOR then ticker:cancel() end
    render()
  end)
end)

flare.on("preview", function(id)
  local row = rows[id]
  if not row then return nil end
  local out, err = flare.exec(rex(row.server, "capture", "--session", row.session, "--block", row.block, "--trim"),
    { timeout = 3 })
  local screen = (out and (out.ok and out.stdout or out.stderr) or err):gsub("%s+$", "")
  local lines = {}
  for line in screen:gmatch("[^\n]*") do table.insert(lines, line) end
  local text = table.concat(lines, "\n", math.max(#lines - PREVIEW_LINES + 1, 1))
  return {
    text = text,
    mono = true,
    info = { { "Status", row.state }, { "Agent", row.app }, { "Session", row.place }, { "Directory", row.cwd or "" } },
  }
end)

flare.on("run", function(id)
  local row = rows[id]
  if not row then return end
  local client = app_client()
  if not client then error("Rex isn't running", 0) end
  call(rex("local", "--client", client, "do", "session.select",
    "session_id=" .. row.session, "window_id=" .. row.window))
  call(rex(row.server, "api", "call", "session.focus_block",
    flare.json.encode{ session_id = row.session, block_id = row.block }))
  flare.exec{ "/usr/bin/open", "-b", REX_APP }
end)

-- The agent a terminal's foreground process is, by its argv0, executable, or script
local function classify(foreground)
  for _, key in ipairs{ "argv0", "invoked_path", "path", "script" } do
    local name = type(foreground[key]) == "string" and foreground[key]:match("([^/]+)$")
    name = name and name:gsub("%.[^.]*$", "")
    if name == "claude" or name == "codex" or name == "pi" then return name end
  end
end

-- The agent in the focused pane of a session's active window
local function front(session)
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
  if app.bundle_id ~= REX_APP or not snapshot then return nil end
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
      if agent ~= nil and agent ~= this then return nil end
      agent = this
    end
  end
  return agent or nil
end)

follow()
render()
