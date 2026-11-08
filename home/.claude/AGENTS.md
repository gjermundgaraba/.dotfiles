Always build code cleanly, modularly, and with proper architecture and separation of concerns. Never simply bolt on a feature because I asked for it. If you can’t find an easy way to build it naturally, and you'd recommend a refactor to make the whole thing cleanly, stop your work ahead of time and say so.

## Git commits

If the repo's recent commits carry `Signed-off-by` trailers (DCO), commit with `git commit -s`.

## Shell

The Bash tool runs zsh, which aborts a command on an unmatched glob (`no matches found`). Quote glob arguments (`--include='*.ts'`, `-name '*.rs'`) or use `rg -g '*.ts'`.
