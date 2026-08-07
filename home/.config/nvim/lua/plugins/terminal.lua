local lazygit_term

local add = require "utils.pack"

add({
  {
    src = "https://github.com/akinsho/toggleterm.nvim",
    version = "main",
  },
})

local toggleterm = require "toggleterm"
local map = require "utils.keymapper"

toggleterm.setup {}

map.map({ "n", "t" }, "<M-D-t>", function()
  toggleterm.toggle(1, nil, nil, "float")
end, { desc = "Toggle terminal" })

map.map({ "n", "i", "t" }, "<F18>", function()
  toggleterm.toggle(1, nil, nil, "float")
end, { desc = "Toggle terminal" })

map.nmap("<leader><M-D-t>g", function()
  if not lazygit_term then
    local Terminal = require("toggleterm.terminal").Terminal
    lazygit_term = Terminal:new { cmd = "lazygit", direction = "float", hidden = true }
  end
  lazygit_term:toggle()
end, { desc = "Toggle lazygit" })
