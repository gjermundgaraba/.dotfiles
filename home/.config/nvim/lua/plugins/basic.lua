local add = require "utils.pack"

add({
  {
    src = "https://github.com/NMAC427/guess-indent.nvim",
    version = "main",
  },
  {
    src = "https://github.com/folke/lazydev.nvim",
    version = "main",
  },
})

require("guess-indent").setup {}

local lazydev_opts = {
  library = {
    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
  },
}

local local_plugin_folder = vim.env.NVIM_LOCAL_PLUGIN_FOLDER
if local_plugin_folder and local_plugin_folder ~= "" then
  vim.list_extend(lazydev_opts.library, vim.fn.glob(local_plugin_folder .. "/*/", true, true))
end

require("lazydev").setup(lazydev_opts)
