import React, { useMemo } from 'react';
import { View, Text, StyleSheet } from 'react-native';
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

interface DividendInfo {
  yield: number | null;
  annualRate: number | null;
  payoutRatio: number | null;
  exDate: string | null;
}

interface Props {
  taxonomies: {
    period_kpi?: { figures: TaxonomyFigure[] };
  } | null;
  dividendInfo: DividendInfo | null;
}

export default function DividendsTab({ taxonomies, dividendInfo }: Props) {
  const figures = taxonomies?.period_kpi?.figures || [];

  // Get dividend yield history
  const yieldHistory = useMemo(() => {
    const figure = figures.find(f =>
      f.name === 'Dividend yield' || f.code === 'kpi_calc_dividend_yield'
    );
    if (!figure?.years) return [];
    return figure.years
      .filter(y => y.year && (y.report_type === 'ANNUAL' || !y.report_type) && y.value !== null && y.value !== undefined)
      .sort((a, b) => (b.year || 0) - (a.year || 0))
      .slice(0, 5);
  }, [figures]);

  // Get dividend payout history
  const payoutHistory = useMemo(() => {
    const figure = figures.find(f =>
      f.name === 'Dividend payout' || f.code === 'kpi_calc_dividend_payout'
    );
    if (!figure?.years) return [];
    return figure.years
      .filter(y => y.year && (y.report_type === 'ANNUAL' || !y.report_type) && y.value !== null && y.value !== undefined)
      .sort((a, b) => (b.year || 0) - (a.year || 0))
      .slice(0, 5);
  }, [figures]);

  const hasDividendData = dividendInfo?.yield || dividendInfo?.annualRate || yieldHistory.length > 0;

  if (!hasDividendData) {
    return (
      <View style={styles.container}>
        <View style={styles.emptyState}>
          <Ionicons name="cash-outline" size={64} color="#4B5563" />
          <Text style={styles.emptyTitle}>No Dividend Data</Text>
          <Text style={styles.emptyText}>
            This stock does not currently pay dividends or dividend data is unavailable.
          </Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Summary Cards */}
      <View style={styles.summaryRow}>
        <View style={styles.summaryCard}>
          <Text style={styles.summaryLabel}>Yield</Text>
          <Text style={styles.summaryValue}>
            {dividendInfo?.yield != null ? `${dividendInfo.yield.toFixed(2)}%` : '--'}
          </Text>
        </View>
        <View style={styles.summaryCard}>
          <Text style={styles.summaryLabel}>Payout Ratio</Text>
          <Text style={styles.summaryValue}>
            {dividendInfo?.payoutRatio != null ? `${dividendInfo.payoutRatio.toFixed(1)}%` : '--'}
          </Text>
        </View>
        <View style={styles.summaryCard}>
          <Text style={styles.summaryLabel}>Annual Rate</Text>
          <Text style={styles.summaryValue}>
            {dividendInfo?.annualRate != null ? `${dividendInfo.annualRate.toFixed(2)}p` : '--'}
          </Text>
        </View>
      </View>

      {/* Dividend Yield History */}
      {yieldHistory.length > 0 && (
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Ionicons name="trending-up-outline" size={16} color="#34D399" />
            <Text style={styles.sectionTitle}>Dividend Yield History</Text>
          </View>
          <View style={styles.table}>
            {yieldHistory.map((entry, idx) => (
              <View key={entry.year} style={[styles.row, idx === yieldHistory.length - 1 && styles.rowLast]}>
                <Text style={styles.rowLabel}>{entry.year}</Text>
                <Text style={[styles.rowValue, { color: '#34D399' }]}>
                  {entry.value.toFixed(2)}%
                </Text>
              </View>
            ))}
          </View>
        </View>
      )}

      {/* Payout History */}
      {payoutHistory.length > 0 && (
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Ionicons name="pie-chart-outline" size={16} color="#60A5FA" />
            <Text style={styles.sectionTitle}>Payout Ratio History</Text>
          </View>
          <View style={styles.table}>
            {payoutHistory.map((entry, idx) => (
              <View key={entry.year} style={[styles.row, idx === payoutHistory.length - 1 && styles.rowLast]}>
                <Text style={styles.rowLabel}>{entry.year}</Text>
                <Text style={[styles.rowValue, { color: entry.value > 100 ? '#F87171' : '#60A5FA' }]}>
                  {entry.value.toFixed(1)}%
                </Text>
              </View>
            ))}
          </View>
        </View>
      )}

      <View style={styles.disclaimer}>
        <Ionicons name="warning-outline" size={14} color="#FBBF24" />
        <Text style={styles.disclaimerText}>
          Past dividends do not guarantee future payments. Dividend policies can change at any time based on company performance and board decisions.
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
  summaryRow: { flexDirection: 'row', gap: 10, marginBottom: 20 },
  summaryCard: {
    flex: 1,
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    padding: 14,
    alignItems: 'center',
  },
  summaryLabel: { color: '#9CA3AF', fontSize: 11, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.3, marginBottom: 4 },
  summaryValue: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold' },
  section: { marginBottom: 20 },
  sectionHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: 8 },
  sectionTitle: { color: '#D1D5DB', fontSize: 14, fontWeight: '600', marginLeft: 6 },
  table: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)', borderRadius: 12,
    borderWidth: 1, borderColor: 'rgba(75, 85, 99, 0.3)', overflow: 'hidden',
  },
  row: {
    flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center',
    paddingVertical: 12, paddingHorizontal: 14,
    borderBottomWidth: 1, borderBottomColor: 'rgba(75, 85, 99, 0.2)',
  },
  rowLast: { borderBottomWidth: 0 },
  rowLabel: { color: '#9CA3AF', fontSize: 14, fontWeight: '600' },
  rowValue: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
  disclaimer: {
    flexDirection: 'row', alignItems: 'flex-start',
    backgroundColor: 'rgba(251, 191, 36, 0.08)', borderRadius: 10, padding: 10, marginTop: 4,
    borderWidth: 1, borderColor: 'rgba(251, 191, 36, 0.15)',
  },
  disclaimerText: { color: '#9CA3AF', fontSize: 11, marginLeft: 6, flex: 1, lineHeight: 16 },
});
