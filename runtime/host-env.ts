/**
 * Node-side resolution of the host's configuration, shared by the Vite configs.
 * Mirrors scripts/lib.sh exactly: environment variable, then
 * ~/.config/agent-canvas/config.json, then defaults. The scripts export the
 * resolved values before starting Vite, so in practice the env wins; the file
 * fallback only matters when Vite is run by hand.
 */
import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

export type CanvasTheme = 'cursor' | 'oxide';

interface UserConfig {
  root?: string;
  theme?: string;
  port?: number | string;
  pagesProject?: string;
}

function readUserConfig(): UserConfig {
  const file = join(process.env.XDG_CONFIG_HOME ?? join(homedir(), '.config'), 'agent-canvas', 'config.json');
  if (!existsSync(file)) return {};
  try {
    return JSON.parse(readFileSync(file, 'utf8')) as UserConfig;
  } catch {
    return {};
  }
}

function expandHome(path: string): string {
  return path.replace(/^~(?=\/|$)/, homedir());
}

/** Directory holding `<workspace-slug>/canvases/*.canvas.tsx`. */
export function canvasRoot(): string {
  const configured = process.env.CANVAS_ROOT ?? readUserConfig().root;
  if (configured) return expandHome(configured);
  const cursorProjects = join(homedir(), '.cursor', 'projects');
  if (existsSync(cursorProjects)) return cursorProjects;
  return join(process.env.XDG_DATA_HOME ?? join(homedir(), '.local', 'share'), 'agent-canvas', 'projects');
}

export function canvasTheme(): CanvasTheme {
  const value = process.env.CANVAS_THEME ?? readUserConfig().theme;
  return value === 'oxide' ? 'oxide' : 'cursor';
}

export function canvasPort(): number {
  const value = Number(process.env.CANVAS_PORT ?? readUserConfig().port ?? 4817);
  return Number.isFinite(value) && value > 0 ? value : 4817;
}

/** Only the oxide preset ships typefaces; the cursor preset uses system fonts. */
export function themeBundlesFonts(theme: CanvasTheme): boolean {
  return theme === 'oxide';
}
