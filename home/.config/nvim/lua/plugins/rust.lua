local add = require "utils.pack"

add({
  {
    src = "https://github.com/mrcjkb/rustaceanvim",
    version = "main",
  },
  {
    src = "https://github.com/saecki/crates.nvim",
    version = "v0.7.1",
  },
})

require("crates").setup {}
