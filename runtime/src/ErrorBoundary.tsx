import { Component, type ErrorInfo, type ReactNode } from 'react';
import { reportError } from './report-error';

interface ErrorPanelProps {
  title: string;
  path: string;
  error: unknown;
}

/** Plain-HTML error display: must not depend on the canvas SDK, which may be what failed. */
export function ErrorPanel({ title, path, error }: ErrorPanelProps) {
  const message = error instanceof Error ? error.message : String(error);
  const stack = error instanceof Error ? error.stack : undefined;
  return (
    <div style={{ fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace', fontSize: 13, lineHeight: 1.5 }}>
      <h1 style={{ fontSize: 18, fontWeight: 600, margin: '0 0 8px' }}>{title}</h1>
      <p style={{ margin: '0 0 16px', opacity: 0.7 }}>{path}</p>
      <pre style={{ whiteSpace: 'pre-wrap', margin: 0 }}>{stack ?? message}</pre>
      <p style={{ marginTop: 16, opacity: 0.7 }}>
        This error was also written to the runtime&apos;s <code>.canvas-errors.log</code>.
      </p>
    </div>
  );
}

interface ErrorBoundaryProps {
  path: string;
  children: ReactNode;
}

interface ErrorBoundaryState {
  error: unknown;
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { error: null };

  static getDerivedStateFromError(error: unknown): ErrorBoundaryState {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    reportError(`render ${this.props.path}`, `${error.stack ?? error.message}\n${info.componentStack ?? ''}`);
  }

  render(): ReactNode {
    if (this.state.error !== null) {
      return <ErrorPanel title="Canvas threw while rendering" path={this.props.path} error={this.state.error} />;
    }
    return this.props.children;
  }
}
