local hooks = {
  ["nvim-treesitter"] = function()
    assert(require("nvim-treesitter").update(nil, { summary = true }):wait(300000), "Tree-sitter parser update failed")
  end,
  ["fff"] = function()
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

    if not data.active then
      vim.cmd.packadd(data.spec.name)
    end
    -- Finish build hooks before vim.pack returns, including in headless updates.
    hook()
  end,
})
