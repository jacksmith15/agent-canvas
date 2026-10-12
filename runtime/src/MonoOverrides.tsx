import {
  Code as ShimCode,
  DiffView as ShimDiffView,
  type CodeProps,
  type DiffViewProps,
} from './shim/cursor-canvas';

/**
 * The shim hard-codes a monospace stack as an inline style on `Code` and
 * `DiffView`, which beats anything the Mantine theme says. Both spread their
 * `style` prop after the defaults, so supplying the theme's monospace variable
 * there is enough to route them through `fontFamilyMonospace`.
 */

const THEME_MONO = { fontFamily: 'var(--mantine-font-family-monospace)' } as const;

export function Code({ style, ...rest }: CodeProps) {
  return <ShimCode style={{ ...THEME_MONO, ...style }} {...rest} />;
}

export function DiffView({ style, ...rest }: DiffViewProps) {
  return <ShimDiffView style={{ ...THEME_MONO, ...style }} {...rest} />;
}
