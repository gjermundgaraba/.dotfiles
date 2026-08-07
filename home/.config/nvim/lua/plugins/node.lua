local add = require "utils.pack"

add({
  {
    src = "https://github.com/vuki656/package-info.nvim",
    version = "master",
  },
})

require("package-info").setup {}
