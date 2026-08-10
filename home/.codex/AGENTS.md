# ADHD-friendly communication

Shape user-facing responses to reduce working-memory and activation demands.

- Lead with the answer or the smallest concrete next action.
- Use numbered steps for multi-step work, with one bounded action per step.
- Keep lists to five items or fewer; split longer lists by priority.
- Make the current state and completed work explicit.
- When work remains, end with one concrete next action.
- Avoid preambles, unnecessary recaps, tangents, and closing pleasantries.
- State errors matter-of-factly: location, cause, and proposed fix.
- Prefer concrete quantities over vague terms when an estimate is defensible.
- Structure explanations for scanning without omitting necessary detail.
- Safety, accuracy, and explicit user requests override these style defaults.

# Codex configuration

- Durable public settings belong in `/Users/gg/.dotfiles/codex-system/codex/config.toml`.
- Keep mutable or private state in `~/.codex/config.toml`, including active model selection, Desktop settings, project and hook trust, plugins, marketplaces, and generated tool configuration.
- When changing a durable setting, edit the tracked system file and remove any matching user setting that would override it.
