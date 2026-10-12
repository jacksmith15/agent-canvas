/**
 * Which canvas is this page hosting?
 *
 * Preferred form is the short route `/c/<workspace>/<name>`, which maps to
 * `<projects dir>/<workspace>/canvases/<name>.canvas.tsx`. The query form
 * `/?file=<absolute path>` is also accepted for canvases outside the managed
 * directory. With neither, the page shows the index of all canvases.
 */

const SHORT_ROUTE = /^\/c\/([^/]+)\/([^/]+)\/?$/;

function isSafeSegment(segment: string): boolean {
  return segment.length > 0 && segment !== '.' && segment !== '..' && !segment.includes('/');
}

export function currentCanvasPath(): string | null {
  // Single-file exports carry their canvas with them; the URL says nothing.
  if (typeof __CANVAS_EXPORT_PATH__ === 'string') return __CANVAS_EXPORT_PATH__;

  const match = SHORT_ROUTE.exec(window.location.pathname);
  if (match) {
    const workspace = decodeURIComponent(match[1]);
    const name = decodeURIComponent(match[2]);
    if (!isSafeSegment(workspace) || !isSafeSegment(name)) return null;
    return `${__CANVAS_PROJECTS_DIR__}/${workspace}/canvases/${name}.canvas.tsx`;
  }

  const file = new URLSearchParams(window.location.search).get('file');
  if (!file) return null;
  if (!file.startsWith('/') || !file.endsWith('.canvas.tsx')) return null;
  return file;
}

/** Display name: `foo.canvas.tsx` -> `foo`. */
export function canvasNameFromPath(path: string): string {
  const base = path.slice(path.lastIndexOf('/') + 1);
  return base.replace(/\.canvas\.tsx$/, '');
}
