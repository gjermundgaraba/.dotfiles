local add = require "utils.pack"

add({
  {
    src = "https://github.com/nvim-treesitter/nvim-treesitter",
    version = "main",
  },
  {
    src = "https://github.com/kylechui/nvim-surround",
    version = vim.version.range "^4",
  },
  {
    src = "https://github.com/chrisgrieser/nvim-various-textobjs",
    version = "main",
  },
})

require("nvim-treesitter").install {
  "bash",
  "diff",
  "go",
  "gomod",
  "gosum",
  "gotmpl",
  "gowork",
  "lua",
  "luadoc",
  "markdown",
  "markdown_inline",
  "query",
  "rust",
  "swift",
  "vim",
  "vimdoc",
  "yaml",
}

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("gg/treesitter", { clear = true }),
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

require("nvim-surround").setup {}

local textobjs = require "various-textobjs"
local map = require "utils.keymapper"

textobjs.setup {
  keymaps = {
    useDefaults = false,
  },
}

map.map({ "o", "x" }, "aq", function()
  textobjs.anyQuote "outer"
end, { desc = "outer quotes" })
map.map({ "o", "x" }, "iq", function()
  textobjs.anyQuote "inner"
end, { desc = "inner quotes" })
