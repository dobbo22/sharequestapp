import React, { useState, useEffect, useCallback } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Dimensions, ActivityIndicator } from 'react-native';
import { LineChart } from 'react-native-chart-kit';
import { apiService } from '../../services/api';

const { width } = Dimensions.get('window');

interface ChartDataPoint {
  date: string;
  value: number;
}

interface PortfolioChartProps {
  data?: ChartDataPoint[];
  loading?: boolean;
  color?: string;
  initialBalance?: number;
  portfolioType?: string;
}

type TimeRange = '7D' | '30D' | '90D' | '1Y';

const TIME_RANGES: TimeRange[] = ['7D', '30D', '90D', '1Y'];

export default function PortfolioChart({
  data,
  loading: externalLoading = false,
  color = '#3B82F6',
  initialBalance = 10000000, // 100,000 in pence
  portfolioType = 'default'
}: PortfolioChartProps) {
  const [selectedRange, setSelectedRange] = useState<TimeRange>('30D');
  const [performanceData, setPerformanceData] = useState<ChartDataPoint[]>([]);
  const [loading, setLoading] = useState(false);

  // Fetch real performance data
  const fetchPerformanceData = useCallback(async () => {
    if (data && data.length > 0) return; // Use provided data if available

    const days = selectedRange === '7D' ? 7 : selectedRange === '30D' ? 30 : selectedRange === '90D' ? 90 : 365;

    setLoading(true);
    try {
      const response = await apiService.getPortfolioPerformance(portfolioType, days);
      if (response.success && response.data && Array.isArray(response.data) && response.data.length > 0) {
        setPerformanceData(response.data.map((d: any) => ({
          date: d.date,
          value: d.value
        })));
      } else {
        // Fallback to generated data if API returns empty
        setPerformanceData([]);
      }
    } catch (err) {
      console.error('Error fetching performance data:', err);
      setPerformanceData([]);
    } finally {
      setLoading(false);
    }
  }, [portfolioType, selectedRange, data]);

  useEffect(() => {
    fetchPerformanceData();
  }, [fetchPerformanceData]);

  // Generate fallback data if no real data available
  const generateFallbackData = (): ChartDataPoint[] => {
    const days = selectedRange === '7D' ? 7 : selectedRange === '30D' ? 30 : selectedRange === '90D' ? 90 : 365;
    const dataPoints: ChartDataPoint[] = [];

    for (let i = days; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);

      // Flat line at initial balance when no real data
      dataPoints.push({
        date: date.toISOString().split('T')[0],
        value: initialBalance,
      });
    }

    return dataPoints;
  };

  // Use provided data > fetched data > fallback
  const chartData = data && data.length > 0
    ? data
    : performanceData.length > 0
      ? performanceData
      : generateFallbackData();

  // Filter data based on selected range
  const getFilteredData = () => {
    const days = selectedRange === '7D' ? 7 : selectedRange === '30D' ? 30 : selectedRange === '90D' ? 90 : 365;
    return chartData.slice(-Math.min(days + 1, chartData.length));
  };

  const filteredData = getFilteredData();

  // Calculate chart values
  const values = filteredData.map(d => d.value / 100); // Convert pence to pounds
  const labels = filteredData.map((d, i) => {
    // Show fewer labels on mobile
    const totalPoints = filteredData.length;
    const showEvery = totalPoints <= 7 ? 1 : totalPoints <= 14 ? 2 : totalPoints <= 30 ? 5 : 10;
    if (i % showEvery === 0 || i === totalPoints - 1) {
      const date = new Date(d.date);
      return `${date.getDate()}/${date.getMonth() + 1}`;
    }
    return '';
  });

  // Calculate performance
  const startValue = filteredData[0]?.value || initialBalance;
  const endValue = filteredData[filteredData.length - 1]?.value || initialBalance;
  const change = endValue - startValue;
  const changePercent = startValue > 0 ? (change / startValue) * 100 : 0;
  const isPositive = change >= 0;

  const formatCurrency = (pence: number) => {
    const pounds = pence / 100;
    if (pounds >= 1000) {
      return `£${(pounds / 1000).toFixed(1)}k`;
    }
    return `£${pounds.toFixed(0)}`;
  };

  const isLoading = loading || externalLoading;

  if (isLoading) {
    return (
      <View style={styles.container}>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="small" color={color} />
          <Text style={styles.loadingText}>Loading chart...</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Time Range Selector */}
      <View style={styles.rangeSelector}>
        {TIME_RANGES.map((range) => (
          <TouchableOpacity
            key={range}
            style={[
              styles.rangeButton,
              selectedRange === range && { backgroundColor: `${color}30`, borderColor: color },
            ]}
            onPress={() => setSelectedRange(range)}
          >
            <Text style={[styles.rangeText, selectedRange === range && { color }]}>
              {range}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {/* Performance Summary */}
      <View style={styles.performanceSummary}>
        <Text style={styles.performanceLabel}>Performance ({selectedRange})</Text>
        <View style={styles.performanceValues}>
          <Text style={[styles.performanceChange, { color: isPositive ? '#10B981' : '#EF4444' }]}>
            {isPositive ? '+' : ''}{formatCurrency(change)} ({changePercent.toFixed(2)}%)
          </Text>
        </View>
      </View>

      {/* Chart */}
      <View style={styles.chartContainer}>
        <LineChart
          data={{
            labels: labels.filter((_, i) => i % Math.ceil(labels.length / 5) === 0 || i === labels.length - 1),
            datasets: [{ data: values.length > 0 ? values : [0] }],
          }}
          width={width - 60}
          height={180}
          chartConfig={{
            backgroundColor: 'transparent',
            backgroundGradientFrom: 'transparent',
            backgroundGradientTo: 'transparent',
            decimalPlaces: 0,
            color: (opacity = 1) => {
              const hex = color.replace('#', '');
              const r = parseInt(hex.substring(0, 2), 16);
              const g = parseInt(hex.substring(2, 4), 16);
              const b = parseInt(hex.substring(4, 6), 16);
              return `rgba(${r}, ${g}, ${b}, ${Math.min(1, opacity * 1.3)})`;
            },
            labelColor: () => '#9CA3AF',
            style: { borderRadius: 16 },
            propsForDots: {
              r: '3',
              strokeWidth: '2',
              stroke: color,
              fill: '#FFFFFF',
            },
            propsForBackgroundLines: {
              strokeDasharray: '',
              stroke: 'rgba(75, 85, 99, 0.3)',
              strokeWidth: 1,
            },
            strokeWidth: 3,
            fillShadowGradientFrom: color,
            fillShadowGradientTo: 'transparent',
            fillShadowGradientFromOpacity: 0.5,
            fillShadowGradientToOpacity: 0.05,
          }}
          bezier
          style={styles.chart}
          withInnerLines={true}
          withOuterLines={false}
          withVerticalLines={false}
          withHorizontalLines={true}
          withVerticalLabels={true}
          withHorizontalLabels={true}
          fromZero={false}
          yAxisLabel="£"
          yAxisSuffix=""
          formatYLabel={(value) => {
            const num = parseFloat(value);
            if (num >= 1000) return `${(num / 1000).toFixed(0)}k`;
            return `${num.toFixed(0)}`;
          }}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginBottom: 20,
  },
  loadingContainer: {
    height: 250,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    color: '#9CA3AF',
    fontSize: 14,
    marginTop: 8,
  },
  rangeSelector: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginBottom: 16,
  },
  rangeButton: {
    paddingHorizontal: 18,
    paddingVertical: 10,
    borderRadius: 20,
    borderWidth: 1.5,
    borderColor: 'rgba(75, 85, 99, 0.5)',
    marginHorizontal: 4,
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
  },
  rangeText: {
    color: '#9CA3AF',
    fontSize: 14,
    fontWeight: '700',
  },
  performanceSummary: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
    paddingHorizontal: 4,
  },
  performanceLabel: {
    color: '#D1D5DB',
    fontSize: 14,
    fontWeight: '500',
  },
  performanceValues: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  performanceChange: {
    fontSize: 17,
    fontWeight: '700',
  },
  chartContainer: {
    alignItems: 'center',
    marginLeft: -10,
    shadowColor: '#3B82F6',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 12,
    elevation: 5,
  },
  chart: {
    borderRadius: 16,
  },
});
