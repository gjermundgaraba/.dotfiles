local disable_session_for_startup = vim.env.NVIM_OPEN_EXPLORER == "1"
local restore_session_keys = "<leader>sr"

local add = require "utils.pack"

local restore_mapping_active = false

local function remove_restore_mapping()
  if restore_mapping_active then
    vim.keymap.del("n", restore_session_keys)
    restore_mapping_active = false
  end
end

local function restore_session()
  if vim.bo.filetype == "neo-tree" then
    vim.cmd.wincmd "p"
  end

  remove_restore_mapping()
  require("auto-session").restore_session()
end

local function setup_startup_restore()
  if disable_session_for_startup then
    return
  end

  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("gg/session_startup_restore", { clear = true }),
    once = true,
    callback = function()
      if not require("utils.startup").directory() or not require("auto-session").session_exists_for_cwd() then
        return
      end

      require("utils.keymapper").nmap(restore_session_keys, restore_session, { desc = "Restore session" })
      restore_mapping_active = true

      vim.api.nvim_create_autocmd("BufEnter", {
        group = "gg/session_startup_restore",
        callback = function(args)
          local name = vim.api.nvim_buf_get_name(args.buf)
          local stat = name ~= "" and vim.uv.fs_stat(name)
          if vim.bo[args.buf].buftype == "" and name ~= "" and (not stat or stat.type ~= "directory") then
            remove_restore_mapping()
            return true
          end
        end,
      })

      local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
      vim.notify(("Session available for %s. Press %s to restore it."):format(cwd, restore_session_keys), vim.log.levels.INFO, { title = "Session" })
    end,
  })
end

add {
  {
    src = "https://github.com/rmagatti/auto-session",
    version = "main",
  },
}

require("auto-session").setup {
  enabled = not disable_session_for_startup,
  suppressed_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
  auto_restore = false,
}

setup_startup_restore()
