import { useEffect, useState } from 'react';
import { H1, Link, Stack, Table, Text } from 'cursor/canvas';

interface CanvasEntry {
  workspace: string;
  name: string;
  path: string;
  url: string;
  mtime: number;
}

function formatMtime(ms: number): string {
  return new Date(ms).toLocaleString(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
}

/** Landing page at `/`: every canvas found in any workspace's `canvases/` directory. */
export function CanvasIndex() {
  const [entries, setEntries] = useState<CanvasEntry[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch('/__canvases')
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`))))
      .then((data: CanvasEntry[]) => setEntries(data))
      .catch((e: unknown) => setError(e instanceof Error ? e.message : String(e)));
  }, []);

  return (
    <Stack gap={16}>
      <H1>Canvases</H1>
      {error && <Text tone="secondary">Could not list canvases: {error}</Text>}
      {entries && entries.length === 0 && (
        <Text tone="secondary">
          No canvases yet. Files written to <code>~/.cursor/projects/&lt;workspace&gt;/canvases/*.canvas.tsx</code> will appear here.
        </Text>
      )}
      {entries && entries.length > 0 && (
        <Table
          headers={['Canvas', 'Workspace', 'Last modified']}
          rows={entries.map((e) => [
            <Link key={e.path} href={e.url}>{e.name}</Link>,
            e.workspace,
            formatMtime(e.mtime),
          ])}
        />
      )}
    </Stack>
  );
}
