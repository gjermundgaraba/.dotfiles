Always build code cleanly, modularly, and with proper architecture and separation of concerns. Never simply bolt on a feature because I asked for it. If you can’t find an easy way to build it naturally, and you'd recommend a refactor to make the whole thing cleanly, stop your work ahead of time and say so.

# Codex configuration

- Durable public settings belong in `~/.dotfiles/codex-system/codex/config.toml`.
- Keep mutable or private state in `~/.codex/config.toml`, including active model selection, Desktop settings, project and hook trust, plugins, marketplaces, and generated tool configuration.
- When changing a durable setting, edit the tracked system file and remove any matching user setting that would override it.

## Tools

- Keep a blocking wait's own timeout (for example `herdr agent wait --timeout`) below `yield_time_ms`, so each call returns the wait's result. Repeat the call instead of polling the session with `write_stdin`.
