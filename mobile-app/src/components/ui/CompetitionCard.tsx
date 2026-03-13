// Compact competition card similar to main app's PortfolioCard
import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { apiService } from '../../services/api';

interface CompetitionData {
  totalValue: number;
  profitLoss: number;
  profitLossPercent: number;
  prizePot: number;
  participants: number;
  hasData: boolean;
}

interface CompetitionCardProps {
  portfolioType: 'weekly' | 'monthly' | 'annual';
  isSubscribed: boolean;
  onPress: () => void;
}

const portfolioConfigs = {
  weekly: {
    title: 'Weekly Challenge',
    subtitle: '7-day trading cycles',
    icon: 'lightning-bolt' as const,
    price: '£1.00',
  colors: ['rgba(34, 197, 94, 0.2)', 'rgba(34, 197, 94, 0.1)'] as const,
    accentColor: '#22C55E',
    borderColor: 'rgba(34, 197, 94, 0.3)',
  },
  monthly: {
    title: 'Monthly Challenge',
    subtitle: '30-day trading cycles',
    icon: 'calendar-month' as const,
    price: '£5.00',
  colors: ['rgba(59, 130, 246, 0.2)', 'rgba(59, 130, 246, 0.1)'] as const,
    accentColor: '#3B82F6',
    borderColor: 'rgba(59, 130, 246, 0.3)',
  },
  annual: {
    title: 'Annual Challenge',
    subtitle: '365-day trading cycles',
    icon: 'trophy' as const,
    price: '£25.00',
  colors: ['rgba(234, 88, 12, 0.2)', 'rgba(234, 88, 12, 0.1)'] as const,
    accentColor: '#EA580C',
    borderColor: 'rgba(234, 88, 12, 0.3)',
  },
};

