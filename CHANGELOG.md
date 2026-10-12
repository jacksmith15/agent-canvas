# Changelog

## 0.1.0

Initial release.

- Skill (`skills/agent-canvas`) adapted from Cursor's built-in canvas skill for terminal agents.
- Local runtime: Vite dev server rendering `.canvas.tsx` files through a vendored, Mantine-backed implementation of the `cursor/canvas` API, with live reload, short `/c/<workspace>/<name>` URLs and an index page.
- `canvas check`: `tsc` plus the skill's file rules; surfaced automatically after every write by a post-tool hook (Cursor CLI `postToolUse`, Claude Code `PostToolUse`), which also opens each canvas in the browser the first time it passes.
- `canvas export`: single-file HTML (fonts inlined), PNG and PDF.
- `canvas share` / `publish` / `unpublish` / `list`: Cloudflare Pages publishing with per-canvas aliases and immediate tombstone revocation.
- Theme presets: `cursor` (default) and `oxide`; configurable canvas root, port and Pages project via `~/.config/agent-canvas/config.json`.
- Plugin manifests for the Cursor CLI and Claude Code, plus `canvas install cursor|claude` for installs without the plugin system.
