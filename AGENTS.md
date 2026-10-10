# Public repository safety

- Treat this repository and its full Git history as public.
- Track only durable configuration intended to be shared across machines.
- Keep credentials, tokens, authentication databases, private infrastructure, internal repository paths, machine identifiers, sessions, caches, logs, and generated state in ignored machine-local files.
- For stateful tools, ignore the application directory by default and explicitly allow only reviewed configuration files.
- Before tracking a new file, inspect its contents and neighboring files for sensitive data. If unsure, leave it ignored and ask.
- Never bypass `.gitignore` with `git add -f`, bypass checks with `--no-verify`, or weaken a protective ignore rule without explicit approval.
- Before every commit, inspect `git diff --cached` and run the configured Gitleaks check.
- Do not commit or push without explicit user approval.

# Skills and instructions

- Personal skills belong in the `skills` Stow package; reusable skills belong in `clanker-stuff/skills/`.
- Keep the Neovim-specific skill beside its configuration in `home/.config/nvim/.agents/skills/`. Follow the README's installation commands so Stow links complete skill folders, not individual `SKILL.md` files.
- See README.md for installation. Stow owns personal skills; skills owned by other repositories, such as `clanker-stuff/skills/` and the personal Herdr fork's `skills/herdr/`, are linked directly from their checkouts. Do not change installed links without authorization.
- Keep each personal skill on one source in `skills/.agents/skills/`, with a relative Claude host link in `skills/.claude/skills/`; do not duplicate its content.
- For user-invocation-only skills, configure both `disable-model-invocation: true` in `SKILL.md` and `policy.allow_implicit_invocation: false` in `agents/openai.yaml`.
- Use `AGENTS.md` for instructions; do not create `CLAUDE.md` aliases.
