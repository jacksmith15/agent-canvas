/**
 * Alias target for `cursor/canvas`.
 *
 * Re-exports the vendored shim (`./shim`, from thisismydesign/cursor-canvas-web
 * v0.3.0, MIT) and layers on the behaviours a single-origin web host needs
 * that the shim does not provide:
 *
 * - `useCanvasState`: the shim persists to `localStorage` under `canvas:<key>`
 *   with no per-canvas namespace. The IDE stores state in a sidecar file next
 *   to each canvas, so two canvases using the same key never collide. We
 *   prefix the key with the hosted canvas path to restore that behaviour.
 * - React hook re-exports: the official SDK re-exports a few React hooks so a
 *   canvas needs only one import. Declared explicitly here so they exist
 *   regardless of shim version (explicit exports shadow `export *`).
 * - `Text`: the SDK parses inline markdown (backtick code, links) and renders
 *   nested Text as `<span>`; the shim does neither. See MarkdownText.tsx.
 * - `Code` / `DiffView`: the shim inlines its own monospace stack; these
 *   wrappers route it through the host theme's `fontFamilyMonospace`.
 */
export * from './shim/cursor-canvas';
export { useEffect, useMemo, useRef, useState } from 'react';
export type { CSSProperties, RefObject } from 'react';
export { Text } from './MarkdownText';
export { Code, DiffView } from './MonoOverrides';

import { useCanvasState as shimUseCanvasState, type SetCanvasState } from './shim/cursor-canvas';
import { currentCanvasPath } from './canvas-id';

export function useCanvasState<T>(key: string, defaultValue: T): [T, SetCanvasState<T>] {
  const scope = currentCanvasPath() ?? '__index__';
  return shimUseCanvasState(`${scope}::${key}`, defaultValue);
}
