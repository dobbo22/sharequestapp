import React, { useState, useMemo } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
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
    income_statement?: { figures: TaxonomyFigure[] };
  } | null;
}

const INCOME_FIELDS = [
  { code: 'is_revenue_tot', label: 'Total Revenue', altCodes: ['is_revenue_net'] },
  { code: 'is_gross_profit', label: 'Gross Profit', altCodes: [] },
  { code: 'is_ebitda', label: 'EBITDA', altCodes: [] },
  { code: 'is_ebit', label: 'EBIT / Operating Income', altCodes: ['is_op_income'] },
  { code: 'is_pretax_income', label: 'Pretax Income', altCodes: ['is_income_bt'] },
  { code: 'is_net_income', label: 'Net Income', altCodes: ['is_income_at', 'is_net_profit'] },
];

const formatCurrency = (value: number | undefined | null): string => {
  if (value === undefined || value === null || isNaN(value)) return '--';
  const abs = Math.abs(value);
  const sign = value < 0 ? '-' : '';
  if (abs >= 1e9) return `${sign}£${(abs / 1e9).toFixed(1)}B`;
  if (abs >= 1e6) return `${sign}£${(abs / 1e6).toFixed(1)}M`;
  if (abs >= 1e3) return `${sign}£${(abs / 1e3).toFixed(0)}K`;
  return `${sign}£${abs.toFixed(0)}`;
};

export default function StatementsTab({ taxonomies }: Props) {
  const figures = taxonomies?.income_statement?.figures || [];

  // Get available years (ANNUAL only)
  const availableYears = useMemo(() => {
    const yearSet = new Set<number>();
    figures.forEach(f => {
      f.years?.forEach(y => {
        if (y.year && (y.report_type === 'ANNUAL' || !y.report_type)) {
          yearSet.add(y.year);
        }
      });
    });
    return Array.from(yearSet).sort((a, b) => b - a).slice(0, 5);
  }, [figures]);

  const [selectedYearIndex, setSelectedYearIndex] = useState(0);
  const selectedYear = availableYears[selectedYearIndex];

  const findValue = (codes: string[], year: number): number | null => {
    for (const code of codes) {
      const figure = figures.find(f => f.code === code);
      if (figure) {
        const yearData = figure.years?.find(y =>
          y.year === year && (y.report_type === 'ANNUAL' || !y.report_type)
        );
        if (yearData?.value !== undefined && yearData.value !== null) {
          return yearData.value;
        }
      }
    }
    return null;
  };

  if (!figures.length || !availableYears.length) {
    return (
      <View style={styles.container}>
        <View style={styles.emptyState}>
          <Ionicons name="document-text-outline" size={64} color="#4B5563" />
          <Text style={styles.emptyTitle}>Income Statement Unavailable</Text>
          <Text style={styles.emptyText}>
            Income statement data is not available for this stock.
          </Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Year Selector */}
      <View style={styles.yearSelector}>
        <Text style={styles.yearLabel}>Fiscal Year</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <View style={styles.yearPills}>
            {availableYears.map((year, index) => (
              <TouchableOpacity
                key={year}
                style={[styles.yearPill, index === selectedYearIndex && styles.yearPillActive]}
                onPress={() => setSelectedYearIndex(index)}
              >
                <Text style={[styles.yearPillText, index === selectedYearIndex && styles.yearPillTextActive]}>
                  {year}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </ScrollView>
      </View>

      {/* Income Statement */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Ionicons name="document-text-outline" size={16} color="#60A5FA" />
          <Text style={styles.sectionTitle}>Income Statement</Text>
        </View>
        <View style={styles.table}>
          {INCOME_FIELDS.map((field, idx) => {
            const value = findValue([field.code, ...field.altCodes], selectedYear);
            const isLast = idx === INCOME_FIELDS.length - 1;
            return (
              <View key={field.code} style={[styles.row, isLast && styles.rowLast]}>
                <Text style={styles.rowLabel}>{field.label}</Text>
                <Text style={[
                  styles.rowValue,
                  value !== null && value < 0 ? { color: '#F87171' } : undefined,
                ]}>
                  {formatCurrency(value)}
                </Text>
              </View>
            );
          })}
        </View>
      </View>

      {/* Margins */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Ionicons name="analytics-outline" size={16} color="#34D399" />
          <Text style={styles.sectionTitle}>Margins</Text>
        </View>
        <View style={styles.table}>
          {(() => {
            const revenue = findValue(['is_revenue_tot', 'is_revenue_net'], selectedYear);
            const grossProfit = findValue(['is_gross_profit'], selectedYear);
            const ebit = findValue(['is_ebit', 'is_op_income'], selectedYear);
            const netIncome = findValue(['is_net_income', 'is_income_at', 'is_net_profit'], selectedYear);

            const grossMargin = revenue && grossProfit ? (grossProfit / revenue) * 100 : null;
            const operatingMargin = revenue && ebit ? (ebit / revenue) * 100 : null;
            const netMargin = revenue && netIncome ? (netIncome / revenue) * 100 : null;

            const margins = [
              { label: 'Gross Margin', value: grossMargin },
              { label: 'Operating Margin', value: operatingMargin },
              { label: 'Net Margin', value: netMargin },
            ];

            return margins.map((m, idx) => (
              <View key={m.label} style={[styles.row, idx === margins.length - 1 && styles.rowLast]}>
                <Text style={styles.rowLabel}>{m.label}</Text>
                <Text style={[
                  styles.rowValue,
                  m.value !== null ? { color: m.value >= 0 ? '#34D399' : '#F87171' } : undefined,
                ]}>
                  {m.value !== null ? `${m.value.toFixed(1)}%` : '--'}
                </Text>
              </View>
            ));
          })()}
        </View>
      </View>

      <View style={styles.disclaimer}>
        <Ionicons name="information-circle-outline" size={14} color="#6B7280" />
        <Text style={styles.disclaimerText}>
          Income statement data sourced from annual reports. Values may differ from interim reports.
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
  yearSelector: { marginBottom: 16 },
  yearLabel: { color: '#9CA3AF', fontSize: 12, fontWeight: '600', marginBottom: 8, textTransform: 'uppercase', letterSpacing: 0.5 },
  yearPills: { flexDirection: 'row', gap: 8 },
  yearPill: {
    paddingHorizontal: 16, paddingVertical: 8, borderRadius: 20,
    backgroundColor: 'rgba(31, 41, 55, 0.6)', borderWidth: 1, borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  yearPillActive: { backgroundColor: '#3B82F6', borderColor: '#3B82F6' },
  yearPillText: { color: '#9CA3AF', fontSize: 13, fontWeight: '600' },
  yearPillTextActive: { color: '#FFFFFF' },
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
  rowLabel: { color: '#9CA3AF', fontSize: 13, fontWeight: '500', flex: 1 },
  rowValue: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
  disclaimer: {
    flexDirection: 'row', alignItems: 'flex-start',
    backgroundColor: 'rgba(31, 41, 55, 0.3)', borderRadius: 10, padding: 10, marginTop: 4,
  },
  disclaimerText: { color: '#6B7280', fontSize: 11, marginLeft: 6, flex: 1, lineHeight: 16 },
});
