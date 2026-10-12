/**
 * Chart primitives mapped onto `@mantine/charts`.
 *
 * The SDK describes charts as parallel `categories` + `series[]` arrays (or a
 * flat `data` array for pie); Mantine wants an array of row objects plus a
 * series descriptor. We reshape here and map `tone` -> color.
 */
import type { CSSProperties } from 'react';
import {
  AreaChart,
  BarChart as MantineBarChart,
  LineChart as MantineLineChart,
  PieChart as MantinePieChart,
  DonutChart,
} from '@mantine/charts';

import type { CanvasHostTheme } from './theme';
import { useHostTheme } from './use-tokens';

export type ChartTone = 'success' | 'danger' | 'warning' | 'info' | 'neutral';

export type ChartDataPoint = { label: string; value: number };

export type ChartSeries = {
  name: string;
  data: number[];
  tone?: ChartTone;
};

export type BarChartProps = {
  categories: string[];
  series: ChartSeries[];
  height?: number;
  stacked?: boolean;
  horizontal?: boolean;
  normalized?: boolean;
  valueSuffix?: string;
  style?: CSSProperties;
};

export type LineChartProps = {
  categories: string[];
  series: ChartSeries[];
  height?: number;
  fill?: boolean;
  valueSuffix?: string;
  style?: CSSProperties;
};

export type PieChartProps = {
  data: Array<ChartDataPoint & { tone?: ChartTone }>;
  size?: number;
  donut?: boolean;
  style?: CSSProperties;
};

function seriesColor(
  theme: CanvasHostTheme,
  tone: ChartTone | undefined,
  index: number,
): string {
  return tone
    ? theme.tone[tone]
    : theme.chartSequence[index % theme.chartSequence.length];
}

/**
 * Recharts (via Mantine) gives a vertical-orientation bar chart a fixed 60px
 * axis for its category labels and clips anything longer. Size it to the
 * longest label instead; ~6.5px per character at the 12px axis font.
 */
function categoryAxisWidth(categories: string[]): number {
  const longest = categories.reduce((max, c) => Math.max(max, c.length), 0);
  return Math.min(220, Math.max(60, 12 + longest * 6.5));
}

/** Reshape parallel `categories` + `series[]` into Mantine row objects. */
export function reshapeLineChartData(
  categories: string[],
  series: ChartSeries[],
): Record<string, string | number>[] {
  return categories.map((category, index) => {
    const row: Record<string, string | number> = { category };
    for (const s of series) row[s.name] = s.data[index] ?? 0;
    return row;
  });
}

function toMantineSeries(theme: CanvasHostTheme, series: ChartSeries[]) {
  return series.map((s, index) => ({
    name: s.name,
    color: seriesColor(theme, s.tone, index),
  }));
}

function suffixFormatter(valueSuffix?: string) {
  return valueSuffix ? (value: number) => `${value}${valueSuffix}` : undefined;
}

export function LineChart({
  categories,
  series,
  height = 240,
  fill,
  valueSuffix,
  style,
}: LineChartProps) {
  const theme = useHostTheme();
  const data = reshapeLineChartData(categories, series);
  const mantineSeries = toMantineSeries(theme, series);
  const common = {
    h: height,
    data,
    dataKey: 'category',
    series: mantineSeries,
    curveType: 'monotone' as const,
    withLegend: series.length > 1,
    valueFormatter: suffixFormatter(valueSuffix),
    style,
  };
  return fill ? <AreaChart {...common} /> : <MantineLineChart {...common} />;
}

export function BarChart({
  categories,
  series,
  height = 240,
  stacked,
  horizontal,
  normalized,
  valueSuffix,
  style,
}: BarChartProps) {
  const theme = useHostTheme();
  const data = reshapeLineChartData(categories, series);
  const type = normalized ? 'percent' : stacked ? 'stacked' : 'default';
  return (
    <MantineBarChart
      h={height}
      data={data}
      dataKey="category"
      series={toMantineSeries(theme, series)}
      type={type}
      orientation={horizontal ? 'vertical' : 'horizontal'}
      withLegend={series.length > 1}
      valueFormatter={suffixFormatter(valueSuffix)}
      yAxisProps={horizontal ? { width: categoryAxisWidth(categories) } : undefined}
      style={style}
    />
  );
}

export function PieChart({ data, size = 180, donut, style }: PieChartProps) {
  const theme = useHostTheme();
  const mantineData = data.map((point, index) => ({
    name: point.label,
    value: point.value,
    color: seriesColor(theme, point.tone, index),
  }));
  const common = {
    data: mantineData,
    size,
    withTooltip: true as const,
    style,
  };
  return donut ? (
    <DonutChart {...common} />
  ) : (
    <MantinePieChart {...common} withLabelsLine={false} />
  );
}
