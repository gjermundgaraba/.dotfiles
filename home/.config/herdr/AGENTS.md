# Herdr

Before helping with Herdr, read the [Herdr agent guide](https://herdr.dev/agent-guide.md).
Use the [official documentation](https://herdr.dev/docs/) to verify commands, configuration, and troubleshooting details.
When implementation details are needed, run `herdr --version` and `herdr status`. The local fork is at `~/ws/pers/forks/herdr`; consult its source and uncommitted changes for fork-specific behavior, without resetting or modifying that working tree.
The installed binary is a patched build of that fork. `herdr update` would replace it with an upstream release, so `[update] version_check = false` silences the update notice; do not run `herdr update`.
For upstream references, use a reusable, read-only checkout of `herdrdev/herdr` at `~/.cache/checkouts/github.com/herdrdev/herdr`, checking out the matching `v<version>` tag. Clone it there if absent; never edit the shared checkout.

For keymap suggestions, inspect `./config.toml` and account for the Norwegian keyboard.
