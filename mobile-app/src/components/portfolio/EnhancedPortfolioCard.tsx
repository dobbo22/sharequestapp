// Enhanced Portfolio Card for Mobile - matches main app functionality
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Dimensions,
  Animated,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useAuth } from '../../hooks/useAuth';
import { apiService } from '../../services/api';

const { width } = Dimensions.get('window');

type PortfolioType = 'default' | 'weekly' | 'monthly' | 'annual';

interface EnhancedPortfolioCardProps {
  type: PortfolioType;
  onPress: () => void;
  showDetailedStats?: boolean;
}

interface PortfolioData {
  totalValue: number;
  cashBalance: number;
  holdingsValue: number;
  profitLoss: number;
  profitLossPercent: number;
  prizePot?: number;
  subscribers?: number;
  hasData: boolean;
  isSubscribed?: boolean;
}

const INITIAL_INVESTMENT = 10000000; // £100,000 in pence (matching main app)

const EnhancedPortfolioCard: React.FC<EnhancedPortfolioCardProps> = ({
  type,
  onPress,
  showDetailedStats = false
}) => {
  const { user } = useAuth();
  const [portfolioData, setPortfolioData] = useState<PortfolioData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [animatedValue] = useState(new Animated.Value(0));

  useEffect(() => {
    Animated.timing(animatedValue, {
      toValue: 1,
      duration: 800,
      useNativeDriver: true,
    }).start();
  }, []);

  type Config = {
    title: string;
    duration: string;
    colors: readonly [string, string];
    bgColors: readonly [string, string];
    borderColor: string;
    icon: string;
    price: string;
    description: string;
  };

  const getConfig = (): Config => {
    if (type === 'weekly') {
      return {
        title: 'Weekly Challenge',
        duration: '5-day contest',
        colors: ['#10B981', '#059669'] as const,
        bgColors: ['rgba(16, 185, 129, 0.15)', 'rgba(5, 150, 105, 0.15)'] as const,
        borderColor: 'rgba(16, 185, 129, 0.4)',
        icon: 'flash',
        price: '£1/week',
        description: 'Short-term trading challenge',
      };
    }
    if (type === 'monthly') {
      return {
        title: 'Monthly Challenge',
        duration: '30-day challenge',
        colors: ['#3B82F6', '#2563EB'] as const,
        bgColors: ['rgba(59, 130, 246, 0.15)', 'rgba(37, 99, 235, 0.15)'] as const,
        borderColor: 'rgba(59, 130, 246, 0.4)',
        icon: 'calendar',
        price: '£5/month',
        description: 'Build diverse portfolios',
      };
    }
    if (type === 'annual') {
      return {
        title: 'Annual Competition',
        duration: 'Year-long challenge',
        colors: ['#8B5CF6', '#7C3AED'] as const,
        bgColors: ['rgba(139, 92, 246, 0.15)', 'rgba(124, 58, 237, 0.15)'] as const,
        borderColor: 'rgba(139, 92, 246, 0.4)',
        icon: 'trophy',
        price: '£50/year',
        description: 'Long-term investment strategy',
      };
    }
    return {
      title: 'Practice Portfolio',
      duration: 'Risk-free practice',
      colors: ['#3B82F6', '#2563EB'] as const,
      bgColors: ['rgba(59, 130, 246, 0.15)', 'rgba(37, 99, 235, 0.15)'] as const,
      borderColor: 'rgba(59, 130, 246, 0.4)',
      icon: 'school',
      price: 'FREE',
      description: 'Perfect your trading skills',
    };
  };

  const config = getConfig();

  const fetchPortfolioData = async () => {
    if (!user) return;
    setLoading(true);
    setError(null);
    try {
      // ...existing code...
      const response = await apiService.request(`/portfolio/${type}?refresh=true&t=${Date.now()}`, {
        method: 'GET',
        headers: {
          'Cache-Control': 'no-cache'
        }
      });
      if (response.success && response.data) {
        const respData: any = response.data as any;
        const portfolio = respData.portfolio || {};
        const holdings = respData.holdings || [];
        const subscription = respData.subscription || {};
        // Check subscription status for non-default portfolios
        const isSubscribed = (type === 'default') || Boolean(subscription.isSubscribed);
        if (!isSubscribed && (type === 'weekly' || type === 'monthly' || type === 'annual')) {
          setPortfolioData({
            totalValue: 0,
            cashBalance: 0,
            holdingsValue: 0,
            profitLoss: 0,
            profitLossPercent: 0,
            prizePot: 0,
            subscribers: 0,
            hasData: false,
            isSubscribed: false
          });
          return;
        }
        // Parse values - main app API returns values in pence
        const cashBalanceInPence = Number(portfolio.cash_balance) || 0;
        const totalValueInPence = Number(portfolio.total_value) || 0;
        // Calculate holdings value from total - cash
        const holdingsValueInPence = Math.max(0, totalValueInPence - cashBalanceInPence);
        const profitLossInPence = totalValueInPence - INITIAL_INVESTMENT;
        const profitLossPercent = INITIAL_INVESTMENT > 0 ? (profitLossInPence / INITIAL_INVESTMENT) * 100 : 0;
        // Convert to pounds for display
        const totalValue = totalValueInPence / 100;
        const cashBalance = cashBalanceInPence / 100;
        const holdingsValue = holdingsValueInPence / 100;
        const profitLoss = profitLossInPence / 100;
        setPortfolioData({
          totalValue,
          cashBalance,
          holdingsValue,
          profitLoss,
          profitLossPercent,
          prizePot: 0, // TODO: Add prize pot data from API
          subscribers: 0, // TODO: Add subscriber count from API
          hasData: totalValue > 0 || cashBalance > 0 || holdingsValue > 0,
          isSubscribed: true
        });
      } else {
        const subRequired = (response as any).subscriptionRequired || (response.data as any)?.subscriptionRequired;
        if (subRequired) {
          setPortfolioData({
            totalValue: 0,
            cashBalance: 0,
            holdingsValue: 0,
            profitLoss: 0,
            profitLossPercent: 0,
            prizePot: 0,
            subscribers: 0,
            hasData: false,
            isSubscribed: false
          });
        } else {
          throw new Error(response.error || 'Failed to load portfolio');
        }
      }
    } catch (err: any) {
      // ...existing code...
      if (err?.message?.includes('403') || err?.message?.includes('subscription')) {
        setError(null);
      } else if (err?.name === 'AbortError') {
        setError(null);
      } else {
        setError(err instanceof Error ? err.message : 'Failed to load data');
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (user && (type === 'default' || user)) {
      fetchPortfolioData();
    }
  }, [user, type]);

  const formatCurrency = (value: number | null | undefined) => {
    const safeValue = parseFloat(String(value)) || 0;
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(safeValue);
  };

  const formatPercentage = (value: number | null | undefined) => {
    const safeValue = parseFloat(String(value)) || 0;
    return `${safeValue >= 0 ? '+' : ''}${safeValue.toFixed(2)}%`;
  };

  const isProfitable = portfolioData ? portfolioData.profitLoss >= 0 : false;

  return (
    <Animated.View style={[
      styles.container,
      {
        opacity: animatedValue,
        transform: [{
          scale: animatedValue.interpolate({
            inputRange: [0, 1],
            outputRange: [0.9, 1]
          })
        }]
      }
    ]}>
      <TouchableOpacity 
        style={styles.card} 
        onPress={onPress}
        activeOpacity={0.9}
      >
        <LinearGradient
          colors={config.bgColors}
          style={[styles.cardGradient, { borderColor: config.borderColor }]}
        >
          {/* Header Section */}
          <View style={styles.header}>
            <View style={styles.headerLeft}>
              <View style={[styles.iconContainer, { backgroundColor: config.colors[0] }]}> 
                <Ionicons name={config.icon as any} size={24} color="#FFFFFF" />
              </View>
              <View style={styles.headerText}>
                <Text style={styles.title}>{config.title}</Text>
                <Text style={styles.duration}>{config.duration}</Text>
              </View>
            </View>
            <View style={styles.priceTag}>
              <Text style={styles.priceText}>{config.price}</Text>
            </View>
          </View>

          {/* Portfolio Data */}
          {loading ? (
            <View style={styles.loadingSection}>
              <Text style={styles.loadingText}>Loading...</Text>
            </View>
          ) : error ? (
            <View style={styles.errorSection}>
              <Text style={styles.errorText}>Failed to load data</Text>
              <TouchableOpacity onPress={fetchPortfolioData}>
                <Text style={styles.retryText}>Retry</Text>
              </TouchableOpacity>
            </View>
          ) : portfolioData ? (
            portfolioData.isSubscribed === false ? (
              <View style={styles.subscriptionRequiredSection}>
                <Ionicons name="lock-closed" size={24} color="#F59E0B" style={styles.lockIcon} />
                <Text style={styles.subscriptionText}>Subscription Required</Text>
                <Text style={styles.subscriptionSubtext}>Tap to subscribe to {config.title}</Text>
              </View>
            ) : (
              <View style={styles.dataSection}>
                <View style={styles.valueSection}>
                  <Text style={styles.valueLabel}>Portfolio Value</Text>
                  <View style={styles.valueRow}>
                    <Text style={styles.valueAmount}>
                      {formatCurrency(portfolioData.totalValue)}
                    </Text>
                    {portfolioData.hasData && (
                      <View style={[
                        styles.changeIndicator,
                        { backgroundColor: isProfitable ? 'rgba(16, 185, 129, 0.2)' : 'rgba(239, 68, 68, 0.2)' }
                      ]}>
                        <Ionicons 
                          name={isProfitable ? 'trending-up' : 'trending-down'} 
                          size={14} 
                          color={isProfitable ? '#10B981' : '#EF4444'}
                        />
                        <Text style={[
                          styles.changeText,
                          { color: isProfitable ? '#10B981' : '#EF4444' }
                        ]}>
                          {formatPercentage(portfolioData.profitLossPercent)}
                        </Text>
                      </View>
                    )}
                  </View>
                </View>

                {showDetailedStats && portfolioData.hasData && (
                  <View style={styles.detailsSection}>
                    <View style={styles.detailRow}>
                      <Text style={styles.detailLabel}>Cash</Text>
                      <Text style={styles.detailValue}>
                        {formatCurrency(portfolioData.cashBalance)}
                      </Text>
                    </View>
                    <View style={styles.detailRow}>
                      <Text style={styles.detailLabel}>Holdings</Text>
                      <Text style={styles.detailValue}>
                        {formatCurrency(portfolioData.holdingsValue)}
                      </Text>
                    </View>
                    <View style={[styles.detailRow, styles.profitLossRow]}>
                      <Text style={styles.detailLabel}>P&L</Text>
                      <Text style={[
                        styles.detailValue,
                        { color: isProfitable ? '#10B981' : '#EF4444' }
                      ]}>
                        {formatCurrency(portfolioData.profitLoss)}
                      </Text>
                    </View>
                  </View>
                )}

                {/* Hide Rank for Practice Portfolio */}
                {type !== 'default' && (
                  <View style={styles.rankSection}>
                    <Text style={styles.rankLabel}>Rank</Text>
                    <Text style={styles.rankValue}>{/* Rank value here if available */}-</Text>
                  </View>
                )}
              </View>
            )
          ) : (
            <View style={styles.emptySection}>
              <Text style={styles.emptyText}>{config.description}</Text>
              <Text style={styles.emptySubtext}>Tap to get started</Text>
            </View>
          )}

          {/* Action Indicator */}
          <View style={styles.actionIndicator}>
            <Ionicons name="chevron-forward" size={20} color="#9CA3AF" />
          </View>
        </LinearGradient>
      </TouchableOpacity>
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginBottom: 12, // REDUCED: Less space between cards (was 16)
    marginHorizontal: 8, // ADDED: Better alignment with screen margins
  },
  card: {
    borderRadius: 20,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 8,
    },
    shadowOpacity: 0.15,
    shadowRadius: 16,
    elevation: 12,
  },
  cardGradient: {
    padding: 20, // REDUCED: Less padding for more compact design (was 24)
    borderWidth: 1,
    borderRadius: 20,
    minHeight: 240, // INCREASED: Even more space to prevent cutoff (was 200)
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  headerLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  iconContainer: {
    width: 48,
    height: 48,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 6,
  },
  headerText: {
    flex: 1,
  },
  title: {
    fontSize: 16, // REDUCED: Made title smaller (was 18)
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 2,
  },
  duration: {
    fontSize: 12,
    color: '#D1D5DB',
  },
  priceTag: {
    backgroundColor: 'rgba(255, 255, 255, 0.15)',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.2)',
  },
  priceText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  loadingSection: {
    alignItems: 'center',
    paddingVertical: 20,
  },
  loadingText: {
    color: '#D1D5DB',
    fontSize: 16,
  },
  errorSection: {
    alignItems: 'center',
    paddingVertical: 20,
  },
  errorText: {
    color: '#EF4444',
    fontSize: 16,
    marginBottom: 8,
  },
  retryText: {
    color: '#3B82F6',
    fontSize: 14,
    fontWeight: '600',
  },
  dataSection: {
    flex: 1,
    minHeight: 120, // ADDED: Ensure data section has minimum height
  },
  valueSection: {
    alignItems: 'center',
    marginBottom: 16, // INCREASED: More space below value section (was 12)
  },
  valueLabel: {
    fontSize: 12,
    color: '#D1D5DB',
    marginBottom: 8, // INCREASED: More space below label (was 6)
  },
  valueRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
  },
  valueAmount: {
    fontSize: 20, // REDUCED: Made value amount smaller (was 22)
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
  changeIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    gap: 3,
  },
  changeText: {
    fontSize: 12,
    fontWeight: '600',
  },
  detailsSection: {
    backgroundColor: 'rgba(0, 0, 0, 0.2)',
    borderRadius: 12,
    padding: 16,
    marginTop: 8, // ADDED: Space above details section
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 4,
  },
  profitLossRow: {
    paddingTop: 8,
    marginTop: 8,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255, 255, 255, 0.1)',
  },
  detailLabel: {
    fontSize: 14,
    color: '#D1D5DB',
  },
  detailValue: {
    fontSize: 14,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  emptySection: {
    alignItems: 'center',
    paddingVertical: 20,
  },
  emptyText: {
    fontSize: 16,
    color: '#D1D5DB',
    marginBottom: 4,
    textAlign: 'center',
  },
  emptySubtext: {
    fontSize: 14,
    color: '#9CA3AF',
    textAlign: 'center',
  },
  actionIndicator: {
    position: 'absolute',
    top: 24,
    right: 24,
  },
  
  // Subscription Required Section
  subscriptionRequiredSection: {
    alignItems: 'center',
    paddingVertical: 20,
  },
  lockIcon: {
    marginBottom: 8,
  },
  subscriptionText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#F59E0B',
    marginBottom: 4,
    textAlign: 'center',
  },
  subscriptionSubtext: {
    fontSize: 14,
    color: '#9CA3AF',
    textAlign: 'center',
  },
});

export default EnhancedPortfolioCard;