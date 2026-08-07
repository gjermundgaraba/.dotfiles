vim.opt_local.wrap = true

vim.keymap.set("i", "<C-v>", "<cmd>PasteImage<CR>", {
  buffer = true,
  desc = "Paste image from clipboard",
})
