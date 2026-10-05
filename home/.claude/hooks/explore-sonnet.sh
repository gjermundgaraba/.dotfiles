#!/bin/sh
# PreToolUse hook for the Agent tool: run the built-in Explore subagent on Sonnet.
# The built-in Explore agent inherits the session model, and CLAUDE_CODE_SUBAGENT_MODEL
# doesn't apply to it, so we set the per-call `model` parameter instead.
# Other subagent types, and Explore calls that already set a model, pass through untouched.

jq -c '
  select(.tool_input.subagent_type == "Explore" and ((.tool_input.model // "") == ""))
  | {hookSpecificOutput: {
      hookEventName: "PreToolUse",
      updatedInput: (.tool_input + {model: "sonnet"})
    }}
' 2>/dev/null

exit 0
