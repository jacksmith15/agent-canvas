import { existsSync } from 'node:fs';
import { isAbsolute, join } from 'node:path';
import { fileURLToPath, URL } from 'node:url';
import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import { viteSingleFile } from 'vite-plugin-singlefile';
import { canvasRoot, canvasTheme, themeBundlesFonts } from './host-env';

/**
 * Build config for single-file canvas exports. Driven by scripts/export-canvas.sh:
 *
 *   CANVAS_EXPORT_FILE   absolute path of the .canvas.tsx to bundle (required)
 *   CANVAS_EXPORT_OUT    output directory (default: .export-dist)
 *   CANVAS_EXPORT_FONTS  "0" to leave the self-hosted fonts out (smaller file)
 *
 * Produces <out>/export.html: runtime + canvas + CSS (+ fonts as data URLs) in
 * one file, with no absolute asset URLs, so it renders from file:// or any host.
 */

const RUNTIME_DIR = fileURLToPath(new URL('.', import.meta.url));
const PROJECTS_DIR = canvasRoot();
const THEME = canvasTheme();

const canvasFile = process.env.CANVAS_EXPORT_FILE;
if (!canvasFile || !isAbsolute(canvasFile) || !existsSync(canvasFile)) {
  throw new Error(`CANVAS_EXPORT_FILE must be an absolute path to an existing .canvas.tsx (got: ${canvasFile ?? 'unset'})`);
}
const outDir = process.env.CANVAS_EXPORT_OUT ?? join(RUNTIME_DIR, '.export-dist');
// Fonts are only worth the bytes when the active theme actually uses them.
const includeFonts = themeBundlesFonts(THEME) && process.env.CANVAS_EXPORT_FONTS !== '0';

/** With --no-fonts, replace fonts.css with an empty module so nothing is embedded. */
function stripFonts(): Plugin {
  return {
    name: 'canvas-cli:strip-fonts',
    enforce: 'pre',
    transform(_code, id) {
      if (!includeFonts && id.endsWith('/src/fonts.css')) return { code: '', map: null };
      return null;
    },
  };
}

export default defineConfig({
  root: RUNTIME_DIR,
  base: './',
  // Nothing may be emitted beside the HTML; every asset is an import.
  publicDir: false,
  plugins: [stripFonts(), react(), viteSingleFile()],
  define: {
    __CANVAS_PROJECTS_DIR__: JSON.stringify(PROJECTS_DIR),
    __CANVAS_THEME__: JSON.stringify(THEME),
    __CANVAS_EXPORT_PATH__: JSON.stringify(canvasFile),
  },
  resolve: {
    alias: {
      'cursor/canvas': join(RUNTIME_DIR, 'src', 'cursor-canvas.ts'),
      '@canvas': canvasFile,
    },
  },
  server: {
    fs: { allow: [RUNTIME_DIR, PROJECTS_DIR] },
  },
  build: {
    outDir,
    emptyOutDir: true,
    rollupOptions: { input: join(RUNTIME_DIR, 'export.html') },
    // Fonts referenced from fonts.css must become data URLs, not files.
    assetsInlineLimit: () => true,
    cssCodeSplit: false,
    // Keep the build quiet about the (expected) large single chunk.
    chunkSizeWarningLimit: 10_000,
    sourcemap: false,
  },
  logLevel: 'warn',
});
