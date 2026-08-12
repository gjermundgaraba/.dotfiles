# Public repository safety

- Treat this repository and its full Git history as public.
- Track only durable configuration intended to be shared across machines.
- Keep credentials, tokens, authentication databases, private infrastructure, internal repository paths, machine identifiers, sessions, caches, logs, and generated state in ignored machine-local files.
- For stateful tools, ignore the application directory by default and explicitly allow only reviewed configuration files.
- Before tracking a new file, inspect its contents and neighboring files for sensitive data. If unsure, leave it ignored and ask.
- Never bypass `.gitignore` with `git add -f`, bypass checks with `--no-verify`, or weaken a protective ignore rule without explicit approval.
- Before every commit, inspect `git diff --cached` and run the configured Gitleaks check.
- Do not commit or push without explicit user approval.
