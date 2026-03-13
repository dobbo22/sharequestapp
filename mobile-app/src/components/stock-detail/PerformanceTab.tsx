import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';

interface PerformanceData {
  oneWeek: number | null;
  oneMonth: number | null;
  threeMonth: number | null;
  sixMonth: number | null;
  oneYear: number | null;
  ytd: number | null;
}

interface FiftyTwoWeekData {
  high: number | null;
  low: number | null;
}

interface Props {
  performance: PerformanceData | null;
  fiftyTwoWeek: FiftyTwoWeekData | null;
  currentPrice: number;
}

const PERIOD_CONFIG: { key: keyof PerformanceData; label: string; color: string }[] = [
  { key: 'oneWeek', label: '1 Week', color: '#3B82F6' },
  { key: 'oneMonth', label: '1 Month', color: '#10B981' },
  { key: 'threeMonth', label: '3 Month', color: '#8B5CF6' },
  { key: 'sixMonth', label: '6 Month', color: '#F59E0B' },
  { key: 'oneYear', label: '1 Year', color: '#EF4444' },
  { key: 'ytd', label: 'YTD', color: '#6366F1' },
];

function formatPrice(pence?: number | null) {
  if (pence == null) return '--';
  return `${pence.toFixed(2)}p`;
}

export default function PerformanceTab({ performance, fiftyTwoWeek, currentPrice }: Props) {
  const hasPerformance = performance && PERIOD_CONFIG.some(p => performance[p.key] != null);
  const has52Week = fiftyTwoWeek && (fiftyTwoWeek.high != null || fiftyTwoWeek.low != null);

  if (!hasPerformance && !has52Week) {
    return (
      <View style={styles.container}>
        <View style={styles.emptyContainer}>
          <MaterialCommunityIcons name="chart-timeline-variant" size={48} color="#4B5563" />
          <Text style={styles.emptyText}>No performance data available</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Performance Grid */}
      {hasPerformance && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Performance</Text>
          <View style={styles.grid}>
            {PERIOD_CONFIG.map(({ key, label, color }) => {
              const value = performance![key];
              if (value == null) return null;
              const isPositive = value >= 0;
              return (
                <View key={key} style={[styles.perfCard, { borderColor: `${color}40` }]}>
                  <Text style={[styles.perfLabel, { color: `${color}CC` }]}>{label}</Text>
                  <View style={styles.perfValueRow}>
                    <MaterialCommunityIcons
                      name={isPositive ? 'trending-up' : 'trending-down'}
                      size={16}
                      color={isPositive ? '#10B981' : '#EF4444'}
                    />
                    <Text style={[styles.perfValue, { color: isPositive ? '#10B981' : '#EF4444' }]}>
                      {isPositive ? '+' : ''}{value.toFixed(2)}%
                    </Text>
                  </View>
                </View>
              );
            })}
          </View>
        </View>
      )}

      {/* 52-Week Range */}
      {has52Week && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>52-Week Range</Text>
          <View style={styles.rangeCard}>
            <View style={styles.rangeLabels}>
              <View>
                <Text style={styles.rangeSubLabel}>Low</Text>
                <Text style={styles.rangeLow}>{formatPrice(fiftyTwoWeek!.low)}</Text>
              </View>
              <View style={{ alignItems: 'center' }}>
                <Text style={styles.rangeSubLabel}>Current</Text>
                <Text style={styles.rangeCurrent}>{formatPrice(currentPrice)}</Text>
              </View>
              <View style={{ alignItems: 'flex-end' }}>
                <Text style={styles.rangeSubLabel}>High</Text>
                <Text style={styles.rangeHigh}>{formatPrice(fiftyTwoWeek!.high)}</Text>
              </View>
            </View>
            <View style={styles.rangeBar}>
              <View style={styles.rangeTrack} />
              {fiftyTwoWeek!.low != null && fiftyTwoWeek!.high != null && fiftyTwoWeek!.high !== fiftyTwoWeek!.low && (
                <View
                  style={[
                    styles.rangeIndicator,
                    {
                      left: `${Math.min(100, Math.max(0,
                        ((currentPrice - fiftyTwoWeek!.low!) /
                        (fiftyTwoWeek!.high! - fiftyTwoWeek!.low!)) * 100
                      ))}%`,
                    },
                  ]}
                />
              )}
            </View>
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  section: { marginBottom: 20 },
  sectionTitle: {
    color: '#9CA3AF',
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 8,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  perfCard: {
    width: '47%',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 14,
    borderWidth: 1,
  },
  perfLabel: {
    fontSize: 12,
    fontWeight: '600',
    marginBottom: 6,
  },
  perfValueRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  perfValue: {
    fontSize: 18,
    fontWeight: 'bold',
  },
  rangeCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  rangeLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  rangeSubLabel: { color: '#6B7280', fontSize: 10, fontWeight: '600', textTransform: 'uppercase', marginBottom: 2 },
  rangeLow: { color: '#F87171', fontSize: 14, fontWeight: 'bold' },
  rangeCurrent: { color: '#60A5FA', fontSize: 14, fontWeight: 'bold' },
  rangeHigh: { color: '#34D399', fontSize: 14, fontWeight: 'bold' },
  rangeBar: {
    height: 6,
    backgroundColor: 'rgba(75, 85, 99, 0.4)',
    borderRadius: 3,
    position: 'relative',
  },
  rangeTrack: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    borderRadius: 3,
  },
  rangeIndicator: {
    position: 'absolute',
    top: -5,
    width: 16,
    height: 16,
    backgroundColor: '#3B82F6',
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#FFFFFF',
    marginLeft: -8,
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingTop: 60,
  },
  emptyText: {
    color: '#9CA3AF',
    fontSize: 16,
    marginTop: 16,
  },
});
