// Mobile trade ticker component
import React, { useEffect, useState, useRef } from 'react';
import { View, Text, ScrollView, TouchableOpacity, StyleSheet, Animated } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { apiService } from '../../services/api';

interface Trade {
  id: string;
  first_name?: string;
  username?: string;
  action: 'buy' | 'sell';
  quantity: number;
  symbol: string;
  companyname?: string; // Made optional to handle real API data
  price: number;
}

interface TradeTickerProps {
  limit?: number;
  refreshInterval?: number;
  onTradePress?: (symbol: string) => void;
}

export default function TradeTicker({ 
  limit = 15, 
  refreshInterval = 60000,
  onTradePress 
}: TradeTickerProps) {
  const [trades, setTrades] = useState<Trade[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const scrollX = useRef(new Animated.Value(0)).current;
  const [quotes, setQuotes] = useState<Record<string, { change: number }>>({});

  const loadTrades = async () => {
    try {
      setError(null);
      console.log('🔄 Loading trades using main app endpoint...');
      
      // Use the main app's transactions/recent endpoint directly
      const response = await apiService.request<{ trades?: Trade[] }>(`/transactions/recent?limit=${limit}`, {
        method: 'GET',
      });

      console.log('📡 Trades API response:', response);

      if (response.success && Array.isArray(response.data?.trades)) {
        const tradesData = response.data.trades || [];
        console.log('📊 Extracted trades data:', tradesData);
        setTrades(Array.isArray(tradesData) ? tradesData : []);
      } else {
        throw new Error(response.error || 'Failed to load trades');
      }
    } catch (err) {
      console.error('❌ Error loading trades:', err);
      setError(err instanceof Error ? err.message : 'Failed to load trades');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadTrades();
    
    if (refreshInterval > 0) {
      const interval = setInterval(loadTrades, refreshInterval);
      return () => clearInterval(interval);
    }
  }, [refreshInterval, limit]);

  // Fetch batch quotes for movement-based coloring when trades change
  useEffect(() => {
    const fetchBatch = async () => {
      try {
        if (!trades || trades.length === 0) return;
        const symbols = Array.from(new Set(trades.map(t => t.symbol))).filter(Boolean);
        if (symbols.length === 0) return;
        const resp = await apiService.getBatchPrices(symbols);
        if (resp.success && resp.data) {
          const map = resp.data as Record<string, any>;
          const next: Record<string, { change: number }> = {};
          symbols.forEach(sym => {
            const q = map[sym];
            if (q && typeof q.change === 'number') next[sym] = { change: q.change };
          });
          setQuotes(next);
        }
      } catch (_) {
        // ignore
      }
    };
    fetchBatch();
  }, [trades]);

  // Smooth continuous scrolling animation
  useEffect(() => {
    if (trades.length > 0 && !loading) {
      console.log('🔄 Starting smooth continuous scroll animation for', trades.length, 'trades');
      
      const cardWidth = 152; // card width + gap
      const totalWidth = trades.length * cardWidth;
      
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
  }, [trades, loading, scrollX]);

  const formatQuantity = (quantity: number) => {
    if (quantity >= 1000) {
      return `${(quantity / 1000).toFixed(1)}k`;
    }
    return quantity.toString();
  };

  // Preserve decimal pence precision and trim unnecessary trailing zeros.
  const formatPence = (value: number) => {
    const v = Number(value) || 0;
    const asFixed = v.toFixed(6);
    const trimmed = asFixed.replace(/(?:\.0+|(?<=\.[0-9]*[1-9])0+)$/, '').replace(/\.$/, '');
    return `${trimmed}p`;
  };

  const getMovementColor = (symbol: string) => {
    const ch = quotes[symbol]?.change;
    if (typeof ch !== 'number') return '#D1D5DB'; // gray-300 fallback
    if (ch > 0) return '#3B82F6'; // blue for up
    if (ch === 0) return '#10B981'; // green for unchanged
    return '#EF4444'; // red for down
  };

  const truncateName = (name: string | undefined | null, maxLength: number = 12) => {
    // Debug logging to understand what's being passed
    if (__DEV__) {
      console.log('truncateName called with:', name, typeof name);
    }
    
    // Handle all falsy values including null, undefined, empty string
    if (!name || typeof name !== 'string') {
      if (__DEV__) console.log('truncateName: returning Unknown Company for:', name);
      return 'Unknown Company';
    }
    
    const safeName = String(name).trim();
    if (!safeName) return 'Unknown Company';
    if (safeName.length <= maxLength) return safeName;
    return safeName.substring(0, maxLength - 3) + '...';
  };

  if (loading) {
    return (
      <View style={styles.container}>
        <LinearGradient
          colors={['rgba(17, 24, 39, 0.8)', 'rgba(31, 41, 55, 0.8)']}
          style={styles.loadingContainer}
        >
          <View style={styles.loadingContent}>
            <Ionicons name="pulse" size={24} color="#8B5CF6" />
            <Text style={styles.loadingText}>Loading trades...</Text>
          </View>
        </LinearGradient>
      </View>
    );
  }

  if (error || !Array.isArray(trades) || trades.length === 0) {
    return (
      <View style={styles.container}>
        <LinearGradient
          colors={['rgba(17, 24, 39, 0.8)', 'rgba(31, 41, 55, 0.8)']}
          style={styles.errorContainer}
        >
          <View style={styles.errorContent}>
            <Ionicons name="pulse" size={24} color="#8B5CF6" />
            <Text style={styles.errorText}>
              {error || 'No recent trades'}
            </Text>
            <Text style={styles.errorSubtext}>Be the first to start trading!</Text>
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
        {/* Smooth continuous scrolling trades */}
        <View style={styles.scrollContainer}>
          <Animated.View 
            style={[
              styles.scrollContent,
              {
                transform: [
                  {
                    translateX: scrollX.interpolate({
                      inputRange: [0, trades.length * 152],
                      outputRange: [0, -trades.length * 152],
                      extrapolate: 'clamp',
                    }),
                  },
                ],
              },
            ]}
          >
            {/* Render trades twice for continuous effect */}
            {[...trades, ...trades]
              .filter(trade => trade && trade.id && trade.symbol) // Filter out invalid trades
              .map((trade, index) => (
              <TouchableOpacity
                key={`${trade.id}-${index}`}
                style={[styles.tradeCard, index === 0 && styles.firstCard]}
                onPress={() => onTradePress?.(trade.symbol)}
                activeOpacity={0.8}
              >
              <LinearGradient
                colors={[
                  trade.action === 'buy' 
                    ? 'rgba(59, 130, 246, 0.2)' // Blue for buy
                    : 'rgba(239, 68, 68, 0.2)', // Red for sell
                  trade.action === 'buy' 
                    ? 'rgba(59, 130, 246, 0.1)' // Blue for buy
                    : 'rgba(239, 68, 68, 0.1)' // Red for sell
                ]}
                style={styles.tradeGradient}
              >
                {/* Action badge */}
                <View style={[
                  styles.actionBadge,
                  { backgroundColor: trade.action === 'buy' ? '#3B82F6' : '#EF4444' }
                ]}>
                  <Ionicons 
                    name={trade.action === 'buy' ? 'trending-up' : 'trending-down'} 
                    size={12} 
                    color="#FFFFFF" 
                  />
                </View>

                {/* Trade info - SWAPPED: Company name first (larger), then username (smaller, bold) */}
                <Text style={styles.companyName} numberOfLines={1}>
                  {truncateName(trade.companyname)}
                </Text>
                
                <Text style={styles.userName} numberOfLines={1}>
                  {trade.username || trade.first_name || 'Anonymous'}
                </Text>
                
                <View style={styles.actionRow}>
                  <Text style={[
                    styles.actionText,
                    { color: trade.action === 'buy' ? '#3B82F6' : '#EF4444' }
                  ]}>
                    {trade.action === 'buy' ? 'bought' : 'sold'}
                  </Text>
                  <Text style={styles.quantityText}>
                    {formatQuantity(trade.quantity)}
                  </Text>
                </View>
                
                {/* Price */}
                <View style={styles.priceContainer}>
                  <Text style={styles.symbolText}>{trade.symbol}</Text>
                  <Text style={[styles.priceText, { color: getMovementColor(trade.symbol) }]}>
                    {formatPence(trade.price)}
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
    borderColor: 'rgba(139, 92, 246, 0.3)',
    alignItems: 'center',
  },
  errorContent: {
    alignItems: 'center',
    gap: 8,
  },
  errorText: {
    color: '#C4B5FD',
    fontSize: 14,
    fontWeight: '600',
    textAlign: 'center',
  },
  errorSubtext: {
    color: '#9CA3AF',
    fontSize: 12,
    textAlign: 'center',
  },

  // Header
  header: {
    marginBottom: 12,
  },
  liveIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(139, 92, 246, 0.2)',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(139, 92, 246, 0.3)',
    alignSelf: 'flex-start',
    gap: 6,
  },
  liveDot: {
    width: 6,
    height: 6,
    backgroundColor: '#8B5CF6',
    borderRadius: 3,
  },
  liveText: {
    color: '#8B5CF6',
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
    gap: 12,
  },
  tradeCard: {
    width: 140, // INCREASED: Larger for better text visibility
    height: 95, // INCREASED: More space for content
    borderRadius: 12,
    overflow: 'hidden',
  },
  firstCard: {
    marginLeft: 0,
  },
  tradeGradient: {
    flex: 1,
    padding: 6, // COMPRESSED: Reduced padding
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  actionBadge: {
    position: 'absolute',
    top: 8,
    right: 8,
    width: 20,
    height: 20,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  userName: {
    fontSize: 12, // SMALLER: Reduced for secondary position
    fontWeight: 'bold',
    color: '#D1D5DB', // MUTED: Less prominent color
    marginBottom: 4,
    paddingRight: 24, // Account for action badge
  },
  actionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginBottom: 4,
  },
  actionText: {
    fontSize: 12,
    fontWeight: '600',
  },
  quantityText: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#60A5FA',
  },
  companyName: {
    fontSize: 14, // LARGER: Now the primary text
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 2, // REDUCED: Tighter spacing
  },
  priceContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  symbolText: {
    fontSize: 10,
    color: '#9CA3AF',
  },
  priceText: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FCD34D',
  },
});