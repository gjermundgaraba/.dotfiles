-- Prints each terminal pane on one Rex server that has program status, as one JSON line.
-- agent-picker runs it on every host with: rex -S SERVER do agent-picker.lua

local terminal = "com.superlogical.terminal"

local list, err = rex.call("session.list")
if not list then error(err, 0) end

for _, session in ipairs(list.sessions or {}) do
  local sid = session.session_id
  -- session.view refuses a session this script isn't attached to
  rex.call("session.attach", { session_id = sid })
  local view = rex.call("session.view", { session_id = sid }) or {}
  for _, window in ipairs(view.windows or {}) do
    for _, layer in ipairs(window.layers or {}) do
      for _, block in ipairs(layer.blocks or {}) do
        if block.creator_name == terminal then
          local args = { session_id = sid, block_id = block.block_id }
          local records = (rex.block.call(terminal, "program_status", args) or {}).records or {}
          if #records > 0 then
            print(rex.json.encode({
              session = sid,
              label   = session.label,
              window  = window.window_id,
              block   = block.block_id,
              title   = (rex.block.call(terminal, "title", args) or {}).title,
              records = records,
            }))
          end
        end
      end
    end
  end
end
