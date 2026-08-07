require "config.options"
require "config.pack_hooks"
require "config.pack_commands"

require "plugins.basic"
require "plugins.treesitter"
require "plugins.ui"
require "plugins.picker"
require "plugins.files"
require "plugins.formatting"
require "plugins.quickfix"
require "plugins.rust"
require "plugins.node"
require "plugins.session"
local ai = require "plugins.ai"
vim.api.nvim_create_autocmd("InsertEnter", {
  once = true,
  callback = ai.setup,
})
require "plugins.opencontext"

require "config.autocmds"
require "config.keymaps"
require "config.colors"
require "config.lsp"
