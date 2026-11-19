-- The app doesn't yet show hosts added with `rex hosts add`, and nothing adds a host to it by address
-- from a script. So this opens its Add Remote Host prompt and enters the address with Cua Driver,
-- which works while Rex is in the background. It needs Remote Control turned on in the app's
-- settings and Cua Driver's daemon running, and a Rex update that changes the prompt can break it.
-- It asks for the name, and then for the template among the ready ones when there's more than one,
-- unless `rex do new_clankerbox_host name=… template=…` gives them.

local helpers = require("helpers")
local run, notify = helpers.run, helpers.notify

local M = {}

local home = os.getenv("HOME")
local CLANKERBOX = home .. "/.vite-plus/bin/clankerbox"
local CUA_DRIVER = home .. "/.local/bin/cua-driver"
local DEFAULT_TEMPLATE = "gg-linux-dev" -- listed first
local REX_APP = "com.superlogical.rex"
local FIELD = "Command Palette Search"
local TITLE = "New Clankerbox Host"
local TIMEOUT_SECONDS = 600

local function wait(deadline, message, check)
  while true do
    local value = check()
    if value then return value end
    if os.time() >= deadline then error(message, 0) end
    rex.sleep(3)
  end
end

-- Raises why a question in the command palette got no answer, or returns nil when it was cancelled
local function unanswered(what, why, detail)
  if why == "cancelled" then return nil end
  error("Couldn't ask for " .. what .. ": " .. why .. (detail and (": " .. detail) or ""), 0)
end

-- Rex can only pause for the answer in the action's own run, not under pcall
local function ask_name()
  local text, why, detail = rex.ui.input{
    title       = "Name of the new clankerbox machine",
    placeholder = "lowercase letters, digits and hyphens",
    confirm     = "Continue",
  }
  if text == nil then return unanswered("a name", why, detail) end
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if text ~= "" then return text end
end

-- Runs a clankerbox command for its JSON reply. Returns the reply, or nil and the error's fields
local function clankerbox(argv)
  local command = { CLANKERBOX }
  for _, arg in ipairs(argv) do command[#command + 1] = arg end
  command[#command + 1] = "--json"
  local r, err = rex.exec(command)
  if not r then error(err, 0) end
  local reply = rex.json.decode(r.stdout) or {}
  if r.ok then return reply end
  if not reply.error then error("clankerbox: " .. (r.stderr:gsub("%s+$", "")), 0) end
  return nil, reply.error
end

local function machine(name)
  local reply, err = clankerbox({ "get", name })
  if reply then return reply end
  if err.tag == "NotFound" then return nil end
  error("clankerbox: " .. tostring(err.message), 0)
end

-- A template's current build, which a create clones
local function current_build(template)
  for _, build in ipairs(template.builds or {}) do
    if build.id == template.current then return build end
  end
  return {}
end

-- The pick list's item for a template: its base and sizes, and the hosts that hold a copy
local function template_item(template)
  local build = current_build(template)
  local hosts = {}
  for _, copy in ipairs(build.copies or {}) do
    if copy.phase == "ready" then hosts[#hosts + 1] = copy.host end
  end
  return {
    id       = template.id,
    icon     = "server",
    subtitle = string.format("%s · %s vCPU, %s GiB RAM, %s GiB disk", tostring(build.base),
      tostring(build.cpu), tostring(build.ramMib and math.floor(build.ramMib / 1024)), tostring(build.diskGib)),
    detail   = table.concat(hosts, ", "),
  }
end

-- Asks which ready template to create the machine from, the default one first. Takes the only one
-- without asking, and returns nil when the question is cancelled
local function pick_template(name)
  local reply, err = clankerbox({ "template", "list" })
  if not reply then error("clankerbox: " .. tostring(err.message), 0) end
  local items = {}
  for _, template in ipairs(reply.templates or {}) do
    if template.state == "ready" then
      local item = template_item(template)
      if template.id == DEFAULT_TEMPLATE then table.insert(items, 1, item) else items[#items + 1] = item end
    end
  end
  if #items == 0 then error("clankerbox has no ready template", 0) end
  if #items == 1 then return items[1].id end
  local id, why, detail = rex.ui.pick{
    title       = "Template for " .. name,
    placeholder = "Filter templates",
    confirm     = "Create machine",
    items       = items,
  }
  if id == nil then return unanswered("a template", why, detail) end
  return id
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
    rex.sleep(0.3)
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
    rex.sleep(0.5)
  end
  error("Rex.app didn't list " .. endpoint .. " after Return", 0)
end

local function create_host(ctx, name, template)
  local deadline = os.time() + TIMEOUT_SECONDS
  local existing = machine(name)
  if not existing then
    if not template then error(name .. " is gone; run again to pick its template", 0) end
    run({ CLANKERBOX, "create", "--template", template, "--timeout", TIMEOUT_SECONDS .. "s", name },
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
    args        = { name = "string?", template = "string?" },
    run         = function(ctx, args)
      args = args or {}
      local name = args.name or ask_name()
      if not name then return end
      if not name:match("^[a-z0-9][a-z0-9-]*$") then
        error("A machine name takes lowercase letters, digits and hyphens: " .. name, 0)
      end
      -- Asked here, outside the pcall below, where Rex can pause for the answer. A machine that has
      -- the name already needs no template
      local template = args.template
      if not template and not machine(name) then
        template = pick_template(name)
        if not template then return end
      end
      notify("Setting up " .. name .. "…", TITLE)
      local ok, result = pcall(create_host, ctx, name, template)
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
