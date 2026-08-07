require("utils.copilot").setup()

for _, name in ipairs {
  "lua_ls",
  "ts_ls",
  "jsonls",
  "gopls",
  "gh_actions_ls",
  "solidity_ls",
} do
  vim.lsp.enable(name)
end
