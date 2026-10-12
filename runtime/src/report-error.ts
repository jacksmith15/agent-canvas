/**
 * Forward browser-side errors to the dev server, which appends them to
 * `runtime/.canvas-errors.log`. The agent cannot see the browser console, so
 * this is how "the canvas is blank" becomes debuggable from the terminal.
 */
export function reportError(context: string, error: unknown): void {
  const message =
    error instanceof Error
      ? `${error.name}: ${error.message}${error.stack ? `\n${error.stack}` : ''}`
      : String(error);
  const payload = `[${context}] ${window.location.search} ${message}`;
  // The /__error endpoint exists only on the dev server. Exported single-file
  // canvases have no server, so just leave the error on the console there.
  if (!import.meta.env.DEV) {
    console.error(payload);
    return;
  }
  try {
    // keepalive so the beacon survives an immediate page reload.
    void fetch('/__error', { method: 'POST', body: payload, keepalive: true });
  } catch {
    // Best-effort only.
  }
}
