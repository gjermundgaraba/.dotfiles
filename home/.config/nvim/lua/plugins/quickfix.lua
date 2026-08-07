local add = require "utils.pack"

add({
  {
    src = "https://github.com/stevearc/quicker.nvim",
    version = "master",
  },
})

require("quicker").setup {
  follow = {
    enabled = true,
  },
}

local map = require "utils.keymapper"

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("gg/quicker-keymaps", { clear = true }),
  pattern = "qf",
  callback = function()
    map.nmap("<leader>r", function()
      require("quicker").refresh()
    end, { buffer = 0, desc = "Refresh quickfix" })
  end,
})
