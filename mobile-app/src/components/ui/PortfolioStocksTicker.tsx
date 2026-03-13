import { formatPence } from '../../lib/utils';
// Portfolio stocks ticker component - shows user's current holdings
import React, { useEffect, useState, useRef } from 'react';
import { View, Text, ScrollView, TouchableOpacity, StyleSheet, Dimensions, Animated } from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { apiService } from '../../services/api';

const { width } = Dimensions.get('window');

interface PortfolioStock {
  symbol: string;
  companyname: string;
  quantity: number;
  averagePrice: number;
  currentPrice: number;
  totalValue: number;
  profitLoss: number;
  profitLossPercent: number;
  portfolio_type?: string;
}

interface PortfolioStocksTickerProps {
  refreshInterval?: number;
  onStockPress?: (symbol: string) => void;
}

export default function PortfolioStocksTicker({ 
  refreshInterval = 120000,
  onStockPress 
}: PortfolioStocksTickerProps) {
  const [portfolioStocks, setPortfolioStocks] = useState<PortfolioStock[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const scrollX = useRef(new Animated.Value(0)).current;

  const loadPortfolioStocks = async () => {
    try {
      setError(null);
      console.log('📊 Loading portfolio stocks...');
      
      // Get holdings from all portfolio types in parallel to reduce total time
      const portfolioTypes = ['default', 'weekly', 'monthly', 'annual'];
      const allHoldings: PortfolioStock[] = [];

      // Make requests with proper error handling to prevent AbortErrors
      const portfolioPromises = portfolioTypes.map(async (portfolioType) => {
        try {
          console.log(`📊 Fetching ${portfolioType} portfolio holdings...`);
          
          const response = await apiService.request(`/portfolio/${portfolioType}/holdings`, {
            method: 'GET'
          });

          if (response.success) {
            const respData: any = response.data as any;
            const holdings: any[] = Array.isArray(respData?.holdings)
              ? respData.holdings
              : (Array.isArray(respData) ? respData : []);
            console.log(`📊 Found ${holdings.length} holdings in ${portfolioType} portfolio`);
            
            return holdings.map((holding: any) => ({
              symbol: holding.symbol,
              companyname: holding.companyname || holding.company_name || holding.symbol,
              quantity: holding.quantity || holding.total_quantity || 0,
              averagePrice: holding.average_price || holding.averagePrice || holding.weighted_average_price || 0,
              currentPrice: holding.current_price || holding.currentPrice || 0,
              totalValue: ((holding.quantity || 0) * (holding.current_price || 0)) / 100,
              profitLoss: (((holding.quantity || 0) * (holding.current_price || 0)) - ((holding.quantity || 0) * (holding.average_price || 0))) / 100,
              profitLossPercent: holding.average_price > 0 ? (((holding.current_price || 0) - (holding.average_price || 0)) / (holding.average_price || 0)) * 100 : 0,
              portfolio_type: portfolioType
            }));
          } else if (response.error?.includes('subscription') || response.error?.includes('403')) {
            console.log(`📊 ${portfolioType} portfolio requires subscription - skipping gracefully`);
            return [];
          } else {
            console.log(`📊 No holdings in ${portfolioType} portfolio:`, response.error);
            return [];
          }
        } catch (portfolioError: any) {
          // Handle subscription/authorization errors gracefully without throwing
          if (portfolioError?.message?.includes('403') || portfolioError?.message?.includes('subscription')) {
            console.log(`📊 ${portfolioType} portfolio requires subscription - skipping gracefully`);
          } else if (portfolioError?.name === 'AbortError') {
            console.log(`📊 ${portfolioType} portfolio request was aborted - continuing with other portfolios`);
          } else {
            console.log(`📊 Error fetching ${portfolioType} portfolio:`, portfolioError?.message || portfolioError);
          }
          return [];
        }
      });

      // Wait for all requests to complete
      const portfolioResults = await Promise.all(portfolioPromises);
      
      // Flatten all results
  portfolioResults.forEach((holdings: PortfolioStock[]) => {
        allHoldings.push(...holdings);
      });

      // Remove duplicates (same stock in multiple portfolios)
      const uniqueStocks = allHoldings.reduce((unique: PortfolioStock[], stock) => {
        const existingStock = unique.find(s => s.symbol === stock.symbol);
        if (existingStock) {
          // Combine quantities and recalculate values
          existingStock.quantity += stock.quantity;
          existingStock.totalValue += stock.totalValue;
          existingStock.profitLoss += stock.profitLoss;
          // Recalculate average price
          const totalCost = (existingStock.quantity * existingStock.averagePrice) + (stock.quantity * stock.averagePrice);
          existingStock.averagePrice = totalCost / existingStock.quantity;
        } else {
          unique.push({ ...stock });
        }
        return unique;
      }, []);

      console.log(`📊 Found ${uniqueStocks.length} unique stocks in portfolios`);
      setPortfolioStocks(uniqueStocks);
      setError(null);
      
    } catch (err: any) {
      console.error('❌ Error loading portfolio stocks:', err);
      
      // Only set error state if we have no existing stocks and it's not a subscription error
      if (portfolioStocks.length === 0) {
        if (err?.message?.includes('403') || err?.message?.includes('subscription')) {
          console.log('📊 Portfolio access requires subscriptions - showing empty state');
          setError(null); // Don't show error for subscription requirements
        } else if (err?.name === 'AbortError') {
          console.log('📊 Portfolio requests were aborted - this is expected for concurrent requests');
          setError(null); // Don't show error for abort situations
        } else {
          setError(err instanceof Error ? err.message : 'Failed to load portfolio stocks');
        }
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    // Add delay to prevent concurrent API calls with other tickers
    const initialLoadTimer = setTimeout(() => {
      loadPortfolioStocks();
    }, 2000); // 2 second delay
    
    let interval: NodeJS.Timeout;
    if (refreshInterval > 0) {
      interval = setInterval(loadPortfolioStocks, refreshInterval);
    }
    
    return () => {
      clearTimeout(initialLoadTimer);
      if (interval) clearInterval(interval);
    };
  }, [refreshInterval]);

  // Smooth continuous scrolling animation
  useEffect(() => {
    if (portfolioStocks.length > 0 && !loading) {
      console.log('📊 Starting portfolio stocks scroll animation for', portfolioStocks.length, 'stocks');
      
      const cardWidth = 126; // UPDATED: card width (118) + gap (8) = 126
      const totalWidth = portfolioStocks.length * cardWidth;
      
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

      const timer = setTimeout(animateScroll, 1000);
      
      return () => {
        clearTimeout(timer);
        scrollX.stopAnimation();
      };
    }
  }, [portfolioStocks, loading, scrollX]);

  const formatPrice = (price: number) => {
    return `£${price.toFixed(2)}`;
  };

  const formatPercent = (percent: number) => {
    return percent >= 0
      ? `+${percent.toFixed(1)}%`
      : `${percent.toFixed(1)}%`;
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
            <MaterialCommunityIcons name="briefcase" size={24} color="#10B981" />
            <Text style={styles.loadingText}>Loading your stocks...</Text>
          </View>
        </LinearGradient>
      </View>
    );
  }

  if (error || portfolioStocks.length === 0) {
    return (
      <View style={styles.container}>
        <LinearGradient
          colors={['rgba(17, 24, 39, 0.8)', 'rgba(31, 41, 55, 0.8)']}
          style={styles.errorContainer}
        >
          <View style={styles.errorContent}>
            <MaterialCommunityIcons name="briefcase-outline" size={24} color="#6B7280" />
            <Text style={styles.errorText}>
              {error || 'No stocks in your portfolios'}
            </Text>
            <Text style={styles.errorSubtext}>Start trading to see your stocks here!</Text>
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
        {/* Smooth continuous scrolling portfolio stocks */}
        <View style={styles.scrollContainer}>
          <Animated.View 
            style={[
              styles.scrollContent,
              {
                transform: [
                  {
                    translateX: scrollX.interpolate({
                      inputRange: [0, portfolioStocks.length * 126],
                      outputRange: [0, -portfolioStocks.length * 126],
                      extrapolate: 'clamp',
                    }),
                  },
                ],
              },
            ]}
          >
            {/* Render stocks twice for continuous effect */}
            {[...portfolioStocks, ...portfolioStocks].map((stock, index) => (
              <TouchableOpacity
                key={`${stock.symbol}-${index}`}
                style={[styles.stockCard, index === 0 && styles.firstCard]}
                onPress={() => onStockPress?.(stock.symbol)}
                activeOpacity={0.8}
              >
                <LinearGradient
                  colors={
                    stock.profitLoss > 0 
                      ? ['rgba(59, 130, 246, 0.2)', 'rgba(59, 130, 246, 0.1)'] // Blue for profit
                      : stock.profitLoss < 0 
                        ? ['rgba(239, 68, 68, 0.2)', 'rgba(239, 68, 68, 0.1)'] // Red for loss
                        : ['rgba(34, 197, 94, 0.2)', 'rgba(34, 197, 94, 0.1)'] // Green for breakeven
                  }
                  style={styles.stockGradient}
                >
                  {/* Portfolio indicator */}
                  <View style={styles.portfolioBadge}>
                    <MaterialCommunityIcons name="briefcase" size={10} color="#10B981" />
                  </View>

                  {/* Stock info - Same format as StocksTicker */}
                  <Text style={styles.stockSymbol}>{stock.symbol}</Text>
                  <Text style={styles.stockName} numberOfLines={1}>
                    {truncateName(stock.companyname)}
                  </Text>
                  
                  {/* Quantity and P&L */}
                  <View style={styles.priceContainer}>
                    <Text style={styles.quantityText}>
                      {stock.quantity} shares
                    </Text>
                    <Text style={styles.stockChange}>
                      Avg: {formatPence(stock.averagePrice)}
                    </Text>
                    <Text style={styles.stockChange}>
                      Current: {formatPence(stock.currentPrice)}
                    </Text>
                    <Text style={[
                      styles.stockChange,
                      { color: stock.profitLoss > 0 ? '#3B82F6' : stock.profitLoss < 0 ? '#EF4444' : '#10B981' }
                    ]}>
                      {formatPercent(stock.profitLossPercent)}
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
    fontSize: 14,
  },
  errorContainer: {
    borderRadius: 16,
    padding: 20,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.5)',
    alignItems: 'center',
  },
  errorContent: {
    alignItems: 'center',
    gap: 8,
  },
  errorText: {
    color: '#9CA3AF',
    fontSize: 14,
    textAlign: 'center',
  },
  errorSubtext: {
    color: '#6B7280',
    fontSize: 12,
    textAlign: 'center',
  },
  scrollContainer: {
    height: 98, // INCREASED: Match updated card height (88 + padding)
    overflow: 'hidden',
  },
  scrollContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  stockCard: {
    width: 118, // INCREASED: Match updated StocksTicker size
    height: 88, // INCREASED: Match updated StocksTicker size
    marginRight: 8,
    borderRadius: 12,
    overflow: 'hidden',
  },
  firstCard: {
    marginLeft: 0,
  },
  stockGradient: {
    flex: 1,
    padding: 6, // COMPRESSED: Reduced padding
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
    position: 'relative',
    alignItems: 'center',
    justifyContent: 'center',
  },
  portfolioBadge: {
    position: 'absolute',
    top: 6,
    right: 6,
    width: 18,
    height: 18,
    borderRadius: 9,
    backgroundColor: 'rgba(16, 185, 129, 0.2)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  stockName: {
    fontSize: 14, // REDUCED: Made company name smaller to match TradeTicker
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 4,
    paddingRight: 20,
  },
  stockSymbol: {
    fontSize: 10, // Match StocksTicker
    color: '#9CA3AF',
    marginBottom: 4,
  },
  priceContainer: {
    alignItems: 'flex-start',
  },
  quantityText: {
    fontSize: 10,
    color: '#10B981',
    fontWeight: '600',
    marginBottom: 2,
  },
  stockChange: {
    fontSize: 12, // Match StocksTicker
    fontWeight: '600',
  },
});