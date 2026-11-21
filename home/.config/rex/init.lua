local terminal = "com.superlogical.terminal"

local function type_text(ctx, data)
  rex.block.call(terminal, "write", { block_id = ctx.block_id, data = data })
  return true
end

local helpers = require("helpers")
local run, copy = helpers.run, helpers.copy

-- Norwegian keyboard: restore Option+key special characters
-- (only matters if Option as Alt is turned on in Rex's settings)
local alt_text = {
  ["alt+7"] = "|",
  ["alt+8"] = "[",
  ["alt+9"] = "]",
  ["alt+[Equal]"] = "`",        -- ´
  ["alt+[BracketRight]"] = "~", -- ¨
  ["alt+[Backslash]"] = "'",    -- @
  ["alt+shift+8"] = "{",
  ["alt+shift+9"] = "}",
  ["alt+shift+7"] = "\\",
}
for key, text in pairs(alt_text) do
  rex.bind(key, function(ctx) return type_text(ctx, text) end)
end

rex.unbind("cmd+w")

rex.bind("cmd+k", "client.palette.toggle")
rex.bind("ctrl+cmd+r", "client.tab.rename")
rex.bind("ctrl+tab", "client.tab.next")
rex.bind("ctrl+shift+tab", "client.tab.previous")

rex.action{
  name  = "restart_shell",
  title = "Restart Shell",
  run   = function(ctx) type_text(ctx, "\x15exec fish -l\n") end,
}
rex.bind("cmd+shift+r", "restart_shell")

rex.action{
  name  = "split_right_balanced",
  title = "Split Pane Right and Balance",
  run   = function()
    rex.client.queue("pane.split.right")
    rex.client.queue("pane.balance")
  end,
}
rex.bind("cmd+d", "split_right_balanced")
rex.bind("f20>d", "split_right_balanced")

rex.action{
  name  = "split_down_balanced",
  title = "Split Pane Down and Balance",
  run   = function()
    rex.client.queue("pane.split.down")
    rex.client.queue("pane.balance")
  end,
}
rex.bind("f20>shift+d", "split_down_balanced")

rex.bind("f20>s", "session.switch")
rex.bind("f20>a", "client.sidebar.activity.toggle")
rex.bind("f20>m", "pane.move_to_tab")
rex.bind("f20>shift+m", "pane.move_to_new_tab")
rex.bind("f20>i>t", "client.tab.new")
rex.bind("f20>tab", "client.tab.new")
for i = 1, 9 do
  rex.bind("f20>" .. i, "client.tab.goto", { index = i })
end
rex.bind("f20>shift+h", "client.tab.previous")
rex.bind("f20>shift+l", "client.tab.next")
rex.bind("f20>p", "client.tab.previous")
rex.bind("f20>n", "client.tab.next")
rex.bind("f20>i>s", "session.switch") -- type a new name to create it
rex.bind("f20>i>h", "client.host.add")
rex.bind("f20>r>t", "client.tab.rename")
rex.bind("f20>r>s", "session.rename")
rex.bind("f20>shift+p", "session.previous")
rex.bind("f20>shift+n", "session.next")

-- A session.select queued from a key press only looks on the Mac's server.
local function focus_history(ctx, direction)
  run({ os.getenv("HOME") .. "/.cargo/bin/rex-state", direction, ctx.client_id })
end

rex.action{
  name     = "focus_back",
  title    = "Back to Previous Pane",
  keywords = "history jump back previous last pane tab session",
  run      = function(ctx) focus_history(ctx, "back") end,
}
rex.action{
  name     = "focus_forward",
  title    = "Forward to Next Pane",
  keywords = "history jump forward next pane tab session",
  run      = function(ctx) focus_history(ctx, "forward") end,
}
rex.bind("f20>shift+o", "focus_back")
rex.bind("f20>shift+i", "focus_forward")
rex.bind("f20>z", "pane.zoom")
rex.bind("f20>,", "client.settings")

rex.action{
  name  = "copy_block_id",
  title = "Copy Pane ID",
  run   = function(ctx) return copy(ctx.block_id, "Copied pane ID") end,
}
rex.bind("f20>y>y", "copy_block_id")

require("agent_fork").setup{ copy = copy }
rex.bind("f20>f", "fork_agent")
rex.bind("f20>y>i", "copy_agent_session_id")

require("clankerbox_host").setup()
rex.bind("f20>i>c", "new_clankerbox_host")

local function close_popup(session_id, label)
  local view = rex.call("session.view", { session_id = session_id }) or {}
  for _, window in ipairs(view.windows or {}) do
    if window.window_id == view.active_window_id then
      for _, layer in ipairs(window.layers or {}) do
        for _, block in ipairs(layer.blocks or {}) do
          if layer.kind ~= "tiled" and block.label == label then
            rex.call("session.close_layer", { session_id = session_id, layer_id = layer.layer_id })
            return true
          end
        end
      end
    end
  end
  return false
end

rex.action{
  name  = "popup_shell",
  title = "Toggle Popup Shell",
  run   = function(ctx)
    if close_popup(ctx.session_id, "popup") then return end
    local proc = rex.block.call(terminal, "process", { block_id = ctx.block_id }) or {}
    local _, err = rex.session.new_layer{
      bounds = { 0.1, 0.1, 0.8, 0.8 },
      focus  = true,
      layout = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        label   = "popup",
        options = {
          shell = "/opt/homebrew/bin/fish",
          cwd   = proc.foreground and proc.foreground.cwd,
        },
      },
    }
    if err then error(err, 0) end
  end,
}
rex.bind("cmd+shift+t", "popup_shell")

