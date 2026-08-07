local add = require "utils.pack"

add({
  {
    src = "https://github.com/nvim-lua/plenary.nvim",
    version = "master",
  },
  {
    src = "https://github.com/nvim-tree/nvim-web-devicons",
    version = "master",
  },
  {
    src = "https://github.com/folke/todo-comments.nvim",
    version = "main",
  },
  {
    src = "https://github.com/akinsho/bufferline.nvim",
    version = "main",
  },
  {
    src = "https://github.com/folke/which-key.nvim",
    version = "main",
  },
})

require("todo-comments").setup {
  signs = true,
  keywords = {
    H1 = { icon = "󰉫", color = "hint" },
    H2 = { icon = "󰉬", color = "hint" },
    H3 = { icon = "󰉭", color = "hint" },
    TODO = { color = "default" },
  },
}

require("bufferline").setup {
  options = {
    diagnostics = "nvim_lsp",
    diagnostics_indicator = function(_, _, diagnostics_dict)
      local text = " "
      for severity, count in pairs(diagnostics_dict) do
        local symbol = severity == "error" and " " or (severity == "warning" and " " or " ")
        text = text .. count .. symbol
      end
      return text
    end,
    offsets = {
      {
        filetype = "neo-tree",
        text = "File Explorer",
        highlight = "Directory",
        separator = true,
      },
    },
  },
}

require("which-key").setup {
  icons = {
    mappings = true,
  },
}

local map = require "utils.keymapper"

map.group("<leader>k", "[K]eymaps")

map.leader("ks", function()
  require("which-key").show()
end, { desc = "Show keymaps" })
map.leader("kl", function()
  require("which-key").show { loop = true }
end, { desc = "Keymaps (loop mode)" })
