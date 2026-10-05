---
name: update-neovim-plugins
description: Review and safely update Neovim plugin dependencies managed by the built-in vim.pack API, including moving branches, semantic-version ranges, and exact tag or commit pins. Use when asked to check, report, upgrade, refresh, or update plugins or nvim-pack-lock.json in a Neovim configuration.
disable-model-invocation: true
---

# Update Neovim Plugins

Follow a report-first workflow. Do not change plugin checkouts, specs, or the lockfile before approval.

## 1. Verify the local setup

- Read the repository instructions and every `vim.pack.add()` call.
- Check `nvim --version`, the installed `:help vim.pack`, and the lockfile documented by `:help vim.pack-lockfile`. Prefer installed help over newer website syntax.
- Confirm the config uses `vim.pack`; otherwise stop and use the actual package manager's workflow.
- Check version-control status. Before mutation, require a reversible baseline. If none exists, stop after the report and ask the user to initialize version control or approve a backup; do not do either implicitly.

## 2. Inventory every dependency

Record each plugin's name, source, version expression, and locked revision. Treat the Lua spec as authoritative and the lockfile as generated state.

Classify versions by checking upstream refs instead of guessing from their spelling:

- A verified branch such as `main` is moving.
- A `vim.version.range(...)` value moves to the newest matching stable tag.
- A verified tag such as `v2.15.0` or a commit hash is an exact pin.

Do not mistake a string such as `v3.x` for a semantic range; it may be a branch. Never edit `nvim-pack-lock.json` by hand.

## 3. Research without mutation

- Query remote refs, releases, changelogs, and comparisons without running `vim.pack.update()` or modifying local plugin repositories.
- For moving versions, compare the locked revision with the current matching upstream revision.
- For every exact pin, find the latest stable release, compare it with the pinned release, and propose a new exact tag. Preserve exact pinning unless the user requests another policy.
- Report breaking changes, useful changes, required config edits, and missing upstream release notes. Ignore prereleases unless requested or already pinned.

Present one initial table: `Plugin | Current | Candidate | Constraint | Risk/config change | Sources`. End with `No changes made` and ask approval for explicit plugin targets and config edits.

## 4. Apply only the approved update

Edit exact pins and any approved compatibility changes in the Lua specs first. Preserve unrelated work and leave the lockfile to `vim.pack`.

For all approved plugins, run:

```sh
nvim --headless \
  '+lua vim.pack.update(nil, { force = true })' \
  '+qa'
```

For a subset, pass only approved plugin names instead of `nil`. Use the Lua API after verifying its installed signature; a custom interactive `:PackUpdate` command is not an automation substitute. Check the exit status and review only the intended spec, config, and lockfile diffs.

## 5. Verify and report

Run:

```sh
nvim --headless '+qa'
```

Run any small, relevant config check revealed by upstream migration notes. Report exact pins changed, locked revisions changed, config edits, and verification results. On failure, state the command, cause, and current diff; do not claim success, hand-edit the lockfile, or discard user changes.
