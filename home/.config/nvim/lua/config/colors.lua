local M = {}

local function apply(bg)
  local scheme = bg == "dark" and "gg-dark" or "gg-light"
  if vim.g.colors_name ~= scheme then
    vim.cmd.colorscheme(scheme)
  end
end

function M.apply()
  if vim.fn.has("macunix") ~= 1 or vim.fn.executable("defaults") ~= 1 then
    apply(vim.o.background)
    return
  end

  vim.system({ "defaults", "read", "-g", "AppleInterfaceStyle" }, { text = true }, function(result)
    local bg = result.code == 0 and (result.stdout or ""):match "Dark" and "dark" or "light"
    vim.schedule(function()
      apply(bg)
    end)
  end)
end

apply(vim.o.background)
M.apply()

vim.api.nvim_create_autocmd("FocusGained", {
  group = vim.api.nvim_create_augroup("gg/system-theme", { clear = true }),
  desc = "Sync colorscheme with system appearance",
  callback = M.apply,
})

return M
