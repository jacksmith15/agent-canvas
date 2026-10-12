import {
  createTheme,
  Table,
  type CSSVariablesResolver,
  type MantineColorScheme,
  type MantineColorsTuple,
  type MantineThemeOverride,
} from '@mantine/core';
import { canvasPaletteDark, canvasPaletteLight, type CanvasPalette } from './shim/theme';

/**
 * Mantine theme for the canvas host page.
 *
 * The shim builds its components from Mantine primitives. Everything the shim
 * colours itself comes from `shim/theme.ts` (selected by the theme preset);
 * this file makes the Mantine layer underneath agree with it: the page
 * background, text and border variables the shim's components reach for, the
 * `dark` grey ramp Mantine's own internals (inputs, dropdowns, dividers) use,
 * the primary colour that buttons, focus rings and controls inherit, and the
 * typefaces.
 *
 * Presets (`__CANVAS_THEME__`, from the host config):
 *   cursor  Cursor's palette, system UI font, follows the OS colour scheme.
 *   oxide   The oxide palette, Merriweather / Raleway / Fira Mono (self-hosted,
 *           see fonts.css), always dark.
 *
 * Components that hard-code a monospace stack inline (`Code`, `DiffView`) are
 * redirected to the theme's monospace variable by wrappers in cursor-canvas.ts.
 */

export const THEME_PRESET: 'cursor' | 'oxide' = typeof __CANVAS_THEME__ !== 'undefined' ? __CANVAS_THEME__ : 'cursor';

/** Oxide is a dark scheme and starts dark regardless of the OS; cursor follows the OS. */
export const DEFAULT_COLOR_SCHEME: MantineColorScheme = THEME_PRESET === 'oxide' ? 'dark' : 'auto';

/**
 * The shim's components reach for these Mantine variables (e.g. `Card` and
 * `CardHeader` borders use `default-border`, `Code` uses `default-hover`,
 * `Stat` labels use `dimmed`). Point them at the palette so the page
 * background and surfaces match the colours the components were designed for.
 */
function mantineVariablesFor(palette: CanvasPalette): Record<string, string> {
  return {
    '--mantine-color-body': palette.editor,
    '--mantine-color-text': palette.foreground,
    '--mantine-color-dimmed': palette.foregroundSecondary,
    '--mantine-color-placeholder': palette.foregroundTertiary,
    '--mantine-color-default': palette.elevated,
    '--mantine-color-default-border': palette.strokeSecondary,
    '--mantine-color-default-hover': palette.fillTertiary,
    '--mantine-color-anchor': palette.link,
  };
}

export const hostCssVariables: CSSVariablesResolver = () => ({
  variables: {},
  light: mantineVariablesFor(canvasPaletteLight),
  dark: mantineVariablesFor(canvasPaletteDark),
});

/* ------------------------------------------------------------ typefaces */

const SYSTEM_UI = 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Ubuntu, "Droid Sans", sans-serif';
const SYSTEM_MONO = 'ui-monospace, SFMono-Regular, Menlo, Monaco, "Cascadia Code", "Droid Sans Mono", monospace';

interface Typefaces {
  body: string;
  heading: string;
  mono: string;
  /** canvasTypography specifies 590; only a variable font can honour it exactly. */
  headingWeight: string;
}

const TYPEFACES: Record<typeof THEME_PRESET, Typefaces> = {
  cursor: { body: SYSTEM_UI, heading: SYSTEM_UI, mono: SYSTEM_MONO, headingWeight: '600' },
  oxide: {
    // System stacks follow the self-hosted face as a fallback while it loads.
    body: `"Raleway", ${SYSTEM_UI}`,
    heading: '"Merriweather", Georgia, "Times New Roman", serif',
    mono: `"Fira Mono", ${SYSTEM_MONO}`,
    headingWeight: '590',
  },
};

export const { body: BODY_FONT, heading: HEADING_FONT, mono: MONO_FONT } = TYPEFACES[THEME_PRESET];

/* -------------------------------------------------------------- colours */

/**
 * Oxide's grey ramp as Mantine's `dark` scale (index 0 lightest → 9 darkest).
 * Mantine's dark scheme derives input backgrounds (dark-6), dividers (dark-4),
 * dimmed text (dark-2) and more from this, so one ramp themes all of them.
 */
const OXIDE_DARK_RAMP: MantineColorsTuple = [
  '#d7d7d7', // 0 offWhite — text
  '#b5b8b8', // 1
  '#9da0a0', // 2 — dimmed text
  '#777b7c', // 3 muted
  '#585d5e', // 4 border
  '#474c4e', // 5 borderSubtle
  '#383f41', // 6 bgRaise1 — inputs, raised surfaces
  '#2e3436', // 7 bg — body
  '#292e30', // 8 bgFrame
  '#24292a', // 9 bgSink
];

/** Turquoise accent as a 10-shade scale (shade 6 is oxide's #5fafaf). */
const OXIDE_ACCENT: MantineColorsTuple = [
  '#e6f3f3', '#cfe6e6', '#b2d7d7', '#95c8c8', '#7fbcbc',
  '#6fb5b5', '#5fafaf', '#509c9c', '#448989', '#377676',
];

/** Cursor's greys as Mantine's `dark` scale; body #181818, surfaces one step up. */
const CURSOR_DARK_RAMP: MantineColorsTuple = [
  '#e4e4e4', '#c4c4c4', '#a3a3a3', '#7a7a7a', '#454545',
  '#333333', '#242424', '#181818', '#141414', '#101010',
];

/** Cursor's accent blue; shade 6 ≈ dark accent #599CE7, shade 7 ≈ light accent #3685BF. */
const CURSOR_ACCENT: MantineColorsTuple = [
  '#e8f2fc', '#d0e5f8', '#a6cdf2', '#7cb5ec', '#64a6e9',
  '#5c9fe8', '#599ce7', '#3685bf', '#2e76ab', '#256597',
];

const COLOURS: Record<typeof THEME_PRESET, Pick<MantineThemeOverride, 'colors' | 'primaryColor' | 'primaryShade'>> = {
  cursor: {
    colors: { dark: CURSOR_DARK_RAMP, accent: CURSOR_ACCENT },
    primaryColor: 'accent',
    primaryShade: { light: 7, dark: 6 },
  },
  oxide: {
    colors: { dark: OXIDE_DARK_RAMP, accent: OXIDE_ACCENT },
    primaryColor: 'accent',
    primaryShade: { light: 7, dark: 6 },
  },
};

/* ---------------------------------------------------------------- theme */

export const hostTheme = createTheme({
  fontFamily: BODY_FONT,
  fontFamilyMonospace: MONO_FONT,
  headings: {
    fontFamily: HEADING_FONT,
    fontWeight: TYPEFACES[THEME_PRESET].headingWeight,
  },
  ...COLOURS[THEME_PRESET],
  // canvasRadius from the official SDK (px). The shim picks `md` for cards.
  radius: { xs: '2px', sm: '4px', md: '6px', lg: '8px', xl: '12px' },
  defaultRadius: 'md',
  components: {
    Table: Table.extend({
      styles: {
        table: { fontVariantNumeric: 'lining-nums tabular-nums' },
      },
    }),
  },
});
