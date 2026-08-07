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

local function cursor_in_diagnostic(diag, row, col)
  local start_row = diag.lnum
  local end_row = diag.end_lnum
  local start_col = diag.col
  local end_col = diag.end_col

  if row < start_row or row > end_row then
    return false
  end

  if start_row == end_row then
    return col >= start_col and col <= end_col
  end

  if row == start_row then
    return col >= start_col
  end

  if row == end_row then
    return col <= end_col
  end

  return true
end

local function diagnostics_index(bufnr)
  local diagnostics = vim.diagnostic.get(bufnr)
  if #diagnostics == 0 then
    return nil, 0
  end

  sort_diagnostics(diagnostics)

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- APIs are 0-indexed.
  local col = cursor[2]

  -- If cursor is inside a diagnostic, report that one.
  for i, diag in ipairs(diagnostics) do
    if cursor_in_diagnostic(diag, row, col) then
      return i, #diagnostics
    end
  end

  -- Otherwise, use the nearest forward diagnostic, or last when after all diagnostics.
  for i, diag in ipairs(diagnostics) do
    local start_row = diag.lnum
    local start_col = diag.col
    if row < start_row or (row == start_row and col < start_col) then
      return i, #diagnostics
    end
  end

  return #diagnostics, #diagnostics
end

function M.statusline()
  local idx, total = diagnostics_index(0)
  if not idx or total == 0 then
    return ""
  end
  return string.format(" %s %d/%d", DIAG_ICON, idx, total)
end

return M
