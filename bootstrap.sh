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

usage() {
  echo "usage: $0 <list|install|check>" >&2
  exit 2
}

require_brew() {
  command -v brew >/dev/null 2>&1 || {
    echo "install Homebrew from https://brew.sh, then rerun this command" >&2
    exit 1
  }
}

find_vp() {
  if command -v vp >/dev/null 2>&1; then
    command -v vp
  elif command -v brew >/dev/null 2>&1; then
    candidate="$(brew --prefix)/bin/vp"
    test -x "$candidate" && printf '%s\n' "$candidate"
  else
    return 1
  fi
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
  case "$(uname -s)/$(uname -m)" in
    Darwin/arm64 | Linux/x86_64) ;;
    *)
      echo "bootstrap supports macOS on Apple Silicon and Linux on x86_64 only" >&2
      exit 1
      ;;
  esac
  require_brew

  brew bundle install --no-upgrade --file "$brewfile"

  vp=$(find_vp) || {
    echo "missing: Vite+" >&2
    exit 1
  }
  "$vp" env setup
  "$vp" env on
  "$vp" env install "$node_version"
  "$vp" env default "$node_version"

  installed=$("$vp" list -g --json)
  missing=
  while IFS= read -r package; do
    test -n "$package" || continue
    vite_package_installed "$package" || missing="${missing}${package}
"
  done <"$vite_packages"
  test -z "$missing" || printf '%s' "$missing" | xargs "$vp" install -g --node "$node_version"
}

check_packages() {
  failed=0

  if command -v brew >/dev/null 2>&1; then
    brew bundle check --no-upgrade --verbose --file "$brewfile" || failed=1
  else
    echo "missing: Homebrew" >&2
    failed=1
  fi

  if vp=$(find_vp); then
    runtimes=$("$vp" env list --json)
    printf '%s\n' "$runtimes" | jq -e --arg node "$node_version" \
      'any(.node[]; .version == $node)' >/dev/null || {
      echo "missing Vite+ Node runtime: $node_version" >&2
      failed=1
    }

    printf '%s\n' "$runtimes" | jq -e --arg node "$node_version" \
      'any(.node[]; .version == $node and .default)' >/dev/null || {
      echo "wrong Vite+ default Node runtime" >&2
      failed=1
    }

    installed=$("$vp" list -g --json)
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
  check) check_packages ;;
  *) usage ;;
esac
