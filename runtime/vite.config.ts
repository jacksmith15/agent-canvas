import { readdirSync, statSync, appendFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath, URL } from 'node:url';
import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import { canvasPort, canvasRoot, canvasTheme } from './host-env';

const RUNTIME_DIR = fileURLToPath(new URL('.', import.meta.url));
const PROJECTS_DIR = canvasRoot();
const PORT = canvasPort();
const THEME = canvasTheme();
const ERROR_LOG = join(RUNTIME_DIR, '.canvas-errors.log');

interface CanvasEntry {
  workspace: string;
  name: string;
  path: string;
  /** Short route served by this host: `/c/<workspace>/<name>`. */
  url: string;
  mtime: number;
}

function shortUrl(workspace: string, name: string): string {
  return `/c/${encodeURIComponent(workspace)}/${encodeURIComponent(name)}`;
}

/** Scan every `~/.cursor/projects/<ws>/canvases/` for canvas files. */
function listCanvases(): CanvasEntry[] {
  const out: CanvasEntry[] = [];
  let workspaces: string[] = [];
  try {
    workspaces = readdirSync(PROJECTS_DIR);
  } catch {
    return out;
  }
  for (const ws of workspaces) {
    const dir = join(PROJECTS_DIR, ws, 'canvases');
    let files: string[] = [];
    try {
      files = readdirSync(dir);
    } catch {
      continue;
    }
    for (const f of files) {
      if (!f.endsWith('.canvas.tsx')) continue;
      const path = join(dir, f);
      const name = f.replace(/\.canvas\.tsx$/, '');
      out.push({
        workspace: ws,
        name,
        path,
        url: shortUrl(ws, name),
        mtime: statSync(path).mtimeMs,
      });
    }
  }
  return out.sort((a, b) => b.mtime - a.mtime);
}

/**
 * Dev-server-only endpoints used by the host page:
 *  - GET  /__canvases   JSON list of every canvas on disk (for the index page)
 *  - POST /__error      Browser-side runtime errors, appended to a log file so
 *                       the agent can read them from the terminal.
 */
function canvasHostApi(): Plugin {
  return {
    name: 'canvas-cli:host-api',
    configureServer(server) {
      server.middlewares.use('/__canvases', (_req, res) => {
        res.setHeader('Content-Type', 'application/json');
        res.setHeader('Cache-Control', 'no-store');
        res.end(JSON.stringify(listCanvases()));
      });
      server.middlewares.use('/__error', (req, res) => {
        if (req.method !== 'POST') {
          res.statusCode = 405;
          res.end();
          return;
        }
        let body = '';
        req.on('data', (chunk) => (body += chunk));
        req.on('end', () => {
          const line = `${new Date().toISOString()} ${body.replace(/\s+/g, ' ').trim()}\n`;
          try {
            appendFileSync(ERROR_LOG, line);
          } catch {
            // Logging is best-effort.
          }
          res.statusCode = 204;
          res.end();
        });
      });
    },
  };
}

export default defineConfig({
  plugins: [react(), canvasHostApi()],
  define: {
    // Lets the client turn a short `/c/<workspace>/<name>` route back into the
    // absolute file path it needs for the /@fs/ import.
    __CANVAS_PROJECTS_DIR__: JSON.stringify(PROJECTS_DIR),
    __CANVAS_THEME__: JSON.stringify(THEME),
    // Only set by vite.export.config.ts.
    __CANVAS_EXPORT_PATH__: 'undefined',
  },
  resolve: {
    alias: {
      // The single bridge: canvases import `cursor/canvas`; we resolve it to a
      // local module that re-exports the Mantine-backed shim.
      'cursor/canvas': join(RUNTIME_DIR, 'src', 'cursor-canvas.ts'),
    },
  },
  server: {
    host: '127.0.0.1',
    port: PORT,
    strictPort: true,
    open: false,
    fs: {
      // Canvases live outside the Vite root; allow serving them via /@fs/.
      allow: [RUNTIME_DIR, PROJECTS_DIR],
    },
  },
  optimizeDeps: {
    // Canvas files are discovered lazily (dynamic /@fs/ import), so the dep
    // scanner never sees their imports. Pre-bundle everything up front to
    // avoid a mid-session "new dependencies optimized" reload.
    include: [
      'react',
      'react-dom',
      'react/jsx-runtime',
      '@mantine/core',
      '@mantine/charts',
      'recharts',
    ],
  },
});
