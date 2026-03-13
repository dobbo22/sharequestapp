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
    balance_sheet?: { figures: TaxonomyFigure[] };
  } | null;
}

const ASSET_FIELDS = [
  { codes: ['bs_ass_total_2', 'bs_ass_total_1'], label: 'Total Assets' },
  { codes: ['bs_ass_cur_cash', 'bs_ass_cash_bank_bal'], label: 'Cash & Equivalents' },
  { codes: ['bs_ass_cur_tot_rec', 'bs_ass_cur_acc_rec'], label: 'Receivables' },
  { codes: ['bs_ass_cur_tot_inv'], label: 'Inventory' },
  { codes: ['bs_ass_ncur_ppe', 'bs_ass_ppe'], label: 'Property & Equipment' },
];

const LIABILITY_FIELDS = [
  { codes: ['bs_liab_total_2', 'bs_liab_total_1'], label: 'Total Liabilities' },
  { codes: ['bs_liab_cur_total'], label: 'Current Liabilities' },
  { codes: ['bs_liab_ncur_total'], label: 'Non-Current Liabilities' },
  { codes: ['bs_liab_ncur_debt', 'bs_liab_debt'], label: 'Long-term Debt' },
];

const EQUITY_FIELDS = [
  { codes: ['bs_eq_total'], label: 'Total Equity' },
  { codes: ['bs_eq_shareholders'], label: 'Shareholders Equity' },
  { codes: ['bs_eq_retained'], label: 'Retained Earnings' },
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

export default function BalanceSheetTab({ taxonomies }: Props) {
  const figures = taxonomies?.balance_sheet?.figures || [];

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
          <Ionicons name="layers-outline" size={64} color="#4B5563" />
          <Text style={styles.emptyTitle}>Balance Sheet Unavailable</Text>
          <Text style={styles.emptyText}>
            Balance sheet data is not available for this stock.
          </Text>
        </View>
      </View>
    );
  }

  // Calculate ratios
  const totalAssets = findValue(['bs_ass_total_2', 'bs_ass_total_1'], selectedYear);
  const totalLiabilities = findValue(['bs_liab_total_2', 'bs_liab_total_1'], selectedYear);
  const totalEquity = findValue(['bs_eq_total'], selectedYear);
  const currentLiabilities = findValue(['bs_liab_cur_total'], selectedYear);
  const currentAssetCodes = ['bs_ass_cur_total'];
  const currentAssets = findValue(currentAssetCodes, selectedYear);

  const debtToEquity = totalLiabilities && totalEquity && totalEquity !== 0
    ? totalLiabilities / totalEquity : null;
  const equityRatio = totalAssets && totalEquity && totalAssets !== 0
    ? (totalEquity / totalAssets) * 100 : null;
  const currentRatio = currentAssets && currentLiabilities && currentLiabilities !== 0
    ? currentAssets / currentLiabilities : null;

  const renderSection = (
    title: string,
    icon: string,
    iconColor: string,
    accentColor: string,
    fields: typeof ASSET_FIELDS,
  ) => (
    <View style={styles.section}>
      <View style={styles.sectionHeader}>
        <Ionicons name={icon as any} size={16} color={iconColor} />
        <Text style={styles.sectionTitle}>{title}</Text>
      </View>
      <View style={[styles.table, { borderLeftWidth: 3, borderLeftColor: accentColor }]}>
        {fields.map((field, idx) => {
          const value = findValue(field.codes, selectedYear);
          return (
            <View key={field.codes[0]} style={[styles.row, idx === fields.length - 1 && styles.rowLast]}>
              <Text style={styles.rowLabel}>{field.label}</Text>
              <Text style={[styles.rowValue, value !== null && value < 0 ? { color: '#F87171' } : undefined]}>
                {formatCurrency(value)}
              </Text>
            </View>
          );
        })}
      </View>
    </View>
  );

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

      {renderSection('Assets', 'wallet-outline', '#60A5FA', '#3B82F6', ASSET_FIELDS)}
      {renderSection('Liabilities', 'warning-outline', '#F87171', '#EF4444', LIABILITY_FIELDS)}
      {renderSection('Equity', 'shield-checkmark-outline', '#34D399', '#10B981', EQUITY_FIELDS)}

      {/* Calculated Ratios */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Ionicons name="calculator-outline" size={16} color="#FBBF24" />
          <Text style={styles.sectionTitle}>Key Ratios</Text>
        </View>
        <View style={styles.table}>
          <View style={styles.row}>
            <Text style={styles.rowLabel}>Debt-to-Equity</Text>
            <Text style={[styles.rowValue, debtToEquity !== null ? { color: debtToEquity > 2 ? '#F87171' : '#34D399' } : undefined]}>
              {debtToEquity !== null ? debtToEquity.toFixed(2) : '--'}
            </Text>
          </View>
          <View style={styles.row}>
            <Text style={styles.rowLabel}>Equity Ratio</Text>
            <Text style={[styles.rowValue, equityRatio !== null ? { color: equityRatio > 50 ? '#34D399' : '#F87171' } : undefined]}>
              {equityRatio !== null ? `${equityRatio.toFixed(1)}%` : '--'}
            </Text>
          </View>
          <View style={[styles.row, styles.rowLast]}>
            <Text style={styles.rowLabel}>Current Ratio</Text>
            <Text style={[styles.rowValue, currentRatio !== null ? { color: currentRatio > 1 ? '#34D399' : '#F87171' } : undefined]}>
              {currentRatio !== null ? currentRatio.toFixed(2) : '--'}
            </Text>
          </View>
        </View>
      </View>

      <View style={styles.disclaimer}>
        <Ionicons name="information-circle-outline" size={14} color="#6B7280" />
        <Text style={styles.disclaimerText}>
          Balance sheet data sourced from annual reports. All values in reporting currency.
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
