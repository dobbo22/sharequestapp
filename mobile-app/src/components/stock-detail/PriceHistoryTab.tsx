import React, { useState, useEffect, useMemo } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ActivityIndicator, Dimensions } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LineChart } from 'react-native-chart-kit';
import { apiService } from '../../services/api';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

interface Props {
  symbol: string;
}

interface Quote {
  date: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

const TIME_RANGES = [
  { label: '1W', days: 7 },
  { label: '1M', days: 30 },
  { label: '3M', days: 90 },
  { label: '6M', days: 180 },
  { label: '1Y', days: 365 },
];

export default function PriceHistoryTab({ symbol }: Props) {
  const [selectedRange, setSelectedRange] = useState(1); // Default 1M
  const [quotes, setQuotes] = useState<Quote[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchHistory = async (period: number) => {
    try {
      setLoading(true);
      setError(null);
      const response = await apiService.request(`/mobile/stocks/${symbol}/history?period=${period}`, { method: 'GET' }) as any;
      if (response.success && response.data?.quotes) {
        setQuotes(response.data.quotes as Quote[]);
      } else {
        setQuotes([]);
        setError('No price data available');
      }
    } catch (err) {
      console.error('Error fetching price history:', err);
      setError('Failed to load price history');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchHistory(TIME_RANGES[selectedRange].days);
  }, [selectedRange, symbol]);

  // Calculate summary stats
  const stats = useMemo(() => {
    if (!quotes.length) return null;
    const closes = quotes.map(q => q.close);
    const volumes = quotes.map(q => q.volume);
    const high = Math.max(...quotes.map(q => q.high));
    const low = Math.min(...quotes.map(q => q.low));
    const first = closes[0];
    const last = closes[closes.length - 1];
    const change = first > 0 ? ((last - first) / first) * 100 : 0;
    const avgVolume = volumes.reduce((a, b) => a + b, 0) / volumes.length;

    return { high, low, change, avgVolume, latest: last };
  }, [quotes]);

  // Prepare chart data - downsample if too many points
  const chartData = useMemo(() => {
    if (!quotes.length) return null;
    const maxPoints = 40;
    let sampled = quotes;
    if (quotes.length > maxPoints) {
      const step = Math.ceil(quotes.length / maxPoints);
      sampled = quotes.filter((_, i) => i % step === 0 || i === quotes.length - 1);
    }
    const closes = sampled.map(q => q.close);
    const labels = sampled.map((q, i) => {
      if (i === 0 || i === sampled.length - 1 || i === Math.floor(sampled.length / 2)) {
        const d = new Date(q.date);
        return `${d.getDate()}/${d.getMonth() + 1}`;
      }
      return '';
    });
    return { labels, datasets: [{ data: closes }] };
  }, [quotes]);

  const isPositive = stats ? stats.change >= 0 : true;

  const formatVolume = (vol: number) => {
    if (vol >= 1e6) return `${(vol / 1e6).toFixed(1)}M`;
    if (vol >= 1e3) return `${(vol / 1e3).toFixed(0)}K`;
    return vol.toFixed(0);
  };

  return (
    <View style={styles.container}>
      {/* Time Range Selector */}
      <View style={styles.rangeSelector}>
        {TIME_RANGES.map((range, index) => (
          <TouchableOpacity
            key={range.label}
            style={[styles.rangePill, index === selectedRange && styles.rangePillActive]}
            onPress={() => setSelectedRange(index)}
          >
            <Text style={[styles.rangePillText, index === selectedRange && styles.rangePillTextActive]}>
              {range.label}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {loading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#3B82F6" />
          <Text style={styles.loadingText}>Loading price data...</Text>
        </View>
      ) : error || !chartData ? (
        <View style={styles.emptyState}>
          <Ionicons name="bar-chart-outline" size={64} color="#4B5563" />
          <Text style={styles.emptyTitle}>{error || 'No Data'}</Text>
          <Text style={styles.emptyText}>
            Price history is not available for this time range.
          </Text>
        </View>
      ) : (
        <>
          {/* Chart */}
          <View style={styles.chartContainer}>
            <LineChart
              data={chartData}
              width={SCREEN_WIDTH - 32}
              height={200}
              withDots={false}
              withInnerLines={false}
              withOuterLines={false}
              withVerticalLabels={true}
              withHorizontalLabels={true}
              chartConfig={{
                backgroundColor: 'transparent',
                backgroundGradientFrom: 'rgba(31, 41, 55, 0.5)',
                backgroundGradientTo: 'rgba(31, 41, 55, 0.5)',
                color: () => isPositive ? 'rgba(52, 211, 153, 0.8)' : 'rgba(248, 113, 113, 0.8)',
                labelColor: () => '#6B7280',
                propsForBackgroundLines: {
                  strokeDasharray: '',
                  stroke: 'rgba(75, 85, 99, 0.15)',
                },
                fillShadowGradientFrom: isPositive ? '#34D399' : '#F87171',
                fillShadowGradientTo: 'transparent',
                fillShadowGradientFromOpacity: 0.3,
                fillShadowGradientToOpacity: 0,
              } as any}
              bezier
              style={styles.chart}
            />
          </View>

          {/* Summary Stats */}
          {stats && (
            <View style={styles.statsGrid}>
              <View style={styles.statCard}>
                <Text style={styles.statLabel}>Period Change</Text>
                <Text style={[styles.statValue, { color: isPositive ? '#34D399' : '#F87171' }]}>
                  {isPositive ? '+' : ''}{stats.change.toFixed(2)}%
                </Text>
              </View>
              <View style={styles.statCard}>
                <Text style={styles.statLabel}>High</Text>
                <Text style={styles.statValue}>{stats.high.toFixed(2)}p</Text>
              </View>
              <View style={styles.statCard}>
                <Text style={styles.statLabel}>Low</Text>
                <Text style={styles.statValue}>{stats.low.toFixed(2)}p</Text>
              </View>
              <View style={styles.statCard}>
                <Text style={styles.statLabel}>Avg Volume</Text>
                <Text style={styles.statValue}>{formatVolume(stats.avgVolume)}</Text>
              </View>
            </View>
          )}
        </>
      )}

      <View style={styles.disclaimer}>
        <Ionicons name="information-circle-outline" size={14} color="#6B7280" />
        <Text style={styles.disclaimerText}>
          Historical prices are delayed and provided for informational purposes only.
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  rangeSelector: { flexDirection: 'row', justifyContent: 'center', gap: 8, marginBottom: 16 },
  rangePill: {
    paddingHorizontal: 16, paddingVertical: 8, borderRadius: 20,
    backgroundColor: 'rgba(31, 41, 55, 0.6)', borderWidth: 1, borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  rangePillActive: { backgroundColor: '#3B82F6', borderColor: '#3B82F6' },
  rangePillText: { color: '#9CA3AF', fontSize: 13, fontWeight: '600' },
  rangePillTextActive: { color: '#FFFFFF' },
  loadingContainer: { alignItems: 'center', paddingVertical: 60 },
  loadingText: { color: '#9CA3AF', marginTop: 12, fontSize: 14 },
  emptyState: { alignItems: 'center', justifyContent: 'center', paddingVertical: 60 },
  emptyTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: '600', marginTop: 16, marginBottom: 8 },
  emptyText: { color: '#9CA3AF', fontSize: 14, textAlign: 'center', paddingHorizontal: 40 },
  chartContainer: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    overflow: 'hidden',
    marginBottom: 16,
    alignItems: 'center',
    paddingTop: 8,
  },
  chart: { borderRadius: 12 },
  statsGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10, marginBottom: 16 },
  statCard: {
    flex: 1,
    minWidth: '45%' as any,
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    padding: 14,
    alignItems: 'center',
  },
  statLabel: { color: '#9CA3AF', fontSize: 11, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.3, marginBottom: 4 },
  statValue: { color: '#FFFFFF', fontSize: 16, fontWeight: 'bold' },
  disclaimer: {
    flexDirection: 'row', alignItems: 'flex-start',
    backgroundColor: 'rgba(31, 41, 55, 0.3)', borderRadius: 10, padding: 10, marginTop: 4,
  },
  disclaimerText: { color: '#6B7280', fontSize: 11, marginLeft: 6, flex: 1, lineHeight: 16 },
});
