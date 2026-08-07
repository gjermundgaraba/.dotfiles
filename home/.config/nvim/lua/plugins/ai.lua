local M = {}

local add = require "utils.pack"

add {
  {
    src = "https://github.com/zbirenbaum/copilot.lua",
    version = "master",
  },
  {
    src = "https://github.com/folke/sidekick.nvim",
    version = "v2.3.0",
  },
}

local initialized = false

function M.setup()
  if initialized then
    return
  end
  require("sidekick").setup {}
  require("copilot").setup {
    panel = {
      enabled = false,
    },
    suggestion = {
      enabled = true,
      auto_trigger = true,
      hide_during_completion = true,
      keymap = {
        accept = false,
        accept_word = false,
        accept_line = false,
        next = false,
        prev = false,
        dismiss = false,
        toggle_auto_trigger = false,
      },
    },
    nes = {
      enabled = false,
    },
    root_dir = function()
      return vim.fs.root(0, ".git") or vim.fn.getcwd()
    end,
    server_opts_overrides = {
      settings = {
        telemetry = {
          telemetryLevel = "off",
        },
      },
    },
  }
  initialized = true
end

function M.accept_or_fallback()
  M.setup()
  if vim.snippet.active { direction = 1 } then
    vim.snippet.jump(1)
    return ""
  end

  if require("sidekick").nes_jump_or_apply() then
    return ""
  end

  local suggestion = require "copilot.suggestion"
  if suggestion.is_visible() then
    suggestion.accept()
    return ""
  end

  if vim.fn.pumvisible() == 1 then
    return "<C-n>"
  end

  return "<Tab>"
end

function M.accept_word()
  M.setup()
  local suggestion = require "copilot.suggestion"
  if suggestion.is_visible() then
    suggestion.accept_word()
  end
end

function M.accept_line()
  M.setup()
  local suggestion = require "copilot.suggestion"
  if suggestion.is_visible() then
    suggestion.accept_line()
  end
end

function M.previous_or_fallback()
  M.setup()
  if vim.snippet.active { direction = -1 } then
    vim.snippet.jump(-1)
    return ""
  end

  if vim.fn.pumvisible() == 1 then
    return "<C-p>"
  end

  return "<S-Tab>"
end

function M.next_edit_or_indent()
  M.setup()
  if require("sidekick").nes_jump_or_apply() then
    return ""
  end

  return ">>"
end

return M
