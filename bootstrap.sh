#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
brewfile="$root/Brewfile"
vite_packages="$root/packages/vite-plus.txt"
node_version=$(tr -d '[:space:]' <"$root/home/.node-version")

if ! command -v brew >/dev/null 2>&1; then
  for prefix in /opt/homebrew /home/linuxbrew/.linuxbrew; do
    if test -x "$prefix/bin/brew"; then PATH="$prefix/bin:$PATH"; fi
  done
fi

# Vite+'s env scripts and config.fish assume this layout; without VP_HOME,
# the installer picks split directories on a fresh machine.
export VP_HOME="$HOME/.vite-plus"
export PATH="$VP_HOME/bin:$PATH"

usage() {
  echo "usage: $0 <list|install|link|check>" >&2
  exit 2
}

require_brew() {
  command -v brew >/dev/null 2>&1 || {
    echo "install Homebrew from https://brew.sh, then rerun this command" >&2
    exit 1
  }
}

vite_package_installed() {
  package=$1
  name=${package%@*}
  test -n "$name" || name=$package
  version=${package#"$name"}
  version=${version#@}
  printf '%s\n' "$installed" | jq -e \
    --arg name "$name" \
    --arg node "$node_version" \
    --arg version "$version" \
    'any(.[]; .name == $name and .platform.node == $node and
      ($version == "" or .version == $version or (.version | startswith($version + "."))))' >/dev/null
}

list_packages() {
  require_brew

  echo "Homebrew formulae"
  brew bundle list --formula --file "$brewfile"

  echo
  echo "Vite+ globals"
  cat "$vite_packages"
}

install_packages() {
  require_brew

  brew bundle install --no-upgrade --file "$brewfile"

  test -x "$VP_HOME/bin/vp" ||
    curl -fsSL --retry 5 https://viteplus.dev/install.sh | VP_NODE_MANAGER=yes VP_PM_MANAGER=yes bash
  vp env setup
  vp env on
  vp env install "$node_version"
  vp env default "$node_version"
  for pm in npm pnpm yarn bun; do vp env default "$pm@latest"; done

  installed=$(vp list -g --json)
  missing=
  while IFS= read -r package; do
    test -n "$package" || continue
    vite_package_installed "$package" || missing="${missing}${package}
"
  done <"$vite_packages"
  test -z "$missing" || printf '%s' "$missing" | xargs vp install -g --node "$node_version"
}

link_dotfiles() {
  git -C "$root" config core.hooksPath .githooks
  git -C "$root" config filter.pi-settings.clean "jq 'del(.deviceId, .lastChangelogVersion)'"
  # Neovim skills are linked below as whole folders, which Codex needs to
  # discover them; Python's bytecode caches stay in the repository.
  stow -R --no-folding \
    --ignore='^\.config/nvim/\.agents/skills(/.*)?$' \
    --ignore='(^|/)__pycache__(/.*)?$' \
    -d "$root" -t "$HOME" home
  # Real parent directories, so other checkouts can link skills beside these.
  mkdir -p "$HOME/.config/nvim/.agents/skills" "$HOME/.codex/skills" "$HOME/.agents/skills" "$HOME/.claude/skills"
  stow -R -d "$root/home/.config/nvim/.agents" -t "$HOME/.config/nvim/.agents/skills" skills
  stow -R -d "$root" -t "$HOME" skills
}

check_packages() {
  failed=0

  if command -v brew >/dev/null 2>&1; then
    brew bundle check --no-upgrade --verbose --file "$brewfile" || failed=1
  else
    echo "missing: Homebrew" >&2
    failed=1
  fi

  if command -v vp >/dev/null 2>&1; then
    vp env list --json | jq -e --arg node "$node_version" \
      'any(.node[]; .version == $node and .default)' >/dev/null || {
      echo "Vite+ default Node runtime is not $node_version" >&2
      failed=1
    }

    installed=$(vp list -g --json)
    while IFS= read -r package; do
      test -n "$package" || continue
      vite_package_installed "$package" || {
        echo "missing or mismatched Vite+ global on Node $node_version: $package" >&2
        failed=1
      }
    done <"$vite_packages"
  else
    echo "missing: Vite+" >&2
    failed=1
  fi

  test "$failed" -eq 0 || return 1
  echo "package checks passed"
}

case "${1:-}" in
  list) list_packages ;;
  install) install_packages ;;
  link) link_dotfiles ;;
  check) check_packages ;;
  *) usage ;;
esac
