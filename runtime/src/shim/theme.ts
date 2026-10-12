/**
 * Design tokens + tone mappings for the shim.
 *
 * Mirrors the real `cursor/canvas` token surface (`canvasPaletteDark/Light`,
 * `canvasTokens`, `categoryPalette*`, `colorPalette`, `usageColorSequence`,
 * `Color`) so canvases that read tokens via `useHostTheme()` or import the
 * palettes work unchanged.
 *
 * Vendored from thisismydesign/cursor-canvas-web v0.3.0 (MIT) and changed:
 *
 * - Theme presets. `__CANVAS_THEME__` (injected at build time from the host
 *   config) selects the dark scheme: `cursor` (default; Cursor's own dark
 *   palette) or `oxide` (see jacksmith15/dotfiles). Light is always Cursor's.
 * - Semantic tones, the category palette and the chart sequence are scoped to
 *   the colour scheme and exposed on the host theme (`tone`, `category`,
 *   `chartSequence`), rather than being scheme-independent module constants.
 *   Components read them through `useHostTheme()` so every colour flips with
 *   the scheme. `toneHex`, `colorPalette` and `chartColorSequence` remain as
 *   the active dark-scheme values for back-compat.
 */

export interface CanvasPalette {
  readonly foreground: string;
  readonly foregroundSecondary: string;
  readonly foregroundTertiary: string;
  readonly foregroundQuaternary: string;
  readonly editor: string;
  readonly chrome: string;
  readonly sidebar: string;
  readonly elevated: string;
  readonly fillPrimary: string;
  readonly fillSecondary: string;
  readonly fillTertiary: string;
  readonly fillQuaternary: string;
  readonly strokePrimary: string;
  readonly strokeSecondary: string;
  readonly strokeTertiary: string;
  readonly accent: string;
  readonly buttonBackground: string;
  readonly buttonForeground: string;
  readonly buttonHoverBackground: string;
  readonly link: string;
  readonly diffInsertedLine: string;
  readonly diffRemovedLine: string;
  readonly diffStripAdded: string;
  readonly diffStripRemoved: string;
}

/** Semantic tone literals used across primitives (Stat, Pill, Callout, charts, diffs, todos). */
export interface ToneSet {
  readonly success: string;
  readonly danger: string;
  readonly warning: string;
  readonly info: string;
  readonly neutral: string;
  readonly added: string;
  readonly deleted: string;
  readonly renamed: string;
}

/** Named category colours for `Swatch`, `UsageBar`, etc. Matches the official SDK's `Color` union. */
export type Color = 'gray' | 'purple' | 'green' | 'yellow' | 'cyan' | 'pink' | 'blue' | 'orange' | 'red';
export type CategoryPalette = Readonly<Record<Color, string>>;

interface SchemeColors {
  readonly palette: CanvasPalette;
  readonly tone: ToneSet;
  readonly category: CategoryPalette;
  readonly chartSequence: readonly string[];
}

/* ------------------------------------------------------------------ oxide */

// Oxide neutrals, from the Sublime/pi definitions. The text ramp below
// offWhite is pi's "thinking" ramp; the chrome steps are the Sublime theme's.
const OXIDE = {
  bgSink: '#24292a',
  bgFrame: '#292e30',
  bg: '#2e3436',
  bgRaise1: '#383f41',
  bgRaise2: '#424a4d',
  bgRaise3: '#4d5659',
  borderSubtle: '#474c4e',
  border: '#585d5e',
  muted: '#777b7c',
  textLow: '#7c8081',
  textMedium: '#9da0a0',
  textMinimal: '#5c6062',
  offWhite: '#d7d7d7',

  turquoise: '#5fafaf',
  orange: '#d7af5f',
  purple: '#af87d7',
  red: '#d75f5f',
  limegreen: '#87af5f',
  khaki: '#afaf87',
  orangeSubtle: '#c29356',
  // Two hues the editor scheme does not need but a categorical palette does.
  // Both sit on the same xterm-256 cube the other accents are picked from:
  // pink is the scheme's own noted "unused hue" (xterm 175), blue is xterm 67.
  pink: '#d787af',
  blue: '#5f87af',
  // Lighter cube neighbours for the back half of the chart sequence.
  turquoiseLight: '#87d7d7',
  greenLight: '#afd787',
  roseLight: '#d7afaf',

  successBg: '#3b463c',
  errorBg: '#4c3a3b',
} as const;

