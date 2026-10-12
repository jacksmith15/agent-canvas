import '@mantine/core/styles.css';
import '@mantine/charts/styles.css';
import './fonts.css';

import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { MantineProvider, type MantineColorScheme } from '@mantine/core';
import Canvas from '@canvas';

import { canvasNameFromPath } from './canvas-id';
import { ErrorBoundary } from './ErrorBoundary';
import { DEFAULT_COLOR_SCHEME, hostCssVariables, hostTheme } from './host-theme';

/**
 * Entry for single-file exports (vite.export.config.ts). The canvas is
 * imported statically through the `@canvas` alias and bundled with the
 * runtime, fonts included, into one HTML file that works from disk or any
 * static host. No server endpoints are used.
 */

const exportPath = __CANVAS_EXPORT_PATH__ ?? 'canvas.canvas.tsx';

function colorSchemeFromQuery(): MantineColorScheme {
  const theme = new URLSearchParams(window.location.search).get('theme');
  return theme === 'light' || theme === 'dark' || theme === 'auto' ? theme : DEFAULT_COLOR_SCHEME;
}

const container = document.getElementById('root');
if (!container) throw new Error('Root element #root not found');

document.title = canvasNameFromPath(exportPath);
const scheme = colorSchemeFromQuery();

createRoot(container).render(
  <StrictMode>
    <MantineProvider
      theme={hostTheme}
      cssVariablesResolver={hostCssVariables}
      defaultColorScheme={scheme}
      forceColorScheme={scheme === 'auto' ? undefined : scheme}
    >
      <ErrorBoundary path={exportPath}>
        <Canvas />
      </ErrorBoundary>
    </MantineProvider>
  </StrictMode>,
);
