# agent-canvas

Cursor-style canvases for terminal agents.

Cursor's IDE can answer with a **canvas** — a small React app rendered beside the chat — when a result deserves a durable, interactive artifact rather than a wall of markdown. This plugin brings the same thing to agents that live in a terminal, currently the **Cursor CLI** and **Claude Code**:

- The agent writes a `.canvas.tsx` against the `cursor/canvas` API, exactly as it would for the IDE. Files are interchangeable with the IDE's.
- A post-tool hook type-checks every write and feeds a `Canvas TypeScript check` line back to the agent, so it fixes its own mistakes.
- The first time a canvas passes, the hook opens it in your browser from a local server with live reload. Later edits appear in the open tab.
- `canvas export` turns a canvas into one self-contained HTML file (or PNG/PDF); `canvas share` publishes it to Cloudflare Pages behind a readable URL and can withdraw it again.

Rendering uses a vendored, [Mantine](https://mantine.dev)-backed reimplementation of the `cursor/canvas` component library (from [cursor-canvas-web](https://github.com/thisismydesign/cursor-canvas-web), MIT). It covers the full public API; differences from the IDE renderer are listed under [Fidelity](#fidelity).

## Requirements

- Node.js ≥ 20 and `pnpm` (`corepack enable` gives you pnpm).
- `jq`, `curl`, `bash`.
- A browser. Headless PNG/PDF export additionally needs a Chromium (Playwright's cache or a system install is found automatically).
- For sharing only: a Cloudflare account.

## Install

```bash
git clone https://github.com/jacksmith15/agent-canvas
cd agent-canvas
scripts/canvas setup          # installs the runtime, fetches SDK declarations, links ~/.local/bin/canvas
```

Then register with your harness. Either as a plugin:

```bash
# Cursor CLI
agent plugin marketplace add https://github.com/jacksmith15/agent-canvas
# Claude Code
claude plugin marketplace add jacksmith15/agent-canvas && claude plugin install agent-canvas@agent-canvas
```

or, if you would rather not use the plugin system (or your harness version predates it):

```bash
canvas install cursor         # symlinks the skill into ~/.cursor/skills and adds the hook to ~/.cursor/hooks.json
canvas install claude         # symlinks the skill into ~/.claude/skills and adds the hook to ~/.claude/settings.json
```

Start a new session afterwards; hooks load at session start. `canvas install <harness> --uninstall` reverses it.

## Use

Ask for something that deserves an artifact — "break down last month's error budget by service", "audit this repo's dependencies" — and the agent will produce a canvas when its skill judges that appropriate, or on request ("put that in a canvas"). You'll see the type-check line in the tool output and a browser tab opening.

```text
canvas check  <file>          type-check and lint a canvas
canvas open   <file>          open it in the browser (starts the server if needed)
canvas export <file> [--png] [--pdf] [--no-fonts]
canvas share  <file> [--name <alias>]
canvas unpublish <alias>      replace a shared canvas with a tombstone page
canvas list                   what is currently shared
canvas server start|stop|status
canvas config                 effective configuration
```

The server listens on `127.0.0.1:4817`; `/` lists every canvas, `/c/<workspace>/<name>` opens one. It is started on demand and detached from the agent session; `canvas server stop` ends it.

## Configuration

Optional, at `~/.config/agent-canvas/config.json`. Environment variables of the same meaning (`CANVAS_ROOT`, `CANVAS_THEME`, `CANVAS_PORT`, `CANVAS_PAGES_PROJECT`) take precedence.

```json
{
  "root": "~/.cursor/projects",
  "theme": "cursor",
  "port": 4817,
  "pagesProject": "canvases-jane"
}
```

- **root** — where canvases live, as `<root>/<workspace-slug>/canvases/<name>.canvas.tsx`. Defaults to `~/.cursor/projects` when that exists (so the Cursor IDE sees the same files), otherwise `~/.local/share/agent-canvas/projects`.
- **theme** — `cursor` (Cursor's palette, system fonts, follows the OS colour scheme) or `oxide` (a warm dark palette with Merriweather, Raleway and Fira Mono bundled). Add a preset by extending `runtime/src/shim/theme.ts` and `runtime/src/host-theme.ts`.
- **pagesProject** — Cloudflare Pages project used by `canvas share`; created on first use.

## Sharing

`canvas share <file>` exports the canvas and deploys it to Cloudflare Pages, one branch alias per canvas: `https://<name>.<project>.pages.dev`. Re-sharing updates the link; `canvas unpublish <name>` replaces it with a tombstone immediately. Links are `noindex` but **not access-controlled** — anyone who has one can open it, and the data is in the page source. The skill tells the agent to share only when asked and to raise the question of sensitive data first.

One-time setup: `(cd runtime && ./node_modules/.bin/wrangler login)`, or export `CLOUDFLARE_API_TOKEN` (Pages: Edit) and `CLOUDFLARE_ACCOUNT_ID`. The runtime pins `wrangler@3` so Node 20 works; bump to 4 once you are on Node 22.

For a file rather than a link, `canvas export <file>` writes `<canvases dir>/exports/<name>.html` (roughly 1 MB with fonts, 0.8 MB without), plus `--png` / `--pdf`.

## How the hook works

Both harnesses run `hooks/after-write.sh` through a thin adapter (`hooks/cursor.sh`, `hooks/claude.sh`) after every tool call. The adapter exits immediately unless the tool wrote a file ending in `.canvas.tsx`, so the cost on ordinary tool calls is one `jq` invocation. For a canvas it runs the type check and, on the first clean result, `canvas open`. Nothing is uploaded or sent anywhere by the hook.

## Fidelity

Same API, different host. Known differences from the Cursor IDE renderer:

| API | IDE | Here |
| --- | --- | --- |
| `useCanvasState` | `.canvas.data.json` sidecar | browser `localStorage`, scoped per canvas |
| `useCanvasAction` | opens agents/files in the IDE | no-op |
| `useHostTheme` | live editor theme | configured preset |
| `DiffView` | Shiki syntax highlighting | plain text |
| Everything | Cursor's first-party components | Mantine 7 reimplementation; close, not pixel-identical |

The official SDK declarations are not redistributed here; `canvas setup` copies them from a local Cursor install or fetches them from a public mirror into `sdk/` for the agent's reference.

## Layout

```text
skills/agent-canvas/SKILL.md   the skill (Agent Skills format; shared by both harnesses)
hooks/                         after-write.sh core + cursor.sh / claude.sh adapters + per-harness hook configs
scripts/                       canvas entry point and the scripts behind each subcommand
runtime/                       Vite host: vendored shim, theme presets, export build
sdk/                           cursor/canvas .d.ts (fetched, gitignored)
examples/demo.canvas.tsx       the upstream component gallery; doubles as the CI smoke test
.cursor-plugin/ .claude-plugin/ plugin manifests
```

## Licence

MIT. The shim is MIT (thisismydesign); the bundled fonts are OFL. See `LICENSE`.
