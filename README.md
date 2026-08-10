# Dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Setup

1. Install Fish and Stow: `brew install fish stow`
2. Clone this repository to `~/.dotfiles`.
3. Run `stow -R -d ~/.dotfiles -t ~ home`.
4. Create the machine-local Git config: `touch ~/.gitconfig && chmod 600 ~/.gitconfig`.
5. Install or launch tools such as OrbStack and Grok after Stowing so they can create their local Fish integrations.

Run the same Stow command after moving, adding, or deleting managed files. `-R` removes obsolete links before recreating the current layout.

## Local state

Managed files are symlinked from this repository. Configuration directories are linked whole where safe; Claude Code, Herdr, and OpenCode files are linked individually so their runtime data stays local. VS Code and Cursor keep local profile symlinks to the shared files in `~/.config/vscode-settings/config`. Machine-local files that land inside the checkout are excluded by `.gitignore`, including:

- Fish universal variables, generated completions, and installer environment snippets
- Ghostty's local Claude settings
- GitHub CLI and Copilot authentication
- Herdr sessions, pane history, plugin installs, state, logs, and sockets
- Tool runtime files covered by configuration-specific ignore rules

Optional Git signing and other machine-specific overrides live in `~/.gitconfig`, outside this repository. Git reads them after the shared `~/.config/git/config`, and `git config --global` writes there.

OrbStack and Grok own their Fish completion files and recreate or update them when those tools are installed or updated. Do not force-add ignored local files.

## Themes

Edit `theme/palette.ts`, then run `node theme/build.ts`.
