# `cursor/canvas` SDK declarations

This directory holds the official `cursor/canvas` TypeScript declarations (`*.d.ts`), which the agent reads to discover components, props and hooks while authoring a canvas.

They are Cursor's and are **not committed here**. `canvas setup` (or `scripts/fetch-sdk.sh`) populates this directory, copying from a local Cursor IDE install when one exists and otherwise fetching from a public mirror.

Type-checking does not depend on them: `canvas check` compiles against the vendored shim in `runtime/src/shim/`, which is what actually renders. If the two disagree, the check is authoritative for this host.
