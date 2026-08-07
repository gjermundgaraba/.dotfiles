local add = require "utils.pack"

add {
  {
    src = "https://github.com/MunifTanjim/nui.nvim",
    version = "main",
  },
  {
    src = "https://github.com/s1n7ax/nvim-window-picker",
    version = "main",
  },
  {
    src = "https://github.com/nvim-neo-tree/neo-tree.nvim",
    version = "v3.x",
  },
  {
    src = "https://github.com/stevearc/oil.nvim",
    version = "v2.16.0",
  },
}

require("oil").setup {
  default_file_explorer = false,
}

require("window-picker").setup {
  filter_rules = {
    include_current_win = false,
    autoselect_one = true,
    bo = {
      filetype = { "neo-tree", "neo-tree-popup", "notify" },
      buftype = { "terminal", "quickfix" },
    },
  },
}

local map = require "utils.keymapper"
map.nmap("<leader>e", "<cmd>Neotree toggle<CR>", { desc = "Open File Explorer" })

local filesystem_commands = require "neo-tree.sources.filesystem.commands"

require("neo-tree").setup {
  auto_clean_after_session_restore = true,
  filesystem = {
    hijack_netrw_behavior = "open_default",
    follow_current_file = { enabled = true },
    use_libuv_file_watcher = true,
    filtered_items = {
      visible = true,
      show_hidden_count = true,
      hide_dotfiles = false,
      hide_gitignored = true,
      hide_by_name = {
        ".git",
        ".DS_Store",
        "thumbs.db",
        ".idea",
      },
      never_show = {},
    },
    window = {
      mappings = {
        ["<space>"] = "none",
        ["l"] = "open",
        ["h"] = "close_node",
        ["r"] = filesystem_commands.rename,
        ["b"] = filesystem_commands.rename_basename,
        ["<D-S-f>"] = function(state)
          local fzf = require "fzf-lua"
          local node = state.tree:get_node()
          local dir = node.type == "directory" and node.path or node:get_parent_id()
          fzf.live_grep { search_paths = { dir } }
        end,
      },
    },
  },
  window = {
    width = 35,
  },
  default_component_configs = {
    git_status = {
      symbols = {
        unstaged = "󰄱",
        staged = "󰱒",
      },
    },
  },
}
