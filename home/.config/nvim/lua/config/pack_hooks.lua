local hooks = {
  ["nvim-treesitter"] = function()
    vim.cmd "TSUpdate"
  end,
  ["fff.nvim"] = function()
    require("fff.download").download_or_build_binary()
  end,
}

vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("gg/pack-build", { clear = true }),
  callback = function(ev)
    local data = ev.data
    local hook = data and data.spec and hooks[data.spec.name]
    if not hook or (data.kind ~= "install" and data.kind ~= "update") then
      return
    end

    vim.schedule(function()
      if not data.active then
        vim.cmd.packadd(data.spec.name)
      end
      hook()
    end)
  end,
})