-- The Mac app runs actions on the Mac's server, even from remote sessions.
local function show_agents()
  run({ "/usr/bin/open", "-g", "flare://mode/agents" })
end

rex.action{
  name     = "agents",
  title    = "Show Agents",
  keywords = "agents claude codex pi blocked waiting done jump hosts flare",
  run      = show_agents,
}
rex.bind("f20>g", "agents")

require("agent_unread").setup{ pick = show_agents }
rex.bind("f20>u", "mark_agent_unread")

rex.action{
  name  = "copy_block_path",
  title = "Copy Pane Path",
  run   = function(ctx)
    local proc = rex.block.call(terminal, "process", { block_id = ctx.block_id }) or {}
    local cwd = proc.foreground and proc.foreground.cwd
    if cwd then return copy(cwd, "Copied pane path") end
  end,
}
rex.bind("f20>y>p", "copy_block_path")

-- The DNS name of the pane's host, without scheme or port. A remote host's session runs this on
-- the Mac's server with ctx.server set, so ask rex the address that host's label resolves to;
-- this machine's is its built-in Tailscale name
local function host_name(ctx)
  if ctx.server then
    local found = run({ helpers.rex, "-S", ctx.server, "--timeout", "3s", "whoami", "--json" })
    local endpoint = (rex.json.decode(found) or {}).endpoint or ""
    return (endpoint:gsub("^%a[%w+.-]*://", ""):gsub("[:/].*$", ""))
  end
  local status, err = rex.call("server.status")
  if not status then error(err, 0) end
  return status.tailscale and status.tailscale.dns_name
end

rex.action{
  name  = "copy_host_name",
  title = "Copy Host Name",
  run   = function(ctx)
    local name = host_name(ctx)
    if not name or name == "" then error("No DNS name for this host", 0) end
    return copy(name, "Copied host name")
  end,
}
rex.bind("f20>y>u", "copy_host_name")

rex.action{
  name  = "copy_host_label",
  title = "Copy Host Label",
  run   = function(ctx)
    if ctx.server then return copy(ctx.server, "Copied host label") end
    local computer_name = run({ "/usr/sbin/scutil", "--get", "ComputerName" })
    return copy((computer_name:gsub("%s+$", "")), "Copied host label")
  end,
}
rex.bind("f20>y>l", "copy_host_label")

local dirs = { h = "left", j = "down", k = "up", l = "right" }
for key, dir in pairs(dirs) do
  rex.bind("cmd+alt+" .. key, "pane.focus", { direction = dir })
  rex.bind("cmd+alt+shift+" .. key, "pane.move", { direction = dir })
end
rex.bind("cmd+alt+shift+0", "pane.balance")
