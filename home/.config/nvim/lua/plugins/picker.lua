local add = require "utils.pack"

add({
  {
    src = "https://github.com/dmtrKovalenko/fff.nvim",
    version = "main",
  },
  {
    src = "https://github.com/ibhagwan/fzf-lua",
    version = "main",
  },
})

local fff = require "fff"
fff.setup {}

local fzf = require "fzf-lua"
local map = require "utils.keymapper"

fzf.setup {
  "hide",
  keymap = {
    fzf = {
      ["ctrl-q"] = "select-all+accept",
    },
  },
  grep = {
    hidden = true,
  },
  files = {
    hidden = true,
  },
}

fzf.register_ui_select()

map.group("<leader>gs", "[S]earch")

map.nmap("ff", function()
  fff.find_files()
end, { desc = "FFFind files" })
map.nmap("fg", function()
  fff.live_grep()
end, { desc = "LiFFFe grep" })
map.nmap("fz", function()
  fff.live_grep {
    grep = {
      modes = { "fuzzy", "plain" },
    },
  }
end, { desc = "Live fffuzy grep" })
map.nmap("fc", function()
  fff.live_grep { query = vim.fn.expand "<cword>" }
end, { desc = "Search current word" })

map.nmap("<leader>p", fzf.builtin, { desc = "FzfLua Commands" })
map.nmap("<leader><leader>", fzf.buffers, { desc = "Search open buffers" })
map.nmap("<leader>ss", fzf.resume, { desc = "Continue search" })
map.nmap("<leader>so", function()
  fzf.oldfiles { cwd_only = true }
end, { desc = "Search recent files" })
map.nmap("<leader>sf", fzf.files, { desc = "Search files" })
map.nmap("<leader>sh", fzf.help_tags, { desc = "Search help" })
map.nmap("<leader>sg", fzf.live_grep, { desc = "Search with grep" })
map.nmap("<leader>sp", function()
  fzf.live_grep { search_paths = { vim.fn.stdpath "data" .. "/site/pack" } }
end, { desc = "Search plugin code" })
map.nmap("<leader>sd", fzf.diagnostics_workspace, { desc = "Search diagnostics" })

map.nmap("<leader>gsb", fzf.git_branches, { desc = "Git branches" })
map.nmap("<leader>gsB", fzf.git_blame, { desc = "Git blame" })
map.nmap("<leader>gsl", fzf.git_commits, { desc = "Git log" })
map.nmap("<leader>gsh", fzf.git_diff, { desc = "Git diff" })

map.nmap("<leader>ls", fzf.lsp_document_symbols, { desc = "Document symbols" })
map.nmap("<leader>lS", fzf.lsp_live_workspace_symbols, { desc = "Workspace symbols" })
