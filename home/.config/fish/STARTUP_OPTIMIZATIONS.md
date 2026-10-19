# Fish startup optimizations

This configuration favors synchronous correctness for environment managers and
caches only generated Fish source that is stable between tool upgrades.

## Changes made

### Removed repeated work

1. Removed duplicate mise and direnv initialization. Homebrew already installs
   vendor hooks for both; direnv had been initialized three times and mise
   twice.
2. Replaced `brew shellenv fish | source` with its static environment and path
   operations for `/opt/homebrew` (macOS) or `/home/linuxbrew/.linuxbrew`
   (Linux), avoiding a ~27 ms `brew` process. They live in
   `conf.d/00-homebrew.fish` so Homebrew tools are on `PATH` before the other
   `conf.d` files run.
3. Replaced `fzf --fish | source` with Homebrew's packaged
   `key-bindings.fish`. The generated Shift-Tab completion was redundant with
   the custom `accept-autosuggestion` binding.
4. Removed the separate `atuin ai init fish` call because Atuin's main
   initializer already defines the AI function and `?` binding.

### Cached generated initializers

`functions/__cached_source.fish` stores generated Fish source in
`/tmp/fish-init-cache-$USER` and sources it on later shell starts.

| Tool | Cached output | Work that remains dynamic |
|---|---|---|
| Carapace | Completion registrations | Completion queries when Tab is used |
| Atuin | Functions, bindings, and event hooks | Per-shell Atuin session UUID |
| Zoxide | Functions and `PWD` hook | Directory database updates |
| direnv | Fish event hooks | `direnv export` environment evaluation |

`conf.d/direnv.fish` intentionally uses the same basename as Homebrew's vendor
file. Fish gives user `conf.d` files precedence, so it replaces rather than
duplicates the vendor hook.

mise is activated by Homebrew's vendor hook, uncached. Only Homebrew's fish
reads that hook, so use it as the login shell on Linux too. Do not cache
`mise activate fish`: its output embeds the generating process's PATH, and
replaying it drops PATH entries added since. Vite+ owns the JavaScript toolchain
(see `~/.config/mise/config.toml`) and is sourced in `config.fish`.

## Cache invalidation and safety

The cache refreshes when:

1. The cache is missing or empty.
2. The resolved generator binary changes or becomes newer than the cache.
3. Generator arguments change.
4. A declared dependency changes or appears/disappears. Atuin declares its
   config and installer receipt, so both config edits and upgrades refresh it.
5. The internal cache schema is bumped.

Refreshes are written to a temporary file, checked with `fish -n`, and moved
into place atomically. A failed refresh retains the previous valid cache.

The cache directory is private (`0700`) and rejected if it is a symlink or is
owned by another user. macOS and Ubuntu normally clear `/tmp` during reboot, so the first
shell after a restart regenerates the files. Dependency checks still preserve
correctness if `/tmp` survives.

## Why these are not asynchronous

Atuin, Zoxide, mise, and direnv install functions, event handlers, or
environment variables in the current Fish process. A background process cannot
modify its parent shell. Caching removes repetitive code generation while
keeping required initialization synchronous.

## Deliberately left alone

1. mise `hook-env`: roughly 12–16 ms and required for project tools and env.
2. Atuin session UUID: roughly 9 ms and required for history session tracking.
3. Vite+ completion: roughly 7–10 ms; changing it would duplicate
   installer-owned shell logic for a small gain.

## Maintenance

Run the cache self-check:

```fish
fish functions/__cached_source.fish --self-test
```

Clear and regenerate all cached initializers:

```fish
rm -rf /tmp/fish-init-cache-$USER
exec fish
```

Profile startup:

```fish
fish --profile-startup /tmp/fish-startup.prof -ic exit
sort -nrk2 /tmp/fish-startup.prof | head -n 30
```
