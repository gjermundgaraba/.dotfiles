# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Setup

1. Install the Xcode Command Line Tools and [Homebrew](https://brew.sh/).
2. Clone this repository to `~/.dotfiles`.
3. Install the tracked Homebrew, Vite+, Node, and global JavaScript packages: `~/.dotfiles/bootstrap.sh install`.
4. Enable the repository's commit checks: `git -C ~/.dotfiles config core.hooksPath .githooks`.
5. Run `stow -R --no-folding -d ~/.dotfiles -t ~ home`.
6. Run `mkdir -p ~/.codex/skills ~/.config/nvim/.agents/skills && stow -R -d ~/.dotfiles -t ~ skills`.
7. Run `sudo stow -R --no-folding -d ~/.dotfiles -t /etc codex-system`.
8. Install the macOS LaunchAgent as a regular file because launchd may ignore symlinks: `mkdir -p ~/Library/LaunchAgents && install -m 600 ~/.dotfiles/macos/Library/LaunchAgents/local.capslock-f20.plist ~/Library/LaunchAgents/local.capslock-f20.plist`.
9. Load or reload the LaunchAgent after any previous instance finishes unloading:
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

## Local state

Most managed files are symlinked individually from this repository so unmanaged runtime data stays in local directories. The macOS LaunchAgent is copied instead because launchd may ignore symlinks. Skill packages are linked as complete directories because Codex does not discover symlinked `SKILL.md` files. Codex's durable CLI defaults are linked separately at `/etc/codex/config.toml`; its mutable user config remains local. VS Code and Cursor keep local profile symlinks to the shared files in `~/.config/vscode-settings/config`. Machine-specific Fish work helpers and browser-tunnel functions remain as regular local files outside this repository. Machine-local files that land inside the checkout are excluded by `.gitignore`, including:

- Fish universal variables, generated completions, and installer environment snippets
- Ghostty's local Claude settings
- GitHub CLI and Copilot authentication
- Codex authentication, sessions, generated state, plugin installs, and mutable user config
- Herdr sessions, pane history, plugin installs, state, logs, and sockets
- Pi model and MCP configuration, credentials, sessions, caches, package installs, and extension state
- Tool runtime files covered by configuration-specific ignore rules

Optional Git signing and other machine-specific overrides live in `~/.gitconfig`, outside this repository. Git reads them after the shared `~/.config/git/config`, and `git config --global` writes there.

OrbStack and Grok own their Fish completion files and recreate or update them when those tools are installed or updated. Do not force-add ignored local files.

Pi tracks npm package names in `settings.json`. During local extension development, the corresponding directories under `~/.pi/agent/npm/node_modules` may be symlinked to local package checkouts; these links remain machine-local.

## Themes

Edit `theme/palette.ts`, then run `node theme/build.ts`.
