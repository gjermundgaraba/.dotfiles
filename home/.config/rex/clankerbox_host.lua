-- The app doesn't yet show hosts added with `rex hosts add`, and nothing adds a host to it by address
-- from a script. So this opens its Add Remote Host prompt and enters the address with Cua Driver,
-- which works while Rex is in the background. It needs Remote Control turned on in the app's
-- settings and Cua Driver's daemon running, and a Rex update that changes the prompt can break it.

local helpers = require("helpers")
local run, notify = helpers.run, helpers.notify

local M = {}

local home = os.getenv("HOME")
local CLANKERBOX = home .. "/.vite-plus/bin/clankerbox"
local CUA_DRIVER = home .. "/.local/bin/cua-driver"
local TEMPLATE = "gg-linux-dev"
local REX_APP = "com.superlogical.rex"
local FIELD = "Command Palette Search"
local TITLE = "New Clankerbox Host"
local TIMEOUT_SECONDS = 600

local function sleep(seconds) rex.exec({ "/bin/sleep", tostring(seconds) }) end

local function wait(deadline, message, check)
  while true do
    local value = check()
    if value then return value end
    if os.time() >= deadline then error(message, 0) end
    sleep(3)
  end
end

local function ask(prompt)
  local r, err = rex.exec({
    "osascript",
    "-e", "on run argv",
    "-e", "activate",
    "-e", "text returned of (display dialog (item 1 of argv) default answer \"\" with title (item 2 of argv))",
    "-e", "end run",
    prompt, TITLE,
  })
  if not r then error(err, 0) end
  if not r.ok then
    if r.stderr:find("%(%-128%)") then return nil end
    error((r.stderr:gsub("%s+$", "")), 0)
  end
  local text = r.stdout:gsub("^%s+", ""):gsub("%s+$", "")
  if text ~= "" then return text end
end

local function machine(name)
  local r, err = rex.exec({ CLANKERBOX, "get", name, "--json" })
  if not r then error(err, 0) end
  local reply = rex.json.decode(r.stdout) or {}
  if r.ok then return reply end
  if reply.error and reply.error.tag == "NotFound" then return nil end
  error("clankerbox: " .. (reply.error and reply.error.message or r.stderr), 0)
end

local function tailnet_name(name)
  local tailnet = (machine(name) or {}).tailnet or {}
  if tailnet.state == "joined" and tailnet.name ~= "" then return tailnet.name end
end

-- The names of the hosts the Mac app lists. Ask the app: the server lists hosts it doesn't show
local function app_hosts()
  local out = run({
    "osascript",
    "-e", "set text item delimiters to linefeed",
    "-e", 'tell application id "' .. REX_APP .. '" to return (name of every host) as text',
  })
  local names = {}
  for line in out:gmatch("[^\n]+") do names[line] = true end
  return names
end

local function driver(tool, args)
  local r, err = rex.exec({ CUA_DRIVER, "call", tool, rex.json.encode(args) })
  if not r then error(err, 0) end
  local reply = rex.json.decode(r.stdout)
  if not reply then
    error("cua-driver: " .. (r.stdout .. r.stderr):gsub("%s+$", ""), 0)
  end
  if reply.ok == false or reply.error then
    for _, step in ipairs(reply.steps or {}) do
      if step.ok == false then error("cua-driver: " .. step.message, 0) end
    end
    error("cua-driver: " .. tostring(reply.error or r.stdout), 0)
  end
  return reply
end

local function window_with_palette_field()
  for _, window in ipairs(driver("list_windows", { app = REX_APP }).windows or {}) do
    local state = driver("get_window_state", {
      pid = window.pid, window_id = window.window_id,
      query = FIELD, tree_format = "elements", include_screenshot = false,
    })
    for _, element in ipairs(state.elements or {}) do
      if element.role == "AXTextArea" and element.label == FIELD then return window end
    end
  end
end

-- Adds ENDPOINT to the app that ran the action, through its Add Remote Host prompt. Run any other
-- way, such as with `rex do`, ctx names that caller, so leave the choice to rex, which takes the app
-- when only one is connected
local function add_to_app(ctx, endpoint)
  if app_hosts()[endpoint] then return end
  if ctx.origin == "key" or ctx.origin == "palette" then
    run({ helpers.rex, "-C", ctx.client_id, "do", "client.host.add" })
  else
    run({ helpers.rex, "do", "client.host.add" })
  end

  local window
  for _ = 1, 10 do
    window = window_with_palette_field()
    if window then break end
    sleep(0.3)
  end
  if not window then error("Rex.app didn't open Add Remote Host", 0) end

  local function steps(list)
    return driver("run_steps", {
      session = "new-clankerbox-host", pid = window.pid, window_id = window.window_id, steps = list,
    })
  end
  local ok, err = pcall(steps, {
    { set_value = { role = "textarea", name = FIELD, value = endpoint } },
    { expect = {
      { role = "textarea", name = FIELD, value = endpoint },
      { text = "Connect to “" .. endpoint .. "”" },
    } },
    { press_key = { role = "textarea", name = FIELD, key = "return" } },
  })
  if not ok then
    pcall(steps, { { press_key = { key = "escape" } } })
    error(err, 0)
  end

  for _ = 1, 20 do
    if app_hosts()[endpoint] then return end
    sleep(0.5)
  end
  error("Rex.app didn't list " .. endpoint .. " after Return", 0)
end

local function create_host(ctx, name)
  local deadline = os.time() + TIMEOUT_SECONDS
  local existing = machine(name)
  if not existing then
    run({ CLANKERBOX, "create", "--template", TEMPLATE, "--timeout", TIMEOUT_SECONDS .. "s", name },
      { timeout = TIMEOUT_SECONDS })
  elseif existing.state ~= "running" then
    error(name .. " exists and is " .. tostring(existing.state), 0)
  end
  -- Clankerbox joins the tailnet in a separate step after create returns.
  local endpoint = wait(deadline, name .. " didn't join the tailnet", function()
    return tailnet_name(name)
  end)
  wait(deadline, "Rex on " .. endpoint .. " didn't answer", function()
    local r = rex.exec({ helpers.rex, "-S", endpoint, "--timeout", "3s", "whoami" })
    return r and r.ok
  end)
  add_to_app(ctx, endpoint)
  return endpoint
end

function M.setup()
  rex.action{
    name        = "new_clankerbox_host",
    title       = TITLE,
    description = "Creates a clankerbox machine and adds it to the Mac app as a remote host",
    keywords    = "clankerbox machine vm create remote host tailscale",
    args        = { name = "string?" },
    run         = function(ctx, args)
      local name = (args or {}).name or ask("Name of the new clankerbox machine:")
      if not name then return end
      if not name:match("^[a-z0-9][a-z0-9-]*$") then
        error("A machine name takes lowercase letters, digits and hyphens: " .. name, 0)
      end
      notify("Setting up " .. name .. "…", TITLE)
      local ok, result = pcall(create_host, ctx, name)
      if not ok then
        notify(tostring(result), TITLE .. " failed")
        error(result, 0)
      end
      notify("Added " .. result, TITLE)
      return result
    end,
  }
end

return M
