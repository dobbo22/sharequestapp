import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

interface StockData {
  symbol: string;
  companyName: string;
  quote: {
    price: number;
    change: number;
    changePercent: number;
  };
  profile: {
    sector: string;
    marketCap?: number;
  };
}

interface FundamentalsData {
  peRatio?: number;
  eps?: number;
  dividendYield?: number;
  marketCap?: number;
  revenue?: number;
  netIncome?: number;
  debtToEquity?: number;
  currentRatio?: number;
  beta?: number;
  fiftyTwoWeekHigh?: number;
  fiftyTwoWeekLow?: number;
  profitMargin?: number;
  returnOnEquity?: number;
  returnOnAssets?: number;
  priceToBook?: number;
  priceTosales?: number;
}

interface Props {
  stockData: StockData;
  fundamentals: FundamentalsData | null;
}

const formatValue = (value?: number, suffix = '', decimals = 2) => {
  if (value === undefined || value === null || isNaN(value)) return '--';
  return `${value.toFixed(decimals)}${suffix}`;
};

const formatLargeNumber = (num?: number) => {
  if (!num) return '--';
  if (num >= 1e12) return `£${(num / 1e12).toFixed(2)}T`;
  if (num >= 1e9) return `£${(num / 1e9).toFixed(2)}B`;
  if (num >= 1e6) return `£${(num / 1e6).toFixed(2)}M`;
  if (num >= 1e3) return `£${(num / 1e3).toFixed(2)}K`;
  return `£${num.toFixed(0)}`;
};

const getValueColor = (value?: number, greenIfPositive = true, threshold = 0) => {
  if (value === undefined || value === null) return '#FFFFFF';
  if (greenIfPositive) {
    return value > threshold ? '#34D399' : value < threshold ? '#F87171' : '#FFFFFF';
  }
  return value < threshold ? '#34D399' : value > threshold ? '#F87171' : '#FFFFFF';
};

function TableRow({ label, value, valueColor, isLast }: { label: string; value: string; valueColor?: string; isLast?: boolean }) {
  return (
    <View style={[tableStyles.row, isLast && tableStyles.rowLast]}>
      <Text style={tableStyles.label}>{label}</Text>
      <Text style={[tableStyles.value, valueColor ? { color: valueColor } : undefined]}>{value}</Text>
    </View>
  );
}

function SectionHeader({ icon, iconColor, title }: { icon: string; iconColor: string; title: string }) {
  return (
    <View style={styles.sectionHeader}>
      <Ionicons name={icon as any} size={16} color={iconColor} />
      <Text style={styles.sectionTitle}>{title}</Text>
    </View>
  );
}

export default function FinancialsTab({ stockData, fundamentals }: Props) {
  if (!fundamentals) {
    return (
      <View style={styles.container}>
        <View style={styles.emptyState}>
          <Ionicons name="bar-chart-outline" size={64} color="#4B5563" />
          <Text style={styles.emptyTitle}>Financial Data Unavailable</Text>
          <Text style={styles.emptyText}>
            Detailed financial information is not available for this stock at this time.
          </Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Valuation */}
      <View style={styles.section}>
        <SectionHeader icon="calculator-outline" iconColor="#60A5FA" title="Valuation" />
        <View style={tableStyles.table}>
          <TableRow label="P/E Ratio" value={formatValue(fundamentals.peRatio)} valueColor={getValueColor(fundamentals.peRatio)} />
          <TableRow label="Price to Book" value={formatValue(fundamentals.priceToBook)} />
          <TableRow label="Price to Sales" value={formatValue(fundamentals.priceTosales)} />
          <TableRow label="EPS" value={formatValue(fundamentals.eps, 'p')} valueColor={getValueColor(fundamentals.eps)} isLast />
        </View>
      </View>

      {/* Profitability */}
      <View style={styles.section}>
        <SectionHeader icon="trending-up-outline" iconColor="#34D399" title="Profitability" />
        <View style={tableStyles.table}>
          <TableRow
            label="Profit Margin"
            value={fundamentals.profitMargin != null ? formatValue(fundamentals.profitMargin * 100, '%') : '--'}
            valueColor={getValueColor(fundamentals.profitMargin)}
          />
          <TableRow
            label="Return on Equity"
            value={fundamentals.returnOnEquity != null ? formatValue(fundamentals.returnOnEquity * 100, '%') : '--'}
            valueColor={getValueColor(fundamentals.returnOnEquity)}
          />
          <TableRow
            label="Return on Assets"
            value={fundamentals.returnOnAssets != null ? formatValue(fundamentals.returnOnAssets * 100, '%') : '--'}
            valueColor={getValueColor(fundamentals.returnOnAssets)}
          />
          <TableRow label="Revenue" value={formatLargeNumber(fundamentals.revenue)} isLast />
        </View>
      </View>

      {/* Financial Health */}
      <View style={styles.section}>
        <SectionHeader icon="shield-checkmark-outline" iconColor="#FBBF24" title="Financial Health" />
        <View style={tableStyles.table}>
          <TableRow
            label="Debt to Equity"
            value={formatValue(fundamentals.debtToEquity)}
            valueColor={getValueColor(fundamentals.debtToEquity, false, 1)}
          />
          <TableRow
            label="Current Ratio"
            value={formatValue(fundamentals.currentRatio)}
            valueColor={getValueColor(fundamentals.currentRatio)}
          />
          <TableRow label="Beta" value={formatValue(fundamentals.beta)} />
          <TableRow label="Dividend Yield" value={formatValue(fundamentals.dividendYield, '%')} isLast />
        </View>
      </View>

      {/* Disclaimer */}
      <View style={styles.disclaimer}>
        <Ionicons name="information-circle-outline" size={14} color="#6B7280" />
        <Text style={styles.disclaimerText}>
          Financial data is provided for informational purposes only and may be delayed.
        </Text>
      </View>
    </View>
  );
}

const tableStyles = StyleSheet.create({
  table: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 14,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.2)',
  },
  rowLast: {
    borderBottomWidth: 0,
  },
  label: {
    color: '#9CA3AF',
    fontSize: 13,
    fontWeight: '500',
  },
  value: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
});

const styles = StyleSheet.create({
  container: { padding: 16 },
  section: { marginBottom: 20 },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  sectionTitle: {
    color: '#D1D5DB',
    fontSize: 14,
    fontWeight: '600',
    marginLeft: 6,
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
  },
  emptyTitle: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
    marginTop: 16,
    marginBottom: 8,
  },
  emptyText: {
    color: '#9CA3AF',
    fontSize: 14,
    textAlign: 'center',
    paddingHorizontal: 40,
  },
  disclaimer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    backgroundColor: 'rgba(31, 41, 55, 0.3)',
    borderRadius: 10,
    padding: 10,
    marginTop: 4,
  },
  disclaimerText: {
    color: '#6B7280',
    fontSize: 11,
    marginLeft: 6,
    flex: 1,
    lineHeight: 16,
  },
});
