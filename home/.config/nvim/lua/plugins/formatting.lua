local add = require "utils.pack"

add({
  {
    src = "https://github.com/stevearc/conform.nvim",
    version = "master",
  },
})

local disable_lsp_format = { json = true }

require("conform").setup {
  notify_on_error = true,
  format_on_save = function(bufnr)
    return {
      timeout_ms = 500,
      lsp_format = disable_lsp_format[vim.bo[bufnr].filetype] and "never" or "fallback",
    }
  end,
  formatters_by_ft = {
    lua = { "stylua" },
    rust = { "rustfmt", lsp_format = "fallback" },
  },
}

local map = require "utils.keymapper"
map.leader("cf", function()
  require("conform").format()
end, { desc = "Format buffer" })