const oxideDark: SchemeColors = {
  palette: {
    foreground: OXIDE.offWhite,
    foregroundSecondary: OXIDE.textMedium,
    foregroundTertiary: OXIDE.textLow,
    foregroundQuaternary: OXIDE.textMinimal,
    editor: OXIDE.bg,
    chrome: OXIDE.bgFrame,
    sidebar: OXIDE.bgFrame,
    elevated: OXIDE.bgRaise1,
    // Fills are overlays that must read on any surface, so they are alpha
    // washes of offWhite (same alphas as Cursor's) rather than fixed greys.
    fillPrimary: `${OXIDE.offWhite}30`,
    fillSecondary: `${OXIDE.offWhite}1E`,
    fillTertiary: `${OXIDE.offWhite}11`,
    fillQuaternary: `${OXIDE.offWhite}0A`,
    strokePrimary: OXIDE.border,
    strokeSecondary: OXIDE.borderSubtle,
    strokeTertiary: OXIDE.bgRaise2,
    accent: OXIDE.turquoise,
    buttonBackground: OXIDE.turquoise,
    buttonForeground: OXIDE.bg,
    buttonHoverBackground: '#6fbfbf',
    link: OXIDE.turquoise,
    diffInsertedLine: OXIDE.successBg,
    diffRemovedLine: OXIDE.errorBg,
    diffStripAdded: OXIDE.limegreen,
    diffStripRemoved: OXIDE.red,
  },
  tone: {
    success: OXIDE.limegreen,
    danger: OXIDE.red,
    warning: OXIDE.orange,
    info: OXIDE.turquoise,
    neutral: OXIDE.muted,
    added: OXIDE.limegreen,
    deleted: OXIDE.red,
    renamed: OXIDE.purple,
  },
  category: {
    gray: OXIDE.muted,
    purple: OXIDE.purple,
    green: OXIDE.limegreen,
    yellow: OXIDE.khaki,
    cyan: OXIDE.turquoise,
    pink: OXIDE.pink,
    blue: OXIDE.blue,
    orange: OXIDE.orange,
    red: OXIDE.red,
  },
  chartSequence: [
    OXIDE.turquoise,
    OXIDE.orange,
    OXIDE.purple,
    OXIDE.limegreen,
    OXIDE.red,
    OXIDE.khaki,
    OXIDE.pink,
    OXIDE.blue,
    OXIDE.orangeSubtle,
    OXIDE.turquoiseLight,
    OXIDE.greenLight,
    OXIDE.roseLight,
  ],
};

/* ------------------------------------------------------------ cursor dark */

// Cursor's dark palette, as shipped by the upstream shim (aligned with the SDK).
const CURSOR_TONES: ToneSet = {
  success: '#1F8A65',
  danger: '#CF2D56',
  warning: '#E8A33D',
  info: '#2E79B5',
  neutral: '#8888A8',
  added: '#1F8A65',
  deleted: '#CF2D56',
  renamed: '#5A6CC0',
};

const CURSOR_CATEGORY: CategoryPalette = {
  gray: '#8888A8E0',
  purple: '#7B64B8F0',
  green: '#1F8A65E8',
  yellow: '#E8C030E0',
  cyan: '#2A9A8AE0',
  pink: '#C85898E0',
  blue: '#2E79B5E0',
  orange: '#F0A040E0',
  red: '#CF2D56E0',
};

const CURSOR_CHART_SEQUENCE: readonly string[] = [
  '#1F8A65E8',
  '#70B0D8E0',
  '#5A6CC0F0',
  '#F0A040E0',
  '#C06028E0',
  '#E8C030E0',
  '#C85898E0',
  '#F0A088E0',
  '#7B64B8F0',
  '#7DCAB0E0',
  '#8888A8E0',
  '#2A9A8AE0',
];

const cursorDark: SchemeColors = {
  palette: {
    foreground: '#E4E4E4EB',
    foregroundSecondary: '#E4E4E48D',
    foregroundTertiary: '#E4E4E45E',
    foregroundQuaternary: '#E4E4E442',
    editor: '#181818',
    chrome: '#141414',
    sidebar: '#141414',
    elevated: '#181818',
    fillPrimary: '#E4E4E430',
    fillSecondary: '#E4E4E41E',
    fillTertiary: '#E4E4E411',
    fillQuaternary: '#E4E4E40A',
    strokePrimary: '#E4E4E433',
    strokeSecondary: '#E4E4E41F',
    strokeTertiary: '#E4E4E414',
    accent: '#599CE7',
    buttonBackground: '#599CE7',
    buttonForeground: '#191c22',
    buttonHoverBackground: '#6AABE9',
    link: '#87c3ff',
    diffInsertedLine: '#3FA26633',
    diffRemovedLine: '#B8004933',
    diffStripAdded: '#3FA2668F',
    diffStripRemoved: '#FC6B838F',
  },
  tone: CURSOR_TONES,
  category: CURSOR_CATEGORY,
  chartSequence: CURSOR_CHART_SEQUENCE,
};

/* ----------------------------------------------------------- cursor light */