export default function CompetitionCard({ portfolioType, isSubscribed, onPress }: CompetitionCardProps) {
  const [competitionData, setCompetitionData] = useState<CompetitionData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const config = portfolioConfigs[portfolioType];

  const fetchCompetitionData = async () => {
    if (!isSubscribed) return;
    
    setLoading(true);
    setError(null);
    
    try {
      // Fetch portfolio data
      const portfolioResponse = await apiService.request(`/portfolio/${portfolioType}`, {
        method: 'GET',
      });

      if (portfolioResponse.success && portfolioResponse.data) {
        const portfolio = (portfolioResponse.data as any).portfolio || (portfolioResponse as any).portfolio || {};
        const cashBalance = parseFloat(portfolio?.cash_balance || '0') / 100;
        let holdingsValue = 0;

        const holdings = (portfolioResponse.data as any).holdings || (portfolioResponse as any).holdings || [];
        if (holdings && holdings.length > 0) {
          holdingsValue = holdings.reduce((total: number, holding: any) => {
            const quantity = Number(holding.quantity) || 0;
            const currentPrice = Number(holding.current_price) || 0;
            return total + (quantity * currentPrice / 100);
          }, 0);
        }

        const totalValue = cashBalance + holdingsValue;
        const initialValue = 100000; // £100,000 starting capital
        const profitLoss = totalValue - initialValue;
        const profitLossPercent = (profitLoss / initialValue) * 100;

        // Fetch leaderboard data for participants and prize pot
        let participants = 0;
        let prizePot = 0;
        
        try {
          const leaderboardResponse = await apiService.request(`/leaderboards/${portfolioType}?limit=1`, {
            method: 'GET',
          });
          
          if (leaderboardResponse.success) {
            participants = (leaderboardResponse as any).totalParticipants || (leaderboardResponse.data as any)?.totalParticipants || 0;
            // Calculate prize pot based on participants
            const multipliers = { weekly: 0.5, monthly: 2.5, annual: 12.5 };
            prizePot = participants * multipliers[portfolioType];
          }
        } catch (leaderboardError) {
          console.warn('Could not fetch leaderboard data:', leaderboardError);
        }

        setCompetitionData({
          totalValue,
          profitLoss,
          profitLossPercent,
          prizePot,
          participants,
          hasData: totalValue > 0 || cashBalance > 0 || holdingsValue > 0,
        });
      } else if (portfolioResponse.error?.includes('subscription') || portfolioResponse.error?.includes('403')) {
        console.log(`📊 ${portfolioType} portfolio requires subscription - expected for non-subscribed users`);
        setError(null); // Don't show error for subscription requirements
        return;
      } else {
        throw new Error(portfolioResponse.error || 'Failed to load portfolio data');
      }
    } catch (err: any) {
      // Handle subscription/authorization errors gracefully
      if (err?.message?.includes('403') || err?.message?.includes('subscription')) {
        console.log(`📊 ${portfolioType} portfolio requires subscription - expected behavior`);
        setError(null); // Don't show error for subscription requirements
      } else if (err?.name === 'AbortError') {
        console.log(`📊 ${portfolioType} portfolio request was aborted - continuing gracefully`);
        setError(null); // Don't show error for abort situations
      } else {
        setError(err instanceof Error ? err.message : 'Failed to load data');
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isSubscribed) {
      fetchCompetitionData();
    }
  }, [isSubscribed, portfolioType]);

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount);
  };

  const formatPercentage = (value: number) => {
    return `${value >= 0 ? '+' : ''}${value.toFixed(2)}%`;
  };

  return (
    <TouchableOpacity
      style={styles.container}
      onPress={onPress}
      activeOpacity={0.8}
    >
      <LinearGradient
        colors={(
          isSubscribed 
            ? (config.colors as readonly [string, string]) 
            : (['rgba(107, 114, 128, 0.2)', 'rgba(107, 114, 128, 0.1)'] as const)
        )}
        style={[
          styles.cardGradient,
          {
            borderColor: isSubscribed ? config.borderColor : 'rgba(107, 114, 128, 0.3)',
          },
        ]}
      >
        {/* Header */}
        <View style={styles.header}>
          <View style={styles.leftHeader}>
            <View style={[
              styles.iconContainer,
              { backgroundColor: isSubscribed ? config.accentColor : '#6B7280' }
            ]}>
              <MaterialCommunityIcons 
                name={config.icon} 
                size={20} 
                color="#FFFFFF" 
              />
            </View>
            <View style={styles.titleContainer}>
              <Text style={styles.title}>{config.title}</Text>
              <Text style={styles.subtitle}>{config.subtitle}</Text>
            </View>
          </View>

          {/* Status badge */}
          <View style={[
            styles.statusBadge,
            { backgroundColor: isSubscribed ? config.accentColor : '#6B7280' }
          ]}>
            <Text style={styles.statusText}>
              {isSubscribed ? 'Active' : config.price}
            </Text>
          </View>
        </View>

        {/* Content */}
        {isSubscribed ? (
          <View style={styles.content}>
            {loading ? (
              <View style={styles.loadingContainer}>
                <MaterialCommunityIcons name="refresh" size={16} color={config.accentColor} />
                <Text style={styles.loadingText}>Loading...</Text>
              </View>
            ) : error ? (
              <View style={styles.errorContainer}>
                <MaterialCommunityIcons name="alert-circle" size={16} color="#EF4444" />
                <Text style={styles.errorText}>Failed to load</Text>
              </View>
            ) : competitionData ? (
              <>
                {/* Portfolio value and performance */}
                <View style={styles.performanceRow}>
                  <View style={styles.performanceItem}>
                    <Text style={styles.performanceLabel}>Portfolio</Text>
                    <Text style={styles.performanceValue}>
                      {formatCurrency(competitionData.totalValue)}
                    </Text>
                  </View>
                  
                  {competitionData.hasData && (
                    <View style={styles.performanceItem}>
                      <Text style={styles.performanceLabel}>P&L</Text>
                      <Text style={[
                        styles.performanceValue,
                        { color: competitionData.profitLoss >= 0 ? '#22C55E' : '#EF4444' }
                      ]}>
                        {formatPercentage(competitionData.profitLossPercent)}
                      </Text>
                    </View>
                  )}
                </View>

                {/* Prize pot and participants */}
                {competitionData.prizePot > 0 && (
                  <View style={styles.competitionRow}>
                    <View style={styles.competitionItem}>
                      <MaterialCommunityIcons name="trophy" size={14} color="#FCD34D" />
                      <Text style={styles.competitionLabel}>Prize Pot</Text>
                      <Text style={styles.competitionValue}>
                        {formatCurrency(competitionData.prizePot)}
                      </Text>
                    </View>
                    
                    <View style={styles.competitionItem}>
                      <MaterialCommunityIcons name="account-group" size={14} color="#9CA3AF" />
                      <Text style={styles.competitionLabel}>Participants</Text>
                      <Text style={styles.competitionValue}>
                        {competitionData.participants}
                      </Text>
                    </View>
                  </View>
                )}
              </>
            ) : (
              <View style={styles.noDataContainer}>
                <Text style={styles.noDataText}>Start trading to see performance</Text>
              </View>
            )}
          </View>
        ) : (
          <View style={styles.subscribeContent}>
            <Text style={styles.subscribeText}>Subscribe to join the competition</Text>
            <View style={styles.benefitsContainer}>
              <View style={styles.benefitItem}>
                <MaterialCommunityIcons name="trophy" size={12} color="#9CA3AF" />
                <Text style={styles.benefitText}>Real prizes</Text>
              </View>
              <View style={styles.benefitItem}>
                <MaterialCommunityIcons name="trending-up" size={12} color="#9CA3AF" />
                <Text style={styles.benefitText}>Live leaderboard</Text>
              </View>
            </View>
          </View>
        )}

        {/* Action indicator */}
        <View style={styles.actionIndicator}>
          <MaterialCommunityIcons name="chevron-right" size={16} color="#9CA3AF" />
        </View>
      </LinearGradient>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    marginBottom: 12,
  },
  cardGradient: {
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    position: 'relative',
  },

  // Header
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  leftHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  iconContainer: {
    width: 36,
    height: 36,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  titleContainer: {
    flex: 1,
  },
  title: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 2,
  },
  subtitle: {
    fontSize: 12,
    color: '#9CA3AF',
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  statusText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
  },

  // Content
  content: {
    marginBottom: 8,
  },
  loadingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 8,
  },
  loadingText: {
    color: '#9CA3AF',
    fontSize: 14,
  },
  errorContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 8,
  },
  errorText: {
    color: '#EF4444',
    fontSize: 14,
  },
  noDataContainer: {
    paddingVertical: 12,
    alignItems: 'center',
  },
  noDataText: {
    color: '#9CA3AF',
    fontSize: 14,
    textAlign: 'center',
  },

  // Performance
  performanceRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  performanceItem: {
    alignItems: 'center',
  },
  performanceLabel: {
    color: '#9CA3AF',
    fontSize: 12,
    marginBottom: 4,
  },
  performanceValue: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
  },

  // Competition info
  competitionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    padding: 12,
    borderRadius: 12,
  },
  competitionItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  competitionLabel: {
    color: '#9CA3AF',
    fontSize: 12,
  },
  competitionValue: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
    marginLeft: 4,
  },

  // Subscribe content
  subscribeContent: {
    paddingVertical: 8,
  },
  subscribeText: {
    color: '#D1D5DB',
    fontSize: 14,
    textAlign: 'center',
    marginBottom: 8,
  },
  benefitsContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 16,
  },
  benefitItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  benefitText: {
    color: '#9CA3AF',
    fontSize: 12,
  },

  // Action
  actionIndicator: {
    position: 'absolute',
    top: 16,
    right: 16,
  },
});