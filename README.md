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

Whole configuration directories are symlinked into this repository. Machine-local files therefore live inside the checkout but are excluded by `.gitignore`, including:

- Fish universal variables, generated completions, and installer environment snippets
- Ghostty's local Claude settings
- GitHub Copilot authentication
- Tool runtime files covered by configuration-specific ignore rules

Optional Git signing and other machine-specific overrides live in `~/.gitconfig`, outside this repository. Git reads them after the shared `~/.config/git/config`, and `git config --global` writes there.

OrbStack and Grok own their Fish completion files and recreate or update them when those tools are installed or updated. Do not force-add ignored local files.

## Themes

Edit `theme/palette.ts`, then run `node theme/build.ts`.
