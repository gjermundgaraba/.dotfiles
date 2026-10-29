# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Setup

1. Install [Homebrew](https://brew.sh/):
   - macOS: install the Xcode Command Line Tools, then Homebrew.
   - Linux (Ubuntu on x86_64): as the login user, with sudo, install Homebrew at its default prefix, `/home/linuxbrew/.linuxbrew`, owned by that user. The machine's provisioning script sets this up.
2. Clone this repository to `~/.dotfiles`.
3. Install the tracked Homebrew, Vite+, Node, and global JavaScript packages: `~/.dotfiles/bootstrap.sh install`.
4. Enable the repository's commit checks and the filter that keeps Pi's machine-written settings out of commits: `git -C ~/.dotfiles config core.hooksPath .githooks && git -C ~/.dotfiles config filter.pi-settings.clean "jq 'del(.deviceId, .lastChangelogVersion)'"`.
5. Run `stow -R --no-folding --ignore='^\.config/nvim/\.agents/skills(/.*)?$' --ignore='(^|/)__pycache__(/.*)?$' -d ~/.dotfiles -t ~ home`. Neovim skills are installed as whole folders in the next step, and Python's bytecode caches stay in the repository.
6. Run `mkdir -p ~/.config/nvim/.agents/skills && stow -R -d ~/.dotfiles/home/.config/nvim/.agents -t ~/.config/nvim/.agents/skills skills`, then `mkdir -p ~/.codex/skills ~/.agents/skills ~/.claude/skills && stow -R -d ~/.dotfiles -t ~ skills`.
7. Run `sudo stow -R --no-folding -d ~/.dotfiles -t /etc codex-system`.
8. On macOS, install the LaunchAgent as a regular file because launchd may ignore symlinks: `mkdir -p ~/Library/LaunchAgents && install -m 600 ~/.dotfiles/macos/Library/LaunchAgents/local.capslock-f20.plist ~/Library/LaunchAgents/local.capslock-f20.plist`.
9. On macOS, load or reload the LaunchAgent after any previous instance finishes unloading:
   ```sh
   service="gui/$(id -u)/local.capslock-f20"
   if launchctl print "$service" >/dev/null 2>&1; then
     launchctl bootout "$service"
     while launchctl print "$service" >/dev/null 2>&1; do sleep 0.1; done
   fi
   launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/local.capslock-f20.plist
   ```
10. Create the machine-local Git config: `touch ~/.gitconfig && chmod 600 ~/.gitconfig`.
11. Install or launch tools such as OrbStack and Grok after Stowing so they can create their local Fish integrations.

Run the same Stow commands after moving, adding, or deleting managed files. `-R` removes obsolete links before recreating the current layout. Repeat steps 8–9 after changing the LaunchAgent.

## Packages

`Brewfile` and `packages/vite-plus.txt` are the reviewed package baseline, not a snapshot of everything installed on this machine. List or verify them without installing anything:

```sh
./bootstrap.sh list
./bootstrap.sh check
```

Project-specific, private, and manually installed tools stay outside these manifests.

## Skills

Personal skills live in `skills/.agents/skills/`; each has a relative link of
the same name in `skills/.claude/skills/`. Reusable skills,
including `orchestrate`, belong in the `clanker-stuff` repository's `skills/`
catalog. The Neovim-specific `update-neovim-plugins` skill lives beside its
configuration in `home/.config/nvim/.agents/skills/`; setup step 6 links each
complete skill folder rather than individual files.

Stow owns the personal skill links in `~/.agents/skills/` and `~/.claude/skills/`.
Skills owned by other repositories are linked directly from their checkouts
into both host locations and are not part of this Stow package: reusable skills
from `clanker-stuff/skills/`, and the Herdr skill from the personal Herdr
fork's `skills/herdr/`. Codex discovers those skills
through `~/.agents/skills/`, without duplicate installations in
`~/.codex/skills/`. Parent skill directories must remain real directories, as
ensured by setup step 6.

Use `AGENTS.md` for instructions. Checkout helpers do not generate `CLAUDE.md`
aliases. The exception is `~/.claude/CLAUDE.md`, which only imports
`~/.claude/AGENTS.md`: Claude Code has no global `AGENTS.md`, and reads that
file only as a fallback in directories under `~` that have no `CLAUDE.md`.

## Local state

Most managed files are symlinked individually from this repository so unmanaged runtime data stays in local directories. The macOS LaunchAgent is copied instead because launchd may ignore symlinks. Skill packages are linked as complete directories because Codex does not discover symlinked `SKILL.md` files. Codex's durable CLI defaults are linked separately at `/etc/codex/config.toml`; its mutable user config remains local. VS Code and Cursor keep local profile symlinks to the shared files in `~/.config/vscode-settings/config`. Cursor user rules live in `~/.cursor/rules`; only reviewed `.mdc` files are tracked, and plugin-generated rules stay local. Claude Code's `~/.claude/settings.json` is shared. Hook entries written by hand use `$HOME` and skip themselves when their optional tool is not installed; entries a tool writes itself, such as tldraw offline's, are kept as written because the tool rewrites them. Only reviewed hook scripts are tracked, and tool-installed hook scripts such as Herdr's stay local. Pi writes a device identifier and its last-seen changelog version into the shared `settings.json`; the `pi-settings` filter from setup step 4 strips both from commits, and the Gitleaks `pi-device-id` rule blocks the identifier in clones without the filter. Machine-specific Fish work helpers and browser-tunnel functions remain as regular local files outside this repository. Machine-local files that land inside the checkout are excluded by `.gitignore`, including:

- Fish universal variables, generated completions, and installer environment snippets
- Ghostty's local Claude settings
- GitHub CLI and Copilot authentication
- Codex authentication, sessions, generated state, plugin installs, and mutable user config
- Herdr sessions, pane history (`pane_history = true` writes terminal contents to disk, which may include secrets), plugin installs, state, logs, and sockets
- Pi model and MCP configuration, credentials, sessions, caches, package installs, and extension state
- Tool runtime files covered by configuration-specific ignore rules

Ghostty loads machine-local settings from `~/.config/ghostty/local` (`config-file = ?local`), such as `font-codepoint-map` entries for locally built glyph fonts.

Optional Git signing and other machine-specific overrides live in `~/.gitconfig`, outside this repository. Git reads them after the shared `~/.config/git/config`, and `git config --global` writes there.

OrbStack and Grok own their Fish completion files and recreate or update them when those tools are installed or updated. Do not force-add ignored local files.

Pi tracks npm package names in `settings.json`. During local extension development, the corresponding directories under `~/.pi/agent/npm/node_modules` may be symlinked to local package checkouts; these links remain machine-local.

## Themes

Edit `theme/palette.ts`, then run `node theme/build.ts`.

Pi themes are generated from `theme/templates/pi.json` into
`home/.pi/agent/themes/gg-{dark,light}.json`, alongside the Neovim, Ghostty,
Fish, and Herdr themes. Do not edit generated themes directly.
The same build writes the web tokens in `theme/web/`, published to npm as
`@gjermundgaraba/gg-theme`. To release, bump `version` in
`theme/web/package.json`, rebuild, and run `npm publish` from `theme/web`.
After Stowing, select `gg-dark` or `gg-light` via Pi's `/settings`, or run
`pi --use-theme gg-light/gg-dark` to follow terminal appearance.
