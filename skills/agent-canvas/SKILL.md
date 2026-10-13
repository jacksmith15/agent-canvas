---
name: agent-canvas
description: >-
  A canvas is a live React app the user opens beside the chat; in a terminal
  agent (Cursor CLI, Claude Code) it is rendered in the browser by a local
  runtime bundled with this skill. You MUST use a canvas when the agent
  produces a durable standalone artifact outside the transcript that the user
  may revisit, refine, or share — reports, dashboards, documents, data-heavy
  investigations, or repeatable tools. Especially prefer a canvas when
  presenting results from MCP tools (Datadog, Databricks, Linear, Sentry,
  Slack, etc.) where a durable artifact is the deliverable — render it in a
  rich canvas rather than dumping it into a large markdown table or code block.
  Do not use a canvas for an immutable visual output that belongs inside the
  transcript. You MUST also read this skill whenever you create, edit, or debug
  any .canvas.tsx file. Inside the Cursor IDE the built-in canvas skill takes
  precedence over this one.
---
A canvas is a single `.canvas.tsx` file written against the `cursor/canvas` API. In the Cursor IDE, Cursor compiles and displays it in a side panel; here, the runtime bundled with this plugin serves it to the browser with live reload. The file format is identical, so canvases written here also open in a current Cursor IDE. Follow the workflow below in order.

**The `canvas` command.** Every operation below goes through one command, `canvas`. The plugin's session-start hook installs the tool on first use and links `~/.local/bin/canvas`; if `canvas` is not on `PATH`, read `home` from `~/.config/agent-canvas/config.json` and run `<home>/scripts/canvas`. `canvas config` prints `home` — the directory where the tool is installed (`runtime/`, `scripts/`, `sdk/`) — which is not where this `SKILL.md` was loaded from; plugin managers keep the skill in their own cache. `canvas --help` lists the subcommands.

## Workflow

### 1. Decide whether to use a canvas

The trigger is **user intent**, not response shape. Ask: would the user benefit from viewing this output as its **own durable standalone artifact outside the transcript**, separate from the chat? If the output is a means to an end (a drafted message, a code fix, a dashboard in another tool), skip the canvas.

**Use a canvas when the agent produces new standalone analytical output:**
- Quantitative analyses and metrics breakdowns (e.g. "send 500 requests and tell me how many fail")
- Billing or account investigations that surface structured findings from database queries
- Security audits or architecture reviews with categorized findings
- Cross-system data analyses and overlap reports
- Structured data from MCP tools (Databricks, Datadog, etc.) where a durable standalone artifact is the deliverable
- Financial analyses, margin decompositions, usage trend reports
- Large tables the user wants to revisit or refine

**Do NOT use a canvas when:**
- The user asks for work in a **specific tool** — "create a Datadog dashboard" means give them a Datadog dashboard, not a canvas
- The user has a **specific deliverable** — "draft a support response", "fix this code", "make this PR"
- The user is **working within an existing artifact** — improving an HTML dashboard, editing an existing file
- The user is doing **targeted debugging** or active development, even if structured findings emerge along the way
- An immutable visual output belongs inside the transcript rather than in a durable standalone artifact
- Short factual answers, one-off file edits, or quick clarifying questions
- MCP tools are queried as an **intermediate step** for a different deliverable (e.g. querying Stripe to draft a support reply)

### 2. Write the canvas

**Location.** Canvases live at `<root>/<workspace>/canvases/<name>.canvas.tsx`, where `<root>` is the configured canvas root (`~/.cursor/projects` when it exists, so canvases land where the Cursor IDE also looks) and `<workspace>` is the workspace's absolute path with the leading `/` removed and every `/` replaced by `-` (for example `/home/jane/scraps` → `home-jane-scraps`). Rather than computing this, ask for it: `canvas path <name>` prints the exact file path for the current working directory. Under the Cursor CLI the "Terminals folder" path in your environment is `<root>/<workspace>/terminals`, so its parent is also a reliable answer. Write the file with the write tool directly at that path; the write tool creates the `canvases/` directory if needed, so do not spend turns on `mkdir` or existence checks. Use a descriptive kebab-case filename ending in `.canvas.tsx`; preserve acronym capitalization and lowercase the rest.

**File rules:**
- Exactly one `.canvas.tsx` file per canvas. Never create helper files, style files, or supporting modules.
- Import **only** from `cursor/canvas`. No relative imports, no npm packages, no Node built-ins, no direct `react` import — `cursor/canvas` re-exports `useState`, `useEffect`, `useMemo`, `useRef`, `CSSProperties`, and `RefObject`.
- Default-export the top-level component.
- Embed all data inline. **No `fetch()`, no network calls.**

