# Codex configuration

- Durable public settings belong in `~/.dotfiles/codex-system/codex/config.toml`.
- Keep mutable or private state in `~/.codex/config.toml`, including active model selection, Desktop settings, project and hook trust, plugins, marketplaces, and generated tool configuration.
- When changing a durable setting, edit the tracked system file and remove any matching user setting that would override it.
