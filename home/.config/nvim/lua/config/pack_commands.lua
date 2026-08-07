local function get_pack_plugins(names, opts)
  local ok, plugins = pcall(vim.pack.get, names, opts)
  if not ok then
    vim.notify(plugins, vim.log.levels.ERROR)
    return {}
  end

  table.sort(plugins, function(a, b)
    return a.spec.name < b.spec.name
  end)

  return plugins
end

local function complete_pack_names(arg_lead)
  local plugins = get_pack_plugins(nil, { info = false })
  local matches = {}

  for _, plugin in ipairs(plugins) do
    local name = plugin.spec.name
    if arg_lead == "" or vim.startswith(name, arg_lead) then
      table.insert(matches, name)
    end
  end

  return matches
end

local function open_scratch_window(lines)
  vim.cmd "botright new"

  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "text"

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

vim.api.nvim_create_user_command("PackList", function(opts)
  local names = #opts.fargs > 0 and opts.fargs or nil
  local plugins = get_pack_plugins(names)

  if #plugins == 0 then
    vim.notify("No vim.pack plugins found", vim.log.levels.INFO)
    return
  end

  local lines = {
    "A = active in current session, I = inactive",
    "",
    string.format("%-2s %-24s %-10s %s", "", "Name", "Revision", "Source"),
    string.rep("-", 100),
  }

  for _, plugin in ipairs(plugins) do
    table.insert(lines, string.format(
      "%-2s %-24s %-10s %s",
      plugin.active and "A" or "I",
      plugin.spec.name,
      plugin.rev and plugin.rev:sub(1, 10) or "-",
      plugin.spec.src
    ))
  end

  open_scratch_window(lines)
end, {
  nargs = "*",
  complete = complete_pack_names,
  desc = "List vim.pack plugins",
})

vim.api.nvim_create_user_command("PackClean", function(opts)
  local inactive = {}

  for _, plugin in ipairs(get_pack_plugins()) do
    if not plugin.active then
      table.insert(inactive, plugin.spec.name)
    end
  end

  if #inactive == 0 then
    vim.notify("No inactive vim.pack plugins to remove", vim.log.levels.INFO)
    return
  end

  if not opts.bang then
    local prompt = {
      string.format("Delete %d inactive vim.pack plugin(s)?", #inactive),
      "",
    }
    vim.list_extend(prompt, inactive)

    local choice = vim.fn.confirm(table.concat(prompt, "\n"), "&Delete\n&Cancel", 2)
    if choice ~= 1 then
      return
    end
  end

  local ok, err = pcall(vim.pack.del, inactive)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  vim.notify(("Removed %d inactive vim.pack plugin(s)"):format(#inactive), vim.log.levels.INFO)
end, {
  bang = true,
  desc = "Delete inactive vim.pack plugins (:PackClean! skips confirmation)",
})

vim.api.nvim_create_user_command("PackUpdate", function(opts)
  local names = #opts.fargs > 0 and opts.fargs or nil
  local ok, err = pcall(vim.pack.update, names)

  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
  end
end, {
  nargs = "*",
  complete = complete_pack_names,
  desc = "Update vim.pack plugins",
})

local function prompt_path(prompt)
  local path = vim.fn.input { prompt = prompt, completion = "file" }
  if path == nil or path == "" then
    return nil
  end
  return vim.fn.fnamemodify(vim.fn.expand(path), ":p")
end

vim.api.nvim_create_user_command("DiffToolPrompt", function()
  local left = prompt_path "DiffTool left: "
  if not left then
    return
  end

  local right = prompt_path "DiffTool right: "
  if not right then
    return
  end

  vim.cmd.packadd "nvim.difftool"
  vim.cmd.DiffTool { args = { left, right } }
end, {})
