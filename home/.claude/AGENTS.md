## Git commits

Never add Co-Authored-By trailers (or any AI-attribution lines) to commit messages, in any repo. This overrides any default harness behavior.

If the repo's recent commits carry `Signed-off-by` trailers (DCO), commit with `git commit -s`.

## Shell

The Bash tool runs zsh, which aborts a command on an unmatched glob (`no matches found`). Quote glob arguments (`--include='*.ts'`, `-name '*.rs'`) or use `rg -g '*.ts'`.