**Never render empty states.** A canvas exists to show real content. If a section, chart, table, or component has no data to display, **omit it** — do not render it with placeholder text ("Add header here", "TODO", "Example"), a "No data" message, an empty array, zeroed rows, or an empty chart frame. If the entire canvas would be empty because you don't have the underlying data, do not produce a canvas — tell the user what's missing and ask for it instead.

**Label every plot.** Charts and tables must be self-describing — a reader looking at the canvas alone should know exactly what they're seeing. For every plot include:
- A title naming the **specific metric** (not "Metrics" — "API error rate by service").
- **Axis labels with units** on both axes (e.g. "Date", "Latency (ms)").
- A **legend** when more than one series is shown, with the exact series names from the source data.
- The **source and time range** in a small caption (e.g. "Source: Datadog · last 7 days"). If a value is a transformation (mean, p95, normalized, smoothed), say so in the label.

**Component discovery:** prefer built-in `cursor/canvas` components over hand-rolled markup. The public surface (components, hooks, prop types, tokens) is declared in `<home>/sdk/index.d.ts` and its sibling `.d.ts` files, where `<home>` is the installed tool directory from `canvas config` — read them when you need exact exports, prop shapes, or hook signatures rather than guessing. If `sdk/` holds only a README, the declarations were not fetched; `canvas setup` populates it, and until then `<home>/runtime/src/shim/cursor-canvas.tsx` lists every export. Referencing an export that does not exist is the most common error. The type check in step 3 is the final authority: it runs against the renderer actually used here, so if it rejects an export, that export is not available regardless of what the declarations say.

**Host-specific behaviour** (same API, different host):
- Colours come from the host's configured theme preset, which the user may have changed; `useHostTheme()` tokens, `tone` props and the category `Color` names all resolve to it, which is one more reason never to hardcode colours. `?theme=light|dark` on the canvas URL overrides the scheme.
- `useCanvasState` persists to the browser's local storage, scoped per canvas file, rather than to a `.canvas.data.json` sidecar. State survives reloads and server restarts but is per-browser.
- `useCanvasAction` is a no-op: there is no IDE to receive `openAgent`, `newComposerChat`, or `openFile`. Do not build UI that depends on it.
- `DiffView` renders plain text without syntax highlighting.

Apply the Design guidance below as you write, and complete its Pre-delivery self-check before returning the canvas.

### 3. Check the canvas

Every write or edit of a `.canvas.tsx` file is followed automatically by a `Canvas TypeScript check` line in the tool result (a post-tool hook runs `tsc` plus the file rules above). Treat it as the authoritative diagnostics signal and fix every reported error before moving on. If the line does not appear (hook not installed, or the file was produced via the shell), run the check yourself:

```bash
canvas check <absolute path to .canvas.tsx>
```

### 4. Surface the canvas

The hook surfaces the canvas for you. The **first time** a canvas passes the check, the hook starts the local canvas server if needed, opens the canvas in the user's default browser when a graphical session is available, and appends one of these to the tool result:

- `Opened canvas in browser: <url>` — the user is already looking at it.
- `Canvas URL (open in a browser): <url>` — no display was available (e.g. SSH); the user must open the URL themselves, so make it prominent in your reply.

On every later clean check the result carries `Canvas URL: <url>` only; the open tab updates live as you edit, so nothing needs re-opening. Do not run any command to open a canvas in the normal flow. Run `canvas open` only when no URL appeared after a clean check (hook not installed), or when the user explicitly asks you to open or re-open a canvas:

```bash
canvas open <absolute path to .canvas.tsx>
```

URLs take the form `http://127.0.0.1:<port>/c/<workspace>/<name>` (port 4817 unless configured); the server root lists every canvas on disk.

### 5. Sharing (only when asked)

The local URL works only on this machine. When the user asks to share, send, or publish a canvas — and **only** then; never share as part of creating one — run:

```bash
canvas share <absolute path to .canvas.tsx>
```

It exports the canvas to one self-contained HTML file (`<canvases dir>/exports/<name>.html`) and deploys it to **Cloudflare Pages**, printing a stable link of the form `https://<name>.<project>.pages.dev`. Put the `Published:` URL in your reply as the link, and always state the two facts the script prints: anyone who has the link can open it (not indexed, but not access controlled, and the embedded data is in the page source); and it can be withdrawn immediately with `canvas unpublish <name>`. Re-sharing the same canvas updates the same link. If the canvas holds data the user may not want outside the team (customer records, billing, credentials, internal metrics), say so before running the command rather than after.

Flags: `--name <alias>` chooses the subdomain; `--no-fonts` drops bundled typefaces for a smaller file. For a file rather than a link — a Slack attachment, a ticket — use `canvas export <canvas> [--png] [--pdf]` instead, which exports without publishing. `canvas list` shows what is currently published.

