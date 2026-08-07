local M = {}

local function yank(value, label)
  if not value then
    vim.notify("Current buffer has no file path", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", value)
  vim.notify(label .. value, vim.log.levels.INFO, { timeout = 1000 })
end

function M.yank_file_path()
  yank(M.get_relative_path(), "Yanked file path: ")
end

function M.yank_context_file_path()
  yank(M.get_context_file_path(), "Yanked context file path: ")
end

function M.yank_context_range()
  yank(M.get_context_range(), "Yanked context range: ")
end

function M.yank_file_path_absolute()
  yank(M.get_file_path_absolute(), "Yanked absolute file path: ")
end

function M.get_file_path_absolute()
  local buf = vim.api.nvim_get_current_buf()
  if not M.is_buf_valid(buf) then
    return nil
  end
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p")
end

function M.get_context_file_path()
  local path = M.get_relative_path()
  if not path then
    return nil
  end
  return "@" .. path
end

function M.get_context_range()
  local path = M.get_relative_path()
  if not path then
    return nil
  end

  local start_line, end_line = M.get_visual_range()
  return string.format("@%s L%d-L%d", path, start_line, end_line)
end

function M.get_relative_path()
  local buf = vim.api.nvim_get_current_buf()
  if not M.is_buf_valid(buf) then
    return nil
  end
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
end

function M.get_visual_range()
  if vim.fn.mode():match "[vV\22]" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "x", true)
  end

  local buf = vim.api.nvim_get_current_buf()
  local from = vim.api.nvim_buf_get_mark(buf, "<")
  local to = vim.api.nvim_buf_get_mark(buf, ">")

  return math.min(from[1], to[1]), math.max(from[1], to[1])
end

function M.is_buf_valid(buf)
  return vim.api.nvim_get_option_value("buftype", { buf = buf }) == ""
    and vim.api.nvim_buf_get_name(buf) ~= ""
end

local map = require "utils.keymapper"

map.group("<leader>y", "[Y]ank")
map.nmap("<leader>ya", M.yank_context_file_path, { desc = "Yank context file path to clipboard" })
map.xmap("<leader>ya", M.yank_context_range, { desc = "Yank context range to clipboard" })
map.nmap("<leader>yf", M.yank_file_path, { desc = "Yank file path to clipboard" })
map.nmap("<leader>yr", M.yank_file_path_absolute, { desc = "Yank absolute file path to clipboard" })
