# nvim

Personal Neovim configuration.

## LSP servers

This config enables the following language servers (see `lua/config/lsp.lua`). Each must be installed and available on `$PATH`.

| Server | Binary | Language(s) |
| --- | --- | --- |
| `lua_ls` | `lua-language-server` | Lua |
| `ts_ls` | `tsc` 7+ | JavaScript / TypeScript |
| `jsonls` | `vscode-json-language-server` | JSON / JSONC |
| `gopls` | `gopls` | Go |
| `gh_actions_ls` | `gh-actions-language-server` | GitHub Actions YAML |
| `solidity_ls` | `vscode-solidity-server` | Solidity |

### Install

The repository bootstrap installs these dependencies. The methods below are alternatives for using this Neovim configuration independently.

#### `lua_ls` — Lua

| Method | Command |
|--------|---------|
| Homebrew | `brew install lua-language-server` |
| GitHub releases | <https://github.com/LuaLS/lua-language-server/releases> |

#### `ts_ls` — JavaScript / TypeScript

This configuration uses TypeScript 7's native LSP mode.

| Method | Command |
|--------|---------|
| Homebrew | `brew install typescript` |
| npm | `npm install -g typescript` |

#### `jsonls` — JSON / JSONC

| Method | Command |
|--------|---------|
| Homebrew | `brew install vscode-langservers-extracted` |
| npm | `npm install -g vscode-langservers-extracted` |

Note: `vscode-langservers-extracted` bundles HTML, CSS, JSON, and ESLint language servers.

#### `gopls` — Go

| Method | Command |
|--------|---------|
| Homebrew | `brew install gopls` |
| go install | `go install golang.org/x/tools/gopls@latest` |

#### `gh_actions_ls` — GitHub Actions YAML

| Method | Command |
|--------|---------|
| npm | `npm install -g gh-actions-language-server` |

#### `solidity_ls` — Solidity

| Method | Command |
|--------|---------|
| npm | `npm install -g vscode-solidity-server` |

You may also want `solc` installed (e.g. `npm install -g solc` or `brew install solc`) for compilation features.