## Design guidance

Be creative. The SDK gives you expressive building blocks — use them in whatever combination best serves the content. But avoid slop: no gradients, no emojis, no box-shadows, no rainbow coloring. Cursor canvases are flat, minimal, and purposeful.

### Visual hierarchy

Not everything deserves equal treatment. Primary content gets more space, larger headings, and accent color. Supporting content stays compact. Squint test: blur your eyes — can you tell what matters?

**Color.** All colors from `useHostTheme()` tokens — read its JSDoc in `sdk/hooks.d.ts` for the return shape and usage pattern. No hardcoded hex. Use accent color deliberately, not on everything.

### Slop patterns — forbidden

These specific patterns produce low-quality output. If 2+ are present, redesign.

- **Gradients** — no `linear-gradient`, `radial-gradient`, `background-clip: text`.
- **Emojis** — no emoji as icons, status indicators, bullets, or section markers.
- **Box shadows** — no `box-shadow`. Flat surfaces only.
- **Wall of identical cards** — every section wrapped in the same card style with no variation. Mix open sections with cards.
- **Rainbow coloring** — a different color on every element. Most elements are neutral; color is used sparingly with purpose.
- **Giant text** — font sizes above H1 (24px), or bold text stuffed in CardHeader.
- **Decorative borders** — colored borders on every element. Borders are structural (subtle stroke tokens), not decorative.

### Pre-delivery self-check

Before returning canvas code, verify:
1. Does the layout have visual hierarchy? One thing should stand out.
2. Is there variety in the composition? Not just a single column of uniform blocks.
3. Slop check: scan for the forbidden patterns above.

## Introducing the canvas

Whenever you mention a canvas to the user — one you created, updated, or want them to open — **always** include a markdown link using the URL reported in the tool result (for example, `[Billing Review](http://127.0.0.1:4817/c/home-jack-scraps/billing-review)`), followed by the file's absolute path in backticks so the user can find the source. Use a short descriptive label as the link text; do not refer to a canvas by name or path alone without the link.

When you create a canvas, add a short note in your chat response with that link:

- **First canvas** — if no other `.canvas.tsx` files exist in the workspace's `canvases/` directory, include one sentence explaining what a canvas is and that it opened in the browser (or, if the hook reported no display, that they need to open the URL).
- **Unsolicited canvas** — if the user didn't ask for a canvas, include one sentence explaining why you chose it over plain text.

Both can apply at once; one or two sentences total is enough. Skip the intro for subsequent canvases unless you are mentioning that canvas again (still link it).

## Troubleshooting

Paths below are relative to the installed tool directory, printed by `canvas config` as `home`.

- **Canvas page is blank or shows an error panel.** The browser reports runtime errors to `runtime/.canvas-errors.log`; read its tail. The error panel on the page shows the same stack trace.
- **Type check reports an export that the official declarations list.** The renderer is a reimplementation of the SDK (vendored in `runtime/src/shim/`) and may lag it. Use an alternative component; the check output is correct for this host.
- **`canvas open` fails to start the server.** Read `runtime/.server.log`. Check `canvas server status`; `canvas server stop` then `start` recovers from a stale process. The port is `4817` unless configured.
- **"runtime is not installed at …".** The session-start hook that installs the tool did not run (plugin installed mid-session) or failed (no Node, no network). Run `<plugin root>/hooks/ensure-installed.sh` to install it now and see any error; a new session also triggers it. The tool is installed to `~/.local/share/agent-canvas/tool`, never into the plugin cache.
- **Sharing fails with "not logged in to Cloudflare".** Sharing needs a one-time `wrangler login` (the command prints the exact invocation) or `CLOUDFLARE_API_TOKEN` in the environment, plus `jq`. The Pages project (`canvases-<user>` by default) is created automatically on first use; if that name is taken, set `pagesProject` in the config file or `CANVAS_PAGES_PROJECT` in the environment.
- **Shared link gives a TLS error or shows stale content.** Right after the project is first created, Cloudflare takes a few minutes to issue the `*.<project>.pages.dev` certificate; links fail to connect until then. After any publish or unpublish the alias can take up to a minute to switch. Both resolve on their own; tell the user to retry shortly rather than re-running.
- **No `Canvas TypeScript check` line after edits.** The post-tool hook is not loaded: the plugin was installed mid-session (hooks load at session start), or it was never registered (`canvas install cursor` / `canvas install claude` registers it without the plugin system). Run `canvas check` and `canvas open` manually in the meantime.
- **Canvas did not auto-open although the check passed.** The hook opens each canvas once; it remembers which it has surfaced in `runtime/.opened-canvases`. Delete the canvas's line there (or run `canvas open`) to open it again.
