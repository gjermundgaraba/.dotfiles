local M = {}

function M.directory()
  if vim.list_contains(vim.v.argv, "-") then
    return nil
  end
  if vim.fn.argc() == 0 then
    return vim.fn.getcwd()
  end
  if vim.fn.argc() ~= 1 then
    return nil
  end

  local path = vim.fn.fnamemodify(vim.fn.argv(0), ":p")
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == "directory" and path or nil
end

return M
