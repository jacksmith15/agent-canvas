import { Children, createContext, useContext, type ReactNode } from 'react';
import { Link, Text as ShimText, type TextProps } from './shim/cursor-canvas';
import { Code } from './MonoOverrides';

/**
 * `Text` with the two behaviours the official SDK documents that the shim
 * lacks:
 *
 * - Inline markdown in string children: `` `code` `` renders as `<Code>` and
 *   `[label](url)` as `<Link>`. Agents following the SDK's own guidance write
 *   these, so without parsing they appear as raw backticks and brackets.
 * - Nesting: a top-level `Text` is a `<p>`, a `Text` inside a `Text` is a
 *   `<span>`, so inline emphasis never produces invalid nested paragraphs.
 *   An explicit `as` still wins.
 */

const NestedText = createContext(false);

// Links must look like URLs (scheme, root-relative path, or fragment) so prose
// such as `arr[0](x)` is left alone.
const INLINE_MARKDOWN = /`([^`\n]+)`|\[([^\]\n]+)\]\(((?:https?:\/\/|mailto:|\/|#)[^)\s]*)\)/g;

function parseInline(text: string): ReactNode[] {
  const parts: ReactNode[] = [];
  let last = 0;
  for (const match of text.matchAll(INLINE_MARKDOWN)) {
    const index = match.index ?? 0;
    if (index > last) parts.push(text.slice(last, index));
    const [, code, label, href] = match;
    if (code !== undefined) {
      parts.push(<Code key={`code-${index}`}>{code}</Code>);
    } else {
      parts.push(
        <Link key={`link-${index}`} href={href}>
          {label}
        </Link>,
      );
    }
    last = index + match[0].length;
  }
  if (last < text.length) parts.push(text.slice(last));
  return parts;
}

function renderChildren(children: ReactNode): ReactNode {
  return Children.map(children, (child) => (typeof child === 'string' ? parseInline(child) : child));
}

export function Text({ children, as, ...rest }: TextProps) {
  const nested = useContext(NestedText);
  return (
    <NestedText.Provider value={true}>
      <ShimText as={as ?? (nested ? 'span' : 'p')} {...rest}>
        {renderChildren(children)}
      </ShimText>
    </NestedText.Provider>
  );
}
