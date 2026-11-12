-- Helpers shared by init.lua and its modules.

local M = {}

-- The rex binary of this Mac's Rex server. The server runs commands with only the system PATH
M.rex = os.getenv("HOME") .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/"
  .. "Rex Server.app/Contents/MacOS/rex"

-- Runs a command and returns its output, or raises what it printed to stderr. Rex shows the error
-- with its own "Error: " prefix, so drop the one CLIs such as rex and rex-state print. opts is
-- rex.exec's
function M.run(argv, opts)
  local r, err = rex.exec(argv, opts)
  if not r then error(err, 0) end
  local name = argv[1]:match("[^/]+$")
  if r.timed_out then error(name .. " timed out", 0) end
  if not r.ok then
    local message = r.stderr:gsub("^Error: ", ""):gsub("%s+$", "")
    error(message ~= "" and message or name .. " exited with code " .. r.code, 0)
  end
  return r.stdout
end

function M.notify(text, title)
  rex.exec({
    "osascript",
    "-e", "on run argv",
    "-e", "display notification (item 1 of argv) with title (item 2 of argv)",
    "-e", "end run",
    text, title,
  })
end

function M.copy(text, title)
  local copied = rex.exec({ "pbcopy" }, { stdin = text })
  if copied and copied.ok then M.notify(text, title) end
  return text
end

return M
