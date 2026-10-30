-- Keyboard shortcuts ported from ~/.config/ghostty/config

local terminal = "com.superlogical.terminal"

local function type_text(ctx, data)
  rex.block.call(terminal, "write", { block_id = ctx.block_id, data = data })
  return true
end

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

-- Unbinds: let these keys reach the terminal
rex.unbind("cmd+w")
-- rex.unbind("cmd+shift+w")
-- rex.unbind("ctrl+cmd+up")

-- Features
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
rex.bind("f20>h", "client.host.switch")
rex.bind("f20>a", "client.sidebar.activity.toggle")
rex.bind("f20>m", "pane.move_to_new_tab")
rex.bind("f20>t", "client.tab.new")
for i = 1, 9 do
  rex.bind("f20>" .. i, "client.tab.goto", { index = i })
end
rex.bind("f20>shift+h", "client.tab.previous")
rex.bind("f20>shift+l", "client.tab.next")
rex.bind("f20>shift+c", "session.new")
rex.bind("f20>shift+p", "session.previous")
rex.bind("f20>shift+n", "session.next")
rex.bind("f20>z", "pane.zoom")
rex.bind("f20>,", "client.settings")

local function copy(text, title)
  local copied = rex.exec({ "pbcopy" }, { stdin = text })
  if copied and copied.ok then
    rex.exec({
      "osascript",
      "-e", "on run argv",
      "-e", "display notification (item 1 of argv) with title (item 2 of argv)",
      "-e", "end run",
      text, title,
    })
  end
  return text
end

rex.action{
  name  = "copy_block_id",
  title = "Copy Pane ID",
  run   = function(ctx) return copy(ctx.block_id, "Copied pane ID") end,
}
rex.bind("f20>y", "copy_block_id")

-- Fork Agent Session and Copy Agent Session ID, for Claude Code, Codex and pi
require("agent_fork").setup{ copy = copy }
rex.bind("f20>f", "fork_agent")
rex.bind("f20>i", "copy_agent_session_id")

-- Closes the floating layer with this block label in the active tab, if there is one
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

-- Pressed again, closes the popup in the active tab instead of opening another
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

-- A QR code for each host, to add it in Rex on another device. Pressed again, closes them
rex.action{
  name     = "host_qr",
  title    = "Show Host QR Codes",
  keywords = "hosts qr code pair phone iphone ipad ios add remote",
  run      = function(ctx)
    if close_popup(ctx.session_id, "host-qr") then return end
    local _, err = rex.session.new_layer{
      bounds = { 0.25, 0.1, 0.5, 0.8 },
      focus  = true,
      layout = rex.layout.block{
        flavor  = "com.superlogical.terminal.shell",
        label   = "host-qr",
        options = {
          shell   = "none",
          command = { os.getenv("HOME") .. "/.config/rex/host-qr" },
        },
      },
    }
    if err then error(err, 0) end
  end,
}
rex.bind("f20>q", "host_qr")

-- Agents on every host, the ones waiting on you first, in Flare's Agents mode
-- (home/.config/flare/extensions/agents.lua). Runs on the server of the focused
-- session, so only in this Mac's sessions; Flare's own shortcut works anywhere
rex.action{
  name     = "agents",
  title    = "Show Agents",
  keywords = "agents claude codex pi blocked waiting done jump hosts flare",
  run      = function()
    local opened, err = rex.exec({ "/usr/bin/open", "-g", "flare://mode/agents" })
    if not opened then error(err, 0) end
    if not opened.ok then error((opened.stderr:gsub("%s+$", "")), 0) end
  end,
}
rex.bind("f20>g", "agents")

rex.action{
  name  = "copy_block_path",
  title = "Copy Pane Path",
  run   = function(ctx)
    local proc = rex.block.call(terminal, "process", { block_id = ctx.block_id }) or {}
    local cwd = proc.foreground and proc.foreground.cwd
    if cwd then return copy(cwd, "Copied pane path") end
  end,
}
rex.bind("f20>p", "copy_block_path")

-- Splits
local dirs = { h = "left", j = "down", k = "up", l = "right" }
for key, dir in pairs(dirs) do
  rex.bind("cmd+alt+" .. key, "pane.focus", { direction = dir })
  rex.bind("cmd+alt+shift+" .. key, "pane.move", { direction = dir })
end
rex.bind("cmd+alt+shift+0", "pane.balance")
