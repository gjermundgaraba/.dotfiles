# AGENT GUIDE: Ghostty Config

My config is at ./config

## Documentation
- Verify all configuration changes (keys and values) with the docs at https://ghostty.org/docs

## Build, Lint & Test
- No build, lint or test - the user needs to verify that config changes work as expected

## Code Style
- Keep entries `key = value` with single spaces around equals.
- Add new options near related options.
- Avoid trailing whitespace; align multi-line blocks for readability.
- Validate fonts/themes against installed assets before making changes related to those.
- Prefer explicit numeric values.
- Remove deprecated keys instead of commenting them out.
- Code carries no comments except legal headers, foreign/platform gotchas we cannot change, public-API docs, issue/RFC links, and lint-required directives; express intent through names and types.
- Favor descriptive command invocations; ensure shell commands are login-shell safe.
