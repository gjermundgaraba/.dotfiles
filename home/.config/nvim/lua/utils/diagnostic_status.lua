local M = {}

local DIAG_ICON = ""

local function sort_diagnostics(diagnostics)
  table.sort(diagnostics, function(a, b)
    local a_lnum = a.lnum
    local b_lnum = b.lnum
    if a_lnum == b_lnum then
      return a.col < b.col
    end
    return a_lnum < b_lnum
  end)
end

local function cursor_in_diagnostic(diag, lnum, col)
  local start_lnum = diag.lnum
  local end_lnum = diag.end_lnum
  local start_col = diag.col
  local end_col = diag.end_col

  if lnum < start_lnum or lnum > end_lnum then
    return false
  end

  if start_lnum == end_lnum then
    return col >= start_col and col <= end_col
  end

  if lnum == start_lnum then
    return col >= start_col
  end

  if lnum == end_lnum then
    return col <= end_col
  end

  return true
end

local function diagnostic_under_cursor(diagnostics, lnum, col)
  for i, diag in ipairs(diagnostics) do
    if cursor_in_diagnostic(diag, lnum, col) then
      return i
    end
  end
end

local function next_diagnostic_or_last(diagnostics, lnum, col)
  for i, diag in ipairs(diagnostics) do
    if lnum < diag.lnum or (lnum == diag.lnum and col < diag.col) then
      return i
    end
  end
  return #diagnostics
end

local function diagnostics_index(bufnr)
  local diagnostics = vim.diagnostic.get(bufnr)
  if #diagnostics == 0 then
    return nil, 0
  end

  sort_diagnostics(diagnostics)

  local cursor = vim.api.nvim_win_get_cursor(0)
  local lnum = cursor[1] - 1
  local col = cursor[2]

  local idx = diagnostic_under_cursor(diagnostics, lnum, col) or next_diagnostic_or_last(diagnostics, lnum, col)
  return idx, #diagnostics
end

function M.statusline()
  local idx, total = diagnostics_index(0)
  if not idx or total == 0 then
    return ""
  end
  return string.format(" %s %d/%d", DIAG_ICON, idx, total)
end

return M
