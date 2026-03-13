// Mobile stocks ticker component
import React, { useEffect, useState, useRef } from 'react';
import { View, Text, ScrollView, TouchableOpacity, StyleSheet, Dimensions, Animated } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { apiService } from '../../services/api';

const { width } = Dimensions.get('window');

interface StockData {
  symbol: string;
  company_name: string;
  current_price: number;
  change_amount: number;
  change_percent: number;
  market_cap?: number;
}

interface StocksTickerProps {
  limit?: number;
  refreshInterval?: number;
  onStockPress?: (symbol: string) => void;
}

export default function StocksTicker({ 
  limit = 20, 
  refreshInterval = 60000,
  onStockPress 
}: StocksTickerProps) {
  const [stocks, setStocks] = useState<StockData[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const scrollX = useRef(new Animated.Value(0)).current;
  const scrollViewRef = useRef<ScrollView>(null);

  const isUKMarketOpen = (): boolean => {
    try {
      const now = new Date();
      const parts = new Intl.DateTimeFormat('en-GB', {
        timeZone: 'Europe/London',
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      }).formatToParts(now);
      const hh = Number(parts.find(p => p.type === 'hour')?.value || '0');
      const mm = Number(parts.find(p => p.type === 'minute')?.value || '0');
      const dow = new Intl.DateTimeFormat('en-GB', { timeZone: 'Europe/London', weekday: 'short' }).format(now);
      const isWeekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].includes(dow);
      const minutes = hh * 60 + mm;
      return isWeekday && minutes >= 480 && minutes <= 995; // 08:00 - 16:35
    } catch {
      return false;
    }
  };

  const loadStocks = async () => {
    try {
      setError(null);
      console.log('📈 [Mobile] Forcing price update for Top 100/250...');
      // 1. Force price update (identical to main app dashboard)
      await apiService.request('/prices/update-top250', { method: 'POST' });

      // 2. Fetch both Top 100 and Top 250 with fresh Infront prices/movement
      const top100Url = `/stocks/top100?includePrices=true&refresh=true`;
      const top250Url = `/stocks/top250?includePrices=true&refresh=true`;
      const [resp100, resp250] = await Promise.all([
        apiService.request(top100Url, { method: 'GET' }),
        apiService.request(top250Url, { method: 'GET' })
      ]);

      // Merge and dedupe by symbol
      const allStocksRaw = [
        ...((resp100 as any).stocks || (resp100 as any).data?.stocks || []),
        ...((resp250 as any).stocks || (resp250 as any).data?.stocks || [])
      ];
      const seen = new Set();
      const allStocks = allStocksRaw.filter((s: any) => {
        if (!s.symbol || seen.has(s.symbol)) return false;
        seen.add(s.symbol);
        return s.symbol.endsWith('.L');
      });

      let formattedStocks = allStocks.map((stock: any) => ({
        symbol: stock.symbol,
        company_name: stock.company_name ?? stock.companyname ?? stock.companyName ?? stock.longName ?? stock.shortName ?? stock.name ?? stock.symbol,
        current_price: Number(stock.current_price ?? stock.price ?? 0),
        change_amount: Number(stock.change_amount ?? stock.change ?? 0),
        change_percent: Number(stock.change_percent ?? stock.changePercent ?? 0),
        market_cap: Number(stock.marketCap ?? stock.market_cap ?? 0)
      }));

      if (limit > 0) {
        formattedStocks = formattedStocks.slice(0, limit);
      }

      setStocks(formattedStocks);
      setError(null);
    } catch (err) {
      console.error('❌ Error loading stocks:', err);
      // Only set error if we don't already have stocks data
      if (stocks.length === 0) {
        setError(err instanceof Error ? err.message : 'Failed to load stocks');
      } else {
        console.log('📈 Keeping existing stocks data despite error');
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    // Add small delay to stagger API calls
    const initialLoadTimer = setTimeout(() => {
      loadStocks();
    }, 1000); // 1 second delay
    
    let interval: NodeJS.Timeout;
    if (refreshInterval > 0) {
      interval = setInterval(loadStocks, refreshInterval);
    }
    
    return () => {
      clearTimeout(initialLoadTimer);
      if (interval) clearInterval(interval);
    };
  }, [refreshInterval, limit]);

  // Smooth continuous scrolling animation
  useEffect(() => {
    if (stocks.length > 0 && !loading) {
      console.log('📈 Starting smooth continuous scroll animation for', stocks.length, 'stocks');
      
      const cardWidth = 126; // UPDATED: card width (118) + gap (8) = 126
      const totalWidth = stocks.length * cardWidth;
      
      // Create smooth continuous scrolling animation
      const animateScroll = () => {
        scrollX.setValue(0);
        
        Animated.loop(
          Animated.timing(scrollX, {
            toValue: totalWidth,
            duration: totalWidth * 30, // FASTER: Reduced from 50 to 30 for faster scroll speed
            useNativeDriver: false,
          }),
          { iterations: -1 }
        ).start();
      };

      // Start animation after a short delay
      const timer = setTimeout(animateScroll, 1000);
      
      return () => {
        clearTimeout(timer);
        scrollX.stopAnimation();
      };
    }
  }, [stocks, loading, scrollX]);


  // Preserve decimal pence precision and trim unnecessary trailing zeros.
  const formatPence = (value: number) => {
    const v = Number(value) || 0;
    const asFixed = v.toFixed(6);
    const trimmed = asFixed.replace(/(?:\.0+|(?<=\.[0-9]*[1-9])0+)$/, '').replace(/\.$/, '');
    return `${trimmed}p`;
  };

  const formatChange = (change: number) => {
    const c = Number(change) || 0;
    const abs = Math.abs(c);
    const formatted = formatPence(abs);
    return c >= 0 ? `+${formatted}` : `-${formatted}`;
  };

  const formatPercent = (percent: number) => {
    const p = Number(percent) || 0;
    return p >= 0 ? `+${p.toFixed(1)}%` : `${p.toFixed(1)}%`;
  };

  const truncateName = (name: string, maxLength: number = 15) => {
    if (name.length <= maxLength) return name;
    return name.substring(0, maxLength - 3) + '...';
  };

  if (loading) {
    return (
      <View style={styles.container}>
        <LinearGradient
          colors={['rgba(17, 24, 39, 0.8)', 'rgba(31, 41, 55, 0.8)']}
          style={styles.loadingContainer}
        >
          <View style={styles.loadingContent}>
            <Ionicons name="trending-up" size={24} color="#3B82F6" />
            <Text style={styles.loadingText}>Loading stocks...</Text>
          </View>
        </LinearGradient>
      </View>
    );
  }

  if (error || stocks.length === 0) {
    return (
      <View style={styles.container}>
        <LinearGradient
          colors={['rgba(17, 24, 39, 0.8)', 'rgba(31, 41, 55, 0.8)']}
          style={styles.errorContainer}
        >
          <View style={styles.errorContent}>
            <Ionicons name="alert-circle-outline" size={24} color="#EF4444" />
            <Text style={styles.errorText}>
              {error || 'No stock data available'}
            </Text>
          </View>
        </LinearGradient>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <LinearGradient
        colors={['rgba(17, 24, 39, 0.8)', 'rgba(31, 41, 55, 0.8)']}
        style={styles.tickerContainer}
      >
        {/* Smooth continuous scrolling stocks */}
        <View style={styles.scrollContainer}>
          <Animated.View 
            style={[
              styles.scrollContent,
              {
                transform: [
                  {
                    translateX: scrollX.interpolate({
                      inputRange: [0, stocks.length * 126], // UPDATED: new card width (118 + 8 gap = 126)
                      outputRange: [0, -stocks.length * 126], // UPDATED: new card width (118 + 8 gap = 126)  
                      extrapolate: 'clamp',
                    }),
                  },
                ],
              },
            ]}
          >
            {/* Render stocks twice for continuous effect */}
            {[...stocks, ...stocks].map((stock, index) => (
              <TouchableOpacity
                key={`${stock.symbol}-${index}`}
                style={[styles.stockCard, index === 0 && styles.firstCard]}
                onPress={() => onStockPress?.(stock.symbol)}
                activeOpacity={0.8}
              >
                <LinearGradient
                  colors={
                    stock.change_percent > 0 
                      ? ['rgba(59, 130, 246, 0.2)', 'rgba(59, 130, 246, 0.1)']
                      : stock.change_percent < 0 
                        ? ['rgba(239, 68, 68, 0.2)', 'rgba(239, 68, 68, 0.1)']
                        : ['rgba(16, 185, 129, 0.2)', 'rgba(16, 185, 129, 0.1)']
                  }
                  style={styles.stockGradient}
                >
                  {/* Direction indicator */}
                  <View style={[
                    styles.directionBadge,
                    { backgroundColor: stock.change_percent > 0 ? '#3B82F6' : stock.change_percent < 0 ? '#EF4444' : '#22C55E' }
                  ]}>
                    <Ionicons 
                      name={stock.change_percent >= 0 ? 'trending-up' : 'trending-down'} 
                      size={12} 
                      color="#FFFFFF" 
                    />
                  </View>

                  {/* Company name top */}
                  <Text style={styles.stockName} numberOfLines={1}>
                    {truncateName(stock.company_name)}
                  </Text>
                  {/* Price, then symbol + movement */}
                  <View style={styles.priceContainer}>
                    <Text style={styles.stockPrice}>{formatPence(stock.current_price)}</Text>
                  </View>
                  <View style={styles.metaRow}>
                    <Text style={styles.stockSymbol}>{stock.symbol}</Text>
                    <Text style={styles.dot}>•</Text>
                    <Text style={[styles.stockChange, { color: stock.change_percent > 0 ? '#3B82F6' : stock.change_percent < 0 ? '#EF4444' : '#10B981' }]}>
                      {formatChange(stock.change_amount)}
                    </Text>
                    <Text style={styles.dot}>•</Text>
                    <Text style={[styles.stockChange, { color: stock.change_percent > 0 ? '#3B82F6' : stock.change_percent < 0 ? '#EF4444' : '#10B981' }]}>
                      {formatPercent(stock.change_percent)}
                    </Text>
                  </View>
                </LinearGradient>
              </TouchableOpacity>
            ))}
          </Animated.View>
        </View>
      </LinearGradient>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginVertical: 8,
  },
  tickerContainer: {
    borderRadius: 16,
    padding: 12,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.5)',
  },
  loadingContainer: {
    borderRadius: 16,
    padding: 20,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.5)',
    alignItems: 'center',
  },
  loadingContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  loadingText: {
    color: '#9CA3AF',
    fontSize: 16,
    fontWeight: '600',
  },
  errorContainer: {
    borderRadius: 16,
    padding: 20,
    borderWidth: 1,
    borderColor: 'rgba(239, 68, 68, 0.3)',
    alignItems: 'center',
  },
  errorContent: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  errorText: {
    color: '#FCA5A5',
    fontSize: 14,
    textAlign: 'center',
  },

  // Header
  header: {
    marginBottom: 12,
  },
  liveIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(59, 130, 246, 0.2)',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(59, 130, 246, 0.3)',
    alignSelf: 'flex-start',
    gap: 6,
  },
  liveDot: {
    width: 6,
    height: 6,
    backgroundColor: '#3B82F6',
    borderRadius: 3,
  },
  liveText: {
    color: '#3B82F6',
    fontSize: 12,
    fontWeight: '600',
  },

  // Scroll
  scrollContainer: {
    overflow: 'hidden',
  },
  scrollView: {
    marginHorizontal: -8,
  },
  scrollContent: {
    flexDirection: 'row',
    gap: 8, // COMPRESSED: Reduced gap between cards (was 12)
  },
  stockCard: {
    width: 118, // INCREASED: Match TradeTicker proportionally (140 -> 118 for consistency)
    height: 88, // INCREASED: Match TradeTicker proportionally (95 -> 88 for consistency)
    borderRadius: 12,
    overflow: 'hidden',
  },
  firstCard: {
    marginLeft: 0,
  },
  stockGradient: {
    flex: 1,
    padding: 6, // COMPRESSED: Further reduced padding
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  directionBadge: {
    position: 'absolute',
    top: 4, // COMPRESSED: Moved closer to top (was 8)
    right: 4, // COMPRESSED: Moved closer to edge (was 8)
    width: 18, // COMPRESSED: Made smaller (was 20)
    height: 18, // COMPRESSED: Made smaller (was 20)
    borderRadius: 9, // COMPRESSED: Updated for new size (was 10)
    alignItems: 'center',
    justifyContent: 'center',
  },
  stockName: {
    fontSize: 14, // REDUCED: Made company name smaller to match TradeTicker
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 4, // COMPRESSED: Reduced spacing (was 2)
    paddingRight: 20, // COMPRESSED: Account for smaller direction badge (was 24)
  },
  stockSymbol: {
    fontSize: 10, // DECREASED: Made symbol smaller (was 12) 
    color: '#9CA3AF',
    marginBottom: 4, // COMPRESSED: Reduced spacing (was 8)
  },
  priceContainer: {
    alignItems: 'flex-start',
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  dot: {
    color: '#6B7280',
    fontSize: 10,
    marginHorizontal: 2,
  },
  stockPrice: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FCD34D',
    marginBottom: 2,
  },
  stockChange: {
    fontSize: 12,
    fontWeight: '600',
  },
});