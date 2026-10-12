/// <reference types="vite/client" />

/** Injected by `define`: the canvas root (see runtime/host-env.ts). */
declare const __CANVAS_PROJECTS_DIR__: string;

/** Injected by `define`: the active theme preset. */
declare const __CANVAS_THEME__: 'cursor' | 'oxide';

/**
 * Injected by `define`. In the dev server it is `undefined` (the canvas comes
 * from the URL). In a single-file export build (vite.export.config.ts) it is
 * the absolute path of the canvas baked into the bundle.
 */
declare const __CANVAS_EXPORT_PATH__: string | undefined;

/** Export builds only: the alias Vite resolves to the canvas being exported. */
declare module '@canvas' {
  import type { ComponentType } from 'react';
  const Canvas: ComponentType;
  export default Canvas;
}
