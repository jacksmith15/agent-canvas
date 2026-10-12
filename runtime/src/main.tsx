import '@mantine/core/styles.css';
import '@mantine/charts/styles.css';
import './fonts.css';

import { StrictMode, type ComponentType, type ReactNode } from 'react';
import { createRoot } from 'react-dom/client';
import { MantineProvider, type MantineColorScheme } from '@mantine/core';

import { canvasNameFromPath, currentCanvasPath } from './canvas-id';
import { CanvasIndex } from './CanvasIndex';
import { ErrorBoundary, ErrorPanel } from './ErrorBoundary';
import { DEFAULT_COLOR_SCHEME, hostCssVariables, hostTheme } from './host-theme';
import { reportError } from './report-error';

/**
 * Load a canvas module through Vite's `/@fs/` endpoint. The file lives outside
 * the Vite root (`~/.cursor/projects/<ws>/canvases/`), which `server.fs.allow`
 * permits. Going through the module graph (rather than a raw fetch) means the
 * `cursor/canvas` alias is applied and HMR keeps working on edits.
 */
async function loadCanvas(path: string): Promise<ComponentType> {
  const mod: unknown = await import(/* @vite-ignore */ `/@fs${path}`);
  const component = (mod as { default?: unknown }).default;
  if (typeof component !== 'function') {
    throw new Error(
      `${path} must default-export a React component (found ${typeof component}).`,
    );
  }
  return component as ComponentType;
}

/** `?theme=light|dark|auto` overrides the host default (oxide: dark). */
function colorSchemeFromQuery(): MantineColorScheme {
  const theme = new URLSearchParams(window.location.search).get('theme');
  return theme === 'light' || theme === 'dark' || theme === 'auto' ? theme : DEFAULT_COLOR_SCHEME;
}

async function main(): Promise<void> {
  const container = document.getElementById('root');
  if (!container) throw new Error('Root element #root not found');

  window.addEventListener('error', (e) => reportError('window.onerror', e.error ?? e.message));
  window.addEventListener('unhandledrejection', (e) => reportError('unhandledrejection', e.reason));

  const path = currentCanvasPath();
  let content: ReactNode;

  if (path) {
    const name = canvasNameFromPath(path);
    document.title = `${name} · canvas`;
    try {
      const Canvas = await loadCanvas(path);
      content = (
        <ErrorBoundary path={path}>
          <Canvas />
        </ErrorBoundary>
      );
    } catch (err) {
      reportError(`load ${path}`, err);
      content = <ErrorPanel title={`Failed to load ${name}`} path={path} error={err} />;
    }
  } else {
    document.title = 'Canvases';
    content = <CanvasIndex />;
  }

  // Force the scheme rather than defaulting it: Mantine otherwise prefers a
  // value persisted in localStorage from an earlier visit, which would make
  // the host default and `?theme=` unpredictable.
  const scheme = colorSchemeFromQuery();
  createRoot(container).render(
    <StrictMode>
      <MantineProvider
        theme={hostTheme}
        cssVariablesResolver={hostCssVariables}
        defaultColorScheme={scheme}
        forceColorScheme={scheme === 'auto' ? undefined : scheme}
      >
        {content}
      </MantineProvider>
    </StrictMode>,
  );
}

void main();
