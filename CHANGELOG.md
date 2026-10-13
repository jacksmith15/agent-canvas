# Changelog

## 0.2.1

- Sharing reports the concrete URL. Cloudflare assigns a suffixed project host (e.g. `canvases-jane-17n.pages.dev`) when `<project>.pages.dev` is already taken by another account; the published and unpublished URLs are now read from wrangler's deploy output instead of being composed from the project name, and `canvas unpublish` accepts any `*.pages.dev` URL.

## 0.2.0

- Self-installing plugin. A session-start hook (`hooks/ensure-installed.sh`) installs the runtime into `~/.local/share/agent-canvas/tool` on first use and re-syncs it when the plugin version changes, so `claude plugin install` / `agent plugin marketplace add` is the whole install; no clone needed. The post-write hook bootstraps too, in case a first canvas lands before session start finishes. A developer checkout set up with `scripts/canvas setup` is left alone and takes precedence.
- `setup.sh --into <dir>` syncs a checkout into a target before installing there; falls back through `pnpm`, `corepack pnpm`, `npx pnpm`, `npm`.
- Tool-home resolution prefers candidates whose runtime is actually installed, so a bare plugin cache is never mistaken for the tool.

## 0.1.1

- Fix plugin-manager installs. Plugin managers copy the repository into a cache without installing the runtime, so hooks running from that copy failed with "runtime dependencies are missing". Scripts and hooks now resolve the installed tool (`CANVAS_HOME`) via the environment, the `home` key `canvas setup` records in `~/.config/agent-canvas/config.json`, or the `canvas` command on `PATH`, instead of assuming it is beside them.
- Skill no longer describes the tool as living "two levels above `SKILL.md`"; it points at `canvas config`'s `home`.
- `canvas config` labels `home` as the installed tool directory.

## 0.1.0

Initial release.

- Skill (`skills/agent-canvas`) adapted from Cursor's built-in canvas skill for terminal agents.
- Local runtime: Vite dev server rendering `.canvas.tsx` files through a vendored, Mantine-backed implementation of the `cursor/canvas` API, with live reload, short `/c/<workspace>/<name>` URLs and an index page.
- `canvas check`: `tsc` plus the skill's file rules; surfaced automatically after every write by a post-tool hook (Cursor CLI `postToolUse`, Claude Code `PostToolUse`), which also opens each canvas in the browser the first time it passes.
- `canvas export`: single-file HTML (fonts inlined), PNG and PDF.
- `canvas share` / `publish` / `unpublish` / `list`: Cloudflare Pages publishing with per-canvas aliases and immediate tombstone revocation.
- Theme presets: `cursor` (default) and `oxide`; configurable canvas root, port and Pages project via `~/.config/agent-canvas/config.json`.
- Plugin manifests for the Cursor CLI and Claude Code, plus `canvas install cursor|claude` for installs without the plugin system.
