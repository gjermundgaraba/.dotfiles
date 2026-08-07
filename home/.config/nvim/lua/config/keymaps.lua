local map = require "utils.keymapper"

-- ============================================================================
-- Which-key group registrations
-- ============================================================================
map.group("<leader>c", "[C]ode")
map.group("<leader>cr", "[R]efactor")
map.group("<leader>s", "[S]earch")
map.group("<leader>l", "[L]SP")
map.group("<leader>a", "[A]I")
map.group("<leader>g", "[G]it")
map.group("<leader><M-D-t>", "Terminal")

-- ============================================================================
-- Editor keymaps (no plugin dependencies)
-- ============================================================================

-- Save & Quit
map.map({ "i", "n" }, "<D-s>", "<cmd>write<CR>", { desc = "Save file" })
map.map({ "i", "n" }, "<F13>", "<cmd>write<CR>", { desc = "Save file" })
map.nmap("<leader>q", ":qa<CR>", { desc = "Quit" })
map.nmap("<leader>R", "<cmd>restart<CR>", { desc = "Restart Neovim" })
map.nmap("<C-q>", "<cmd>qa!<CR>", { desc = "Quit it and hit it" })

-- Clear highlights
map.nmap("<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear highlights" })

-- Buffer navigation
map.nmap("<S-l>", ":bnext<CR>", { desc = "Next buffer" })
map.nmap("<S-h>", ":bprevious<CR>", { desc = "Previous buffer" })

-- Buffer close (preserve window layout)
local function bufdelete()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].modified then
    vim.notify("Buffer has unsaved changes", vim.log.levels.WARN)
    return
  end

  local bufs = vim.tbl_filter(function(b)
    return vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted
  end, vim.api.nvim_list_bufs())

  if #bufs > 1 then
    vim.cmd "bnext"
  else
    vim.cmd "enew"
  end

  vim.api.nvim_buf_delete(buf, {})
end

local function bufdelete_other()
  local current = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and not vim.bo[buf].modified then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end

map.nmap("<D-w>", bufdelete, { desc = "Close buffer" })
map.nmap("<leader>w", bufdelete, { desc = "Close buffer" })
map.nmap("<D-S-w>", bufdelete_other, { desc = "Close other buffers" })

-- Folding (opt+l, opt+h)
map.nmap("ﬁ", "zo", { desc = "Open fold" })
map.nmap("˛", "zc", { desc = "Close fold" })

-- Window navigation
map.map({ "n", "t" }, "<C-h>", function()
  vim.cmd.wincmd "h"
end, { desc = "Focus left window" })
map.map({ "n", "t" }, "<C-l>", function()
  vim.cmd.wincmd "l"
end, { desc = "Focus right window" })
map.nmap("<C-j>", function()
  vim.cmd.wincmd "j"
end, { desc = "Focus lower window" })
map.map({ "n", "t" }, "<C-k>", function()
  vim.cmd.wincmd "k"
end, { desc = "Focus upper window" })

-- Window resizing
map.nmap("<C-S-0>", "<C-w>=", { desc = "Equalize windows" })
map.nmap("<C-S-h>", "5<C-w><", { desc = "Decrease width" })
map.nmap("<C-S-l>", "5<C-w>>", { desc = "Increase width" })
map.nmap("<C-S-j>", "5<C-w>-", { desc = "Decrease height" })
map.nmap("<C-S-k>", "5<C-w>+", { desc = "Increase height" })

-- Jump list (explicit to avoid conflicts)
map.nmap("<C-o>", "<C-o>", { desc = "Jump back" })
map.nmap("<C-i>", "<C-i>", { desc = "Jump forward" })

-- Indentation
map.nmap("<Tab>", function()
  return require("plugins.ai").next_edit_or_indent()
end, { desc = "Apply next edit or indent line", expr = true })
map.nmap("<S-Tab>", "<<", { desc = "Un-indent line" })
map.vmap("<Tab>", ">gv", { desc = "Indent selection" })
map.vmap("<S-Tab>", "<gv", { desc = "Un-indent selection" })

-- Completion
map.imap("<Tab>", function()
  return require("plugins.ai").accept_or_fallback()
end, { desc = "Accept snippet, next edit, or inline completion", expr = true })

map.imap("<S-Tab>", function()
  return require("plugins.ai").previous_or_fallback()
end, { desc = "Previous completion or snippet stop", expr = true })

map.imap("<D-S-l>", function()
  require("plugins.ai").accept_word()
end, { desc = "Accept next Copilot word" })

map.imap("<D-S-j>", function()
  require("plugins.ai").accept_line()
end, { desc = "Accept next Copilot line" })

map.imap("<C-Space>", function()
  vim.lsp.completion.get()
end, { desc = "Trigger completion" })

-- ============================================================================
-- Diagnostics (vim.diagnostic builtin)
-- ============================================================================
map.leader("cdq", function()
  vim.diagnostic.setqflist { open = true, title = "Diagnostics (all buffers)" }
end, { desc = "Diagnostics to Quickfix" })

pcall(vim.keymap.del, "n", "[d")
pcall(vim.keymap.del, "n", "]d")

-- ============================================================================
-- LSP builtins
-- ============================================================================
map.leader("lr", "<cmd>lsp restart<CR>", { desc = "Restart LSP" })

-- ============================================================================
-- Builtin packages
-- ============================================================================
map.leader("u", function()
  vim.cmd.packadd "nvim.undotree"
  vim.cmd.Undotree()
end, { desc = "Undotree" })

-- ============================================================================
-- Terminal
-- ============================================================================
map.tmap("<esc>", [[<C-\><C-n>]], { desc = "Terminal normal mode" })
