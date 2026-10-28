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
rex.unbind("ctrl+tab")
rex.unbind("ctrl+shift+tab")
-- rex.unbind("cmd+shift+w")
-- rex.unbind("ctrl+cmd+up")

-- Features
rex.bind("cmd+k", "client.palette.toggle")
rex.bind("ctrl+cmd+r", "client.tab.rename")

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

-- Splits
local dirs = { h = "left", j = "down", k = "up", l = "right" }
for key, dir in pairs(dirs) do
  rex.bind("cmd+alt+" .. key, "pane.focus", { direction = dir })
  rex.bind("cmd+alt+shift+" .. key, "pane.resize", { direction = dir })
end
rex.bind("cmd+alt+shift+0", "pane.balance")
