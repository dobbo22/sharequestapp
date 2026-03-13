import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withRepeat,
  Easing,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { apiService } from '../../services/api';
import { colors, spacing, radii, typography, glassStyle } from '../../lib/theme';

interface TickerStock {
  symbol: string;
  name: string;
  price: number;
  changePercent: number;
}

const ITEM_WIDTH = 130;
const ITEM_MARGIN = 8;
const SPEED = 40; // pixels per second

const StockTicker: React.FC = () => {
  const [stocks, setStocks] = useState<TickerStock[]>([]);
  const [loading, setLoading] = useState(true);
  const translateX = useSharedValue(0);

  useEffect(() => {
    const fetchStocks = async () => {
      setLoading(true);
      try {
        const res = await apiService.request('/mobile/stocks/ftse100?limit=20', { method: 'GET' });
        if (res.success && Array.isArray(res.data.stocks)) {
          setStocks(res.data.stocks.map((s: any) => ({
            symbol: s.symbol,
            name: s.name || s.companyName || s.companyname || s.symbol,
            price: s.price || s.lastPrice || 0,
            changePercent: s.changePercent || 0,
          })));
        }
      } finally {
        setLoading(false);
      }
    };
    fetchStocks();
    const interval = setInterval(fetchStocks, 60000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (stocks.length === 0) return;

    const oneSetWidth = stocks.length * (ITEM_WIDTH + ITEM_MARGIN);
    const duration = (oneSetWidth / SPEED) * 1000;

    translateX.value = 0;
    translateX.value = withRepeat(
      withTiming(-oneSetWidth, {
        duration,
        easing: Easing.linear,
      }),
      -1, // infinite
      false // don't reverse
    );
  }, [stocks]);

  const animStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }],
  }));

  if (loading || stocks.length === 0) {
    return (
      <View style={styles.loadingContainer}>
        <Text style={styles.loading}>Loading market data...</Text>
      </View>
    );
  }

  // Render 3 copies for seamless loop
  const tripled = [...stocks, ...stocks, ...stocks];

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Ionicons name="trending-up" size={16} color={colors.textSecondary} />
        <Text style={styles.headerLabel}>Top Stocks</Text>
      </View>
      <View style={styles.tickerWrapper}>
        {/* Left fade */}
        <View style={styles.fadeLeft} />
        <Animated.View style={[styles.strip, animStyle]}>
          {tripled.map((stock, idx) => {
            const isUp = stock.changePercent > 0;
            const isDown = stock.changePercent < 0;
            const changeColor = isUp ? colors.success : isDown ? colors.danger : colors.warning;

            return (
              <View key={idx} style={styles.tickerItem}>
                <Text style={styles.tickerName} numberOfLines={1}>{stock.name}</Text>
                <Text style={styles.tickerPrice}>{stock.price.toFixed(2)}p</Text>
                <View style={[styles.changeBadge, { backgroundColor: `${changeColor}20` }]}>
                  <Ionicons
                    name={isUp ? 'caret-up' : isDown ? 'caret-down' : 'remove'}
                    size={10}
                    color={changeColor}
                  />
                  <Text style={[styles.tickerChange, { color: changeColor }]}>
                    {isUp ? '+' : ''}{stock.changePercent.toFixed(2)}%
                  </Text>
                </View>
              </View>
            );
          })}
        </Animated.View>
        {/* Right fade */}
        <View style={styles.fadeRight} />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {},
  loadingContainer: {
    padding: spacing.md,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: spacing.sm,
  },
  headerLabel: {
    color: colors.textSecondary,
    fontSize: typography.sm,
    fontWeight: '600',
    letterSpacing: 1,
  },
  tickerWrapper: {
    overflow: 'hidden',
    width: '100%',
    position: 'relative',
  },
  fadeLeft: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    width: 20,
    zIndex: 2,
    backgroundColor: 'transparent',
  },
  fadeRight: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    width: 20,
    zIndex: 2,
    backgroundColor: 'transparent',
  },
  strip: {
    flexDirection: 'row',
  },
  tickerItem: {
    ...glassStyle(0.5),
    borderRadius: radii.sm,
    padding: 10,
    marginRight: ITEM_MARGIN,
    alignItems: 'center',
    width: ITEM_WIDTH,
  },
  tickerName: {
    color: colors.textPrimary,
    fontWeight: 'bold',
    fontSize: typography.sm,
  },
  tickerPrice: {
    color: colors.textSecondary,
    fontSize: typography.sm,
    marginTop: 3,
  },
  changeBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: radii.sm,
    marginTop: 4,
  },
  tickerChange: {
    fontSize: typography.xs,
    fontWeight: '600',
  },
  loading: {
    color: colors.textSecondary,
    fontSize: typography.body,
  },
});

export default StockTicker;
