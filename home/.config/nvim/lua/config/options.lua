require("vim._core.ui2").enable {}

-- Set <space> as the leader key  WARN: Must happen before plugins are loaded
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"

vim.opt.laststatus = 3
vim.opt.showcmdloc = "statusline"
vim.opt.cmdheight = 0
vim.opt.statusline:append "%{%v:lua.require('utils.diagnostic_status').statusline()%}"

vim.opt.clipboard = "unnamedplus"

vim.opt.autocomplete = true
vim.opt.completeopt = { "menu", "menuone", "noselect", "popup" }
vim.opt.pumborder = "rounded"
vim.opt.pummaxwidth = 80

vim.opt.breakindent = true
vim.opt.undofile = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250

vim.opt.timeoutlen = 300

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.list = true
vim.opt.listchars = { tab = "  ", trail = "·", nbsp = "␣" }
vim.opt.fillchars:append { eob = " " }
vim.opt.inccommand = "split"
vim.opt.cursorline = true
vim.opt.scrolloff = 10

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.softtabstop = 4

vim.opt.spelllang = "en_us"
vim.opt.spell = false

vim.diagnostic.config {
  severity_sort = true,
  update_in_insert = false,
  float = {
    border = "rounded",
    source = "if_many",
  },
  underline = true,
  virtual_text = {
    spacing = 2,
    source = "if_many",
    prefix = "●",
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "E",
      [vim.diagnostic.severity.WARN] = "W",
      [vim.diagnostic.severity.INFO] = "I",
      [vim.diagnostic.severity.HINT] = "H",
    },
  },
}

vim.o.foldlevelstart = 99
vim.o.statuscolumn = "%s%l "

vim.opt.termguicolors = true

vim.opt.maxmempattern = 102400
