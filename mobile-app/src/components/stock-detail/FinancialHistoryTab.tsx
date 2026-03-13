import React, { useMemo } from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

interface TaxonomyFigure {
  code: string;
  name: string;
  years: Array<{
    year?: number;
    report_type?: string;
    value: number;
  }>;
}

interface Props {
  taxonomies: {
    period_kpi?: { figures: TaxonomyFigure[] };
  } | null;
}

const KPI_METRICS = [
  { code: 'kpi_calc_net_sales', label: 'Revenue', format: 'currency' },
  { code: 'kpi_calc_roe', label: 'Return on Equity', format: 'percent' },
  { code: 'kpi_calc_roa', label: 'Return on Assets', format: 'percent' },
  { code: 'kpi_calc_gross_margin', label: 'Gross Margin', format: 'percent' },
  { code: 'kpi_calc_net_margin', label: 'Net Margin', format: 'percent' },
  { code: 'kpi_eps_basic', label: 'EPS (Basic)', format: 'number' },
  { code: 'kpi_calc_price_to_earnings', label: 'P/E Ratio', format: 'number' },
  { code: 'kpi_calc_dividend_yield', label: 'Dividend Yield', format: 'percent' },
];

const formatValue = (value: number | null, format: string): string => {
  if (value === null || value === undefined || isNaN(value)) return '--';
  switch (format) {
    case 'currency': {
      const abs = Math.abs(value);
      const sign = value < 0 ? '-' : '';
      if (abs >= 1e9) return `${sign}£${(abs / 1e9).toFixed(1)}B`;
      if (abs >= 1e6) return `${sign}£${(abs / 1e6).toFixed(0)}M`;
      return `${sign}£${abs.toFixed(0)}`;
    }
    case 'percent':
      return `${value.toFixed(1)}%`;
    case 'number':
      return value.toFixed(2);
    default:
      return value.toFixed(2);
  }
};

export default function FinancialHistoryTab({ taxonomies }: Props) {
  const figures = taxonomies?.period_kpi?.figures || [];

  // Get all available ANNUAL years across all metrics
  const years = useMemo(() => {
    const yearSet = new Set<number>();
    figures.forEach(f => {
      f.years?.forEach(y => {
        if (y.year && (y.report_type === 'ANNUAL' || !y.report_type) && y.value !== null && y.value !== undefined) {
          yearSet.add(y.year);
        }
      });
    });
    return Array.from(yearSet).sort((a, b) => b - a).slice(0, 5);
  }, [figures]);

  const getValueForYear = (code: string, year: number): number | null => {
    const figure = figures.find(f => f.code === code);
    if (!figure) return null;
    const yearData = figure.years?.find(y =>
      y.year === year && (y.report_type === 'ANNUAL' || !y.report_type)
    );
    return yearData?.value ?? null;
  };

  if (!figures.length || !years.length) {
    return (
      <View style={styles.container}>
        <View style={styles.emptyState}>
          <Ionicons name="time-outline" size={64} color="#4B5563" />
          <Text style={styles.emptyTitle}>Financial History Unavailable</Text>
          <Text style={styles.emptyText}>
            Historical financial data is not available for this stock.
          </Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.sectionHeader}>
        <Ionicons name="time-outline" size={16} color="#60A5FA" />
        <Text style={styles.sectionTitle}>Annual Financial Trends</Text>
      </View>

      {KPI_METRICS.map(metric => {
        const values = years.map(y => getValueForYear(metric.code, y));
        const hasData = values.some(v => v !== null);
        if (!hasData) return null;

        // Calculate trend (latest vs previous)
        const latest = values[0];
        const previous = values[1];
        const trend = latest !== null && previous !== null && previous !== 0
          ? ((latest - previous) / Math.abs(previous)) * 100
          : null;

        return (
          <View key={metric.code} style={styles.metricCard}>
            <View style={styles.metricHeader}>
              <Text style={styles.metricLabel}>{metric.label}</Text>
              {trend !== null && (
                <View style={[styles.trendBadge, { backgroundColor: trend >= 0 ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)' }]}>
                  <Ionicons
                    name={trend >= 0 ? 'trending-up' : 'trending-down'}
                    size={12}
                    color={trend >= 0 ? '#34D399' : '#F87171'}
                  />
                  <Text style={[styles.trendText, { color: trend >= 0 ? '#34D399' : '#F87171' }]}>
                    {trend >= 0 ? '+' : ''}{trend.toFixed(1)}%
                  </Text>
                </View>
              )}
            </View>
            <ScrollView horizontal showsHorizontalScrollIndicator={false}>
              <View style={styles.yearRow}>
                {years.map((year, idx) => (
                  <View key={year} style={[styles.yearCell, idx === 0 && styles.yearCellFirst]}>
                    <Text style={styles.yearCellYear}>{year}</Text>
                    <Text style={[
                      styles.yearCellValue,
                      idx === 0 && styles.yearCellValueLatest,
                    ]}>
                      {formatValue(values[idx], metric.format)}
                    </Text>
                  </View>
                ))}
              </View>
            </ScrollView>
          </View>
        );
      })}

      <View style={styles.disclaimer}>
        <Ionicons name="information-circle-outline" size={14} color="#6B7280" />
        <Text style={styles.disclaimerText}>
          Showing annual data. Trends compare the most recent year to the previous year.
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  emptyState: { alignItems: 'center', justifyContent: 'center', paddingVertical: 60 },
  emptyTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: '600', marginTop: 16, marginBottom: 8 },
  emptyText: { color: '#9CA3AF', fontSize: 14, textAlign: 'center', paddingHorizontal: 40 },
  sectionHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: 12 },
  sectionTitle: { color: '#D1D5DB', fontSize: 14, fontWeight: '600', marginLeft: 6 },
  metricCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    padding: 14,
    marginBottom: 12,
  },
  metricHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  metricLabel: { color: '#D1D5DB', fontSize: 14, fontWeight: '600' },
  trendBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 12,
    gap: 4,
  },
  trendText: { fontSize: 12, fontWeight: '600' },
  yearRow: { flexDirection: 'row', gap: 4 },
  yearCell: {
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: 'rgba(15, 23, 42, 0.5)',
    borderRadius: 8,
    minWidth: 72,
  },
  yearCellFirst: { backgroundColor: 'rgba(59, 130, 246, 0.15)' },
  yearCellYear: { color: '#6B7280', fontSize: 11, fontWeight: '600', marginBottom: 2 },
  yearCellValue: { color: '#D1D5DB', fontSize: 13, fontWeight: '600' },
  yearCellValueLatest: { color: '#FFFFFF' },
  disclaimer: {
    flexDirection: 'row', alignItems: 'flex-start',
    backgroundColor: 'rgba(31, 41, 55, 0.3)', borderRadius: 10, padding: 10, marginTop: 4,
  },
  disclaimerText: { color: '#6B7280', fontSize: 11, marginLeft: 6, flex: 1, lineHeight: 16 },
});