const cursorLight: SchemeColors = {
  palette: {
    foreground: '#141414F0',
    foregroundSecondary: '#141414BD',
    foregroundTertiary: '#1414148A',
    foregroundQuaternary: '#1414145C',
    editor: '#FCFCFC',
    chrome: '#F8F8F8',
    sidebar: '#F3F3F3',
    elevated: '#FCFCFC',
    fillPrimary: '#14141433',
    fillSecondary: '#14141424',
    fillTertiary: '#14141414',
    fillQuaternary: '#1414140F',
    strokePrimary: '#14141433',
    strokeSecondary: '#1414141F',
    strokeTertiary: '#14141414',
    accent: '#3685BF',
    buttonBackground: '#3685BF',
    buttonForeground: '#FCFCFC',
    buttonHoverBackground: '#2E76AB',
    link: '#3685BF',
    diffInsertedLine: '#1F8A651F',
    diffRemovedLine: '#CF2D5614',
    diffStripAdded: '#1F8A65CC',
    diffStripRemoved: '#CF2D56CC',
  },
  tone: CURSOR_TONES,
  category: CURSOR_CATEGORY,
  chartSequence: CURSOR_CHART_SEQUENCE,
};

/* ---------------------------------------------------------------- tokens */

/** The dark scheme selected by the host's theme preset. */
const activeDark: SchemeColors =
  typeof __CANVAS_THEME__ !== 'undefined' && __CANVAS_THEME__ === 'oxide' ? oxideDark : cursorDark;

export const canvasPaletteDark: CanvasPalette = activeDark.palette;
export const canvasPaletteLight: CanvasPalette = cursorLight.palette;

function buildTokens(palette: CanvasPalette) {
  return {
    bg: {
      editor: palette.editor,
      chrome: palette.chrome,
      elevated: palette.elevated,
    },
    text: {
      primary: palette.foreground,
      secondary: palette.foregroundSecondary,
      tertiary: palette.foregroundTertiary,
      quaternary: palette.foregroundQuaternary,
      link: palette.link,
      onAccent: palette.buttonForeground,
    },
    stroke: {
      primary: palette.strokePrimary,
      secondary: palette.strokeSecondary,
      tertiary: palette.strokeTertiary,
    },
    fill: {
      primary: palette.fillPrimary,
      secondary: palette.fillSecondary,
      tertiary: palette.fillTertiary,
      quaternary: palette.fillQuaternary,
    },
    accent: {
      primary: palette.accent,
      control: palette.buttonBackground,
      controlHover: palette.buttonHoverBackground,
    },
    diff: {
      insertedLine: palette.diffInsertedLine,
      removedLine: palette.diffRemovedLine,
      stripAdded: palette.diffStripAdded,
      stripRemoved: palette.diffStripRemoved,
    },
  };
}

export type CanvasTokens = ReturnType<typeof buildTokens>;

export const canvasTokens = buildTokens(canvasPaletteDark);
export const canvasTokensLight = buildTokens(canvasPaletteLight);

export const categoryPaletteDark: CategoryPalette = activeDark.category;
export const categoryPaletteLight: CategoryPalette = cursorLight.category;

/** Legacy name for the category palette; the per-scheme tables are `categoryPalette{Dark,Light}`. */
export const colorPalette: CategoryPalette = categoryPaletteDark;

/** Auto-color rotation for `UsageBar` segments without an explicit color. */
export const usageColorSequence: readonly Color[] = [
  'blue',
  'purple',
  'green',
  'yellow',
  'pink',
  'orange',
  'gray',
];

/** Dark-scheme chart sequence; prefer `useHostTheme().chartSequence`. */
export const chartColorSequence: readonly string[] = activeDark.chartSequence;

/** Dark-scheme tones; prefer `useHostTheme().tone`. */
export const toneHex: ToneSet = activeDark.tone;

/** Append an alpha (0–1) to a 6-digit hex colour. Used for tone-tinted surfaces. */
export function withAlpha(hex: string, alpha: number): string {
  const byte = Math.round(Math.min(1, Math.max(0, alpha)) * 255)
    .toString(16)
    .padStart(2, '0');
  return /^#[0-9a-fA-F]{6}$/.test(hex) ? `${hex}${byte}` : hex;
}

/** Host theme returned by `useHostTheme()`. Extends the token groups. */
export interface CanvasHostTheme extends CanvasTokens {
  readonly kind: string;
  readonly tokens: CanvasTokens;
  readonly palette: CanvasPalette;
  readonly tone: ToneSet;
  readonly category: CategoryPalette;
  readonly chartSequence: readonly string[];
}

export function buildHostTheme(kind: 'light' | 'dark'): CanvasHostTheme {
  const scheme = kind === 'dark' ? activeDark : cursorLight;
  const tokens = kind === 'dark' ? canvasTokens : canvasTokensLight;
  return {
    ...tokens,
    kind,
    tokens,
    palette: scheme.palette,
    tone: scheme.tone,
    category: scheme.category,
    chartSequence: scheme.chartSequence,
  };
}
