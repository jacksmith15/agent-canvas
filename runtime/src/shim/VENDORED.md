# Vendored `cursor/canvas` shim

Source: [thisismydesign/cursor-canvas-web](https://github.com/thisismydesign/cursor-canvas-web), tag `v0.3.0` (commit `b7d8db9d48`), `src/shim/*`. MIT licence; see `LICENSE` in this directory.

Vendored rather than consumed from npm so the palette and component details can be owned here. Keep the public API (export names, prop shapes) identical to the official `cursor/canvas` declarations in `../../../sdk/` so canvases stay portable to the IDE.

## Local changes

- `theme.ts`: rewritten around theme presets. The dark scheme is selected at build time by `__CANVAS_THEME__`: `cursor` (default, upstream's values) or `oxide`; light is always Cursor's. Tones, the category palette and the chart sequence are scheme-scoped and exposed on `useHostTheme()` as `tone`, `category`, `chartSequence`. Added `categoryPaletteDark/Light`, `CategoryPalette`, `ToneSet`, `withAlpha`. `Color` now has the official nine names (adds `cyan`, `red`). Removed `toneColor`.
- `cursor-canvas.tsx`: `Stat`, `Pill`, `Callout`, `Table` row tones, `Swatch`, `UsageBar` read colours from the host theme instead of module constants. `Card` paints `bg.elevated`. `Pill` no longer truncates its label.
- `charts.tsx`: series colours from the host theme; horizontal bar charts size the category axis to the longest label.
- `diff.tsx`, `todo.tsx`: tones from the host theme.

## Re-syncing with upstream

Diff upstream `src/shim/` against the tag above, then apply upstream changes on top of the edits listed here. Behaviours added outside this directory (`../MarkdownText.tsx`, `../MonoOverrides.tsx`, `useCanvasState` namespacing in `../cursor-canvas.ts`) do not depend on shim internals beyond the public exports.
