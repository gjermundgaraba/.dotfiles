local M = {}
local keymaps = {}

---@class MapOpts
---@field desc string Required description
---@field buffer? number Buffer-local keymap
---@field expr? boolean Expression mapping
---@field silent? boolean Silent mapping (default: true)
---@field nowait? boolean No wait for additional keys

local function normalize_key(key)
  local result = key:gsub("<[Ll][Ee][Aa][Dd][Ee][Rr]>", vim.g.mapleader or "\\")
  return result:gsub("<([^>]+)>", function(inner)
    return "<" .. inner:lower() .. ">"
  end)
end

local function check_duplicates(modes, lhs, opts)
  if opts.buffer then
    return
  end

  for _, mode in ipairs(modes) do
    local key = mode .. ":" .. normalize_key(lhs)
    if keymaps[key] then
      error(string.format("[keymapper] Duplicate keymap: '%s' (mode: %s)", lhs, mode))
    end
    keymaps[key] = true
  end
end

function M.map(mode, lhs, rhs, opts)
  opts = opts or {}
  if not opts.desc then
    vim.notify(string.format("[keymapper] Missing desc: %s", lhs), vim.log.levels.WARN)
  end

  check_duplicates(type(mode) == "table" and mode or { mode }, lhs, opts)

  local vim_opts = vim.tbl_extend("force", {}, opts)
  vim_opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, vim_opts)
end

function M.nmap(lhs, rhs, opts)
  M.map("n", lhs, rhs, opts)
end
function M.imap(lhs, rhs, opts)
  M.map("i", lhs, rhs, opts)
end
function M.vmap(lhs, rhs, opts)
  M.map("v", lhs, rhs, opts)
end
function M.xmap(lhs, rhs, opts)
  M.map("x", lhs, rhs, opts)
end
function M.tmap(lhs, rhs, opts)
  M.map("t", lhs, rhs, opts)
end

function M.leader(lhs, rhs, opts)
  M.map("n", "<leader>" .. lhs, rhs, opts)
end

function M.group(prefix, name, opts)
  opts = opts or {}
  require("which-key").add {
    prefix,
    group = name,
    icon = opts.icon,
    mode = opts.mode,
  }
end

return M
