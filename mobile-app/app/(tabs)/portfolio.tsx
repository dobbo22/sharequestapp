import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { useAuth } from '../../src/hooks/useAuth';
import { apiService } from '../../src/services/api';
import { useRouter } from 'expo-router';
import { View, Text, StyleSheet, ActivityIndicator, ScrollView, RefreshControl, TouchableOpacity } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import Animated, { FadeInDown } from 'react-native-reanimated';
import TradeModal from '../../src/components/modals/TradeModal';
import XPGainToast from '../../src/components/gamification/XPGainToast';
import { validateTradeConcentration, PORTFOLIO_CONCENTRATION_LIMITS } from '../../src/services/portfolio-limits';
import { colors, spacing, radii, typography, glassStyle } from '../../src/lib/theme';

type PortfolioType = 'default' | 'practice' | 'weekly' | 'monthly' | 'annual';

interface Holding {
  symbol: string;
  companyname?: string;
  company_name?: string;
  quantity: number;
  average_price: number;
  current_price: number;
}

interface PortfolioData {
  cash_balance: number;
  initial_balance: number;
  total_portfolio_value: number;
  holdings: Holding[];
}

interface PortfolioConfig {
  type: PortfolioType;
  label: string;
  emoji: string;
  color: string;
  isSubscribed: boolean;
}

interface LeaguePortfolio {
  id: string;
  leagueName: string;
  status: string;
}

const PORTFOLIO_CONFIG: Record<PortfolioType, { label: string; icon: keyof typeof MaterialCommunityIcons.glyphMap; color: string }> = {
  default: { label: 'Practice', icon: 'target', color: '#10B981' },
  practice: { label: 'Practice', icon: 'target', color: '#10B981' },
  weekly: { label: 'Weekly', icon: 'calendar-week', color: '#3B82F6' },
  monthly: { label: 'Monthly', icon: 'calendar-month', color: '#8B5CF6' },
  annual: { label: 'Annual', icon: 'trophy-variant', color: '#F59E0B' },
};

export default function PortfolioScreen() {
  const router = useRouter();
  const { user } = useAuth();

  // Category toggle state
  const [portfolioCategory, setPortfolioCategory] = useState<'sharequests' | 'leagues'>('sharequests');
  const [availablePortfolios, setAvailablePortfolios] = useState<PortfolioConfig[]>([]);
  const [leaguePortfolios, setLeaguePortfolios] = useState<LeaguePortfolio[]>([]);

  const [selectedPortfolioType, setSelectedPortfolioType] = useState<PortfolioType>('default');
  const [portfolio, setPortfolio] = useState<PortfolioData | null>(null);
  const [loading, setLoading] = useState(true);  
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // Ref to prevent double fetch on tab switch
  const lastFetchedRef = React.useRef<string | null>(null);

  // Challenge tracking: which portfolio types have been viewed
  const [viewedPortfolios, setViewedPortfolios] = useState<Set<string>>(new Set());
  const [challengeChecked, setChallengeChecked] = useState(false);
  const [xpToastAmount, setXpToastAmount] = useState(0);
  const [xpToastVisible, setXpToastVisible] = useState(false);

  // Trade modal state
  const [tradeModalVisible, setTradeModalVisible] = useState(false);
  const [tradeModalHolding, setTradeModalHolding] = useState<{
    symbol: string;
    companyName: string;
    quantity: number;
    averagePrice: number;
    currentPrice: number;
  } | null>(null);
  const [tradeModalAction, setTradeModalAction] = useState<'buy' | 'sell'>('buy');

  // Helper to get config for current portfolio type
  function getCurrentConfig() {
    if (selectedPortfolioType.startsWith('league-')) {
      return { label: 'League Portfolio', icon: 'trophy-variant' as const, color: '#F59E0B' };
    }
    return PORTFOLIO_CONFIG[selectedPortfolioType] || { label: 'Portfolio', icon: 'briefcase-outline' as const, color: '#64748B' };
  }

  // Open trade modal for a holding
  const openTradeModal = (holding: Holding, action: 'buy' | 'sell') => {
    setTradeModalHolding({
      symbol: holding.symbol,
      companyName: holding.companyname || holding.company_name || holding.symbol,
      quantity: holding.quantity,
      averagePrice: holding.average_price,
      currentPrice: holding.current_price,
    });
    setTradeModalAction(action);
    setTradeModalVisible(true);
  };

  // Fetch portfolio data for the selected type
  const fetchPortfolio = useCallback(async () => {
    if (!user) return;
    setError(null);

    try {
      const response = await apiService.getPortfolio(selectedPortfolioType);
      if (response.success && response.data) {
        const p = response.data.portfolio || response.data;
        const holdings = response.data.holdings || [];

        // cash_balance and total_value come as pence strings from the API — convert to pounds
        const cashPence = parseInt(p.cash_balance || '0', 10);
        const initialPence = parseInt(p.initial_balance || '10000000', 10);

        // Compute holdings value from holdings array
        const holdingsValuePence = holdings.reduce(
          (sum: number, h: any) => sum + (Number(h.quantity) * Number(h.current_price || 0)),
          0,
        );

        setPortfolio({
          cash_balance: cashPence / 100,
          initial_balance: initialPence / 100,
          total_portfolio_value: (cashPence + holdingsValuePence) / 100,
          holdings: holdings.map((h: any) => ({
            symbol: h.symbol,
            companyname: h.companyname,
            company_name: h.company_name,
            quantity: Number(h.quantity),
            average_price: Number(h.average_price),
            current_price: Number(h.current_price),
          })),
        });
      } else {
        setError(response.error || 'Failed to load portfolio');
      }
    } catch (err) {
      console.error('Error fetching portfolio:', err);
      setError('Failed to load portfolio');
    }
  }, [user, selectedPortfolioType]);

  // Fetch portfolio whenever the selected type changes
  useEffect(() => {
    if (user && selectedPortfolioType) {
      fetchPortfolio();
    }
  }, [user, selectedPortfolioType, fetchPortfolio]);

  // Fetch available portfolios (subscribed only) and leagues
  const fetchAvailablePortfolios = useCallback(async () => {
    if (!user) return;

    try {
      // Fetch subscribed portfolios using apiService
      const dashboardResponse = await apiService.request<{ portfolios?: PortfolioConfig[] }>('/mobile/dashboard');

      if (dashboardResponse.success && dashboardResponse.data?.portfolios) {
        const subscribed = dashboardResponse.data.portfolios.filter((p: PortfolioConfig) => p.isSubscribed);
        setAvailablePortfolios(subscribed);
        if (
          subscribed.length > 0 &&
          !subscribed.find((p: PortfolioConfig) => p.type === selectedPortfolioType) &&
          !selectedPortfolioType.startsWith('league-')
        ) {
          console.log('[PortfolioScreen] Setting selectedPortfolioType to:', subscribed[0].type);
          setSelectedPortfolioType(subscribed[0].type);
        }
      }

      // Fetch league portfolios using mobile endpoint - silently fail if not available
      try {
        const leaguesResponse = await apiService.request<{
          myLeagues?: Array<{ id: string; name: string; status: string; portfolioType?: string }>;
        }>('/mobile/leagues');
        if (leaguesResponse.success && leaguesResponse.data?.myLeagues) {
          const activeLeaguePortfolios = leaguesResponse.data.myLeagues
            .filter((l) => l.status === 'active' && (l.portfolioType === 'League' || l.portfolioType === undefined))
            .map((l) => ({
              id: l.id,
              leagueName: l.name,
              status: l.status,
            }));
          setLeaguePortfolios(activeLeaguePortfolios);
        } else {
          setLeaguePortfolios([]);
        }
      } catch {
        setLeaguePortfolios([]);
      }
    } catch (err) {
      console.error('Error fetching portfolios:', err);
    } finally {
      setLoading(false);
    }
  }, [user, selectedPortfolioType]);

  useEffect(() => {
    if (user) {
      fetchAvailablePortfolios();
    }
  }, [user, fetchAvailablePortfolios]);

  // Track which portfolios user has viewed for the portfolio_check challenge
  useEffect(() => {
    if (portfolio && selectedPortfolioType && !selectedPortfolioType.startsWith('league-')) {
      setViewedPortfolios(prev => {
        const next = new Set(prev);
        next.add(selectedPortfolioType);
        return next;
      });
    }
  }, [portfolio, selectedPortfolioType]);

  // Check if all subscribed portfolios have been viewed
  useEffect(() => {
    if (challengeChecked || availablePortfolios.length === 0 || viewedPortfolios.size === 0) return;
    const subscribedTypes = availablePortfolios.map(p => p.type);
    const allViewed = subscribedTypes.every(t => viewedPortfolios.has(t));
    if (allViewed) {
      setChallengeChecked(true);
      Promise.all([
        apiService.updateChallengeProgress('portfolio_check', 1),
        apiService.updateChallengeProgress('pnl_check', 1),
      ])
        .then(([res]) => {
          if (res.success && res.data?.completed?.length > 0) {
            const totalXP = res.data.completed.reduce((sum: number, c: { xp_reward: number }) => sum + c.xp_reward, 0);
            setXpToastAmount(totalXP);
            setXpToastVisible(true);
          }
        })
        .catch(err => console.warn('Challenge progress update failed:', err));
    }
  }, [viewedPortfolios, availablePortfolios, challengeChecked]);

  // Pull-to-refresh handler
  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await Promise.all([fetchAvailablePortfolios(), fetchPortfolio()]);
    setRefreshing(false);
  }, [fetchAvailablePortfolios, fetchPortfolio]);

  const handleExecuteTrade = async (trade: { symbol: string; quantity: number; action: 'buy' | 'sell'; price: number }): Promise<{ success: boolean; error?: string; gamification?: { xp?: number; newAchievements?: { name: string; description: string; icon: string; tier: string; xp_reward: number }[]; challengesCompleted?: { name: string; xp_reward: number }[] } }> => {
    try {
      const result = await apiService.trade(
        selectedPortfolioType,
        trade.symbol,
        trade.quantity,
        trade.action,
        trade.price,
      );
      if (result.success) {
        // Refresh portfolio data after trade
        fetchPortfolio();
        return { success: true, gamification: result.data?.gamification };
      }
      return { success: false, error: result.error || 'Trade failed' };
    } catch (err) {
      console.error('Error executing trade:', err);
      return { success: false, error: 'Trade execution failed' };
    }
  };

  // Market status: 08:00-16:30 UK time, Mon-Fri
  function computeMarketStatusLocally() {
    try {
      const now = new Date();
      const parts = new Intl.DateTimeFormat('en-GB', {
        timeZone: 'Europe/London', hour12: false, weekday: 'short', hour: '2-digit', minute: '2-digit',
      }).formatToParts(now);
      const weekday = parts.find(p => p.type === 'weekday')?.value || '';
      const hour = parseInt(parts.find(p => p.type === 'hour')?.value || '0', 10);
      const minute = parseInt(parts.find(p => p.type === 'minute')?.value || '0', 10);
      if (weekday.startsWith('Sat') || weekday.startsWith('Sun')) return false;
      const currentMinutes = hour * 60 + minute;
      return currentMinutes >= 480 && currentMinutes <= 990; // 08:00-16:30
    } catch { return false; }
  }
  const marketOpen = useMemo(() => computeMarketStatusLocally(), [tradeModalVisible]);


  // Format pounds as currency
  const formatPounds = (pounds: number) => {
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP',
      minimumFractionDigits: 2,
    }).format(pounds);
  };

  // Alias for currency formatting (for compatibility with existing code)
  const formatCurrency = formatPounds;

  const formatPence = (pence: number) => {
    return `${pence.toFixed(2)}p`;
  };

  const calculateProfitLoss = () => {
    if (!portfolio) return { value: 0, percent: 0, isPositive: true };
    const profitLoss = portfolio.total_portfolio_value - portfolio.initial_balance;
    const percent = portfolio.initial_balance > 0 ? (profitLoss / portfolio.initial_balance) * 100 : 0;
    return {
      value: profitLoss,
      percent,
      isPositive: profitLoss >= 0,
    };
  };

  const profitLoss = calculateProfitLoss();

  if (loading) {
    return (
      <View style={styles.container}>
        <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#3B82F6" />
          <Text style={styles.loadingText}>Loading portfolio...</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />

      <SafeAreaView style={styles.safeArea} edges={['top']}>
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#3B82F6" />}
          showsVerticalScrollIndicator={false}
        >
          {/* Header */}
          <View style={styles.header}>
            <Text style={styles.headerTitle}>Portfolio</Text>
            <TouchableOpacity
              style={styles.historyButton}
              onPress={() => router.push({ pathname: '/trade-history', params: { type: selectedPortfolioType } })}
            >
              <MaterialCommunityIcons name="history" size={24} color="#9CA3AF" />
            </TouchableOpacity>
          </View>

          {/* Category Toggle */}
          <View style={styles.categoryToggle}>
            <TouchableOpacity
              style={[
                styles.categoryButton,
                portfolioCategory === 'sharequests' && styles.categoryButtonActive,
              ]}
              onPress={() => {
                setPortfolioCategory('sharequests');
                if (availablePortfolios.length > 0) {
                  const newType = availablePortfolios[0].type;
                  if (selectedPortfolioType !== newType) {
                    setSelectedPortfolioType(newType);
                  }
                }
              }}
            >
              <Text
                style={[
                  styles.categoryButtonText,
                  portfolioCategory === 'sharequests' && styles.categoryButtonTextActive,
                ]}
              >
                ShareQuests
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.categoryButton,
                portfolioCategory === 'leagues' && styles.categoryButtonActive,
              ]}
              onPress={() => {
                setPortfolioCategory('leagues');
                if (leaguePortfolios.length > 0) {
                  const newType = `league-${leaguePortfolios[0].id}`;
                  if (selectedPortfolioType !== newType) {
                    setSelectedPortfolioType(newType);
                  }
                }
              }}
            >
              <Text
                style={[
                  styles.categoryButtonText,
                  portfolioCategory === 'leagues' && styles.categoryButtonTextActive,
                ]}
              >
                Leagues
              </Text>
            </TouchableOpacity>
          </View>

          {/* Portfolio Type Tabs - ShareQuests */}
          {portfolioCategory === 'sharequests' && availablePortfolios.length > 0 && (
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.tabsContainer}>
              {availablePortfolios.map((p) => {
                const typeConfig = PORTFOLIO_CONFIG[p.type] || PORTFOLIO_CONFIG.default;
                const isActive = p.type === selectedPortfolioType;

                return (
                  <TouchableOpacity
                    key={p.type}
                    style={[styles.tab, isActive && { borderColor: typeConfig.color }]}
                    onPress={() => setSelectedPortfolioType(p.type)}
                  >
                    <Text style={styles.tabEmoji}>{p.emoji}</Text>
                    <Text style={[styles.tabLabel, isActive && { color: typeConfig.color }]}>
                      {p.label}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>
          )}

          {/* Portfolio Type Tabs - Leagues */}
          {portfolioCategory === 'leagues' && leaguePortfolios.length > 0 && (
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.tabsContainer}>
              {leaguePortfolios.map((league) => {
                const isActive = selectedPortfolioType === `league-${league.id}`;

                return (
                  <TouchableOpacity
                    key={league.id}
                    style={[styles.tab, isActive && { borderColor: '#F59E0B' }]}
                    onPress={() => {
                      const newType = `league-${league.id}`;
                      console.log('[PortfolioScreen] League tab pressed, setting selectedPortfolioType to:', newType);
                      setSelectedPortfolioType(newType);
                    }}
                  >
                    <Text style={styles.tabEmoji}>🏆</Text>
                    <Text style={[styles.tabLabel, isActive && { color: '#F59E0B' }]}> 
                      {league.leagueName}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>
          )}

          {/* No Leagues Message */}
          {portfolioCategory === 'leagues' && leaguePortfolios.length === 0 && (
            <View style={styles.noLeaguesContainer}>
              <Text style={styles.noLeaguesEmoji}>🏆</Text>
              <Text style={styles.noLeaguesTitle}>No League Portfolios</Text>
              <Text style={styles.noLeaguesText}>You haven't joined any leagues yet.</Text>
              <TouchableOpacity
                style={styles.browseLeaguesButton}
                onPress={() => router.push('/(tabs)/leaderboards')}
              >
                <Text style={styles.browseLeaguesText}>Browse Leagues</Text>
              </TouchableOpacity>
            </View>
          )}

          {error ? (
            <View style={styles.errorContainer}>
              <MaterialCommunityIcons name="alert-circle-outline" size={48} color="#EF4444" />
              <Text style={styles.errorText}>{error}</Text>
              <TouchableOpacity style={styles.retryButton} onPress={fetchPortfolio}>
                <Text style={styles.retryButtonText}>Retry</Text>
              </TouchableOpacity>
            </View>
          ) : (portfolioCategory === 'leagues' && leaguePortfolios.length === 0) ? null : (
            <>
              {/* League Name Title (if league portfolio selected) */}
              {selectedPortfolioType.startsWith('league-') && (
                <View style={styles.leagueTitleContainer}>
                  <Text style={styles.leagueTitle}>{getCurrentConfig().label}</Text>
                </View>
              )}
              {/* Portfolio Summary Hero */}
              <Animated.View entering={FadeInDown.duration(400)} style={styles.compactSummaryCard}>
                <View style={styles.heroRow}>
                  <View style={[styles.heroIconBadge, { backgroundColor: `${getCurrentConfig().color}25` }]}>
                    <MaterialCommunityIcons name={getCurrentConfig().icon} size={22} color={getCurrentConfig().color} />
                  </View>
                  <Text style={styles.compactSummaryTitle}>{getCurrentConfig().label}</Text>
                </View>

                <Text style={styles.heroValue}>{formatCurrency(portfolio?.total_portfolio_value || 0)}</Text>

                <View style={[styles.heroReturnBadge, { backgroundColor: profitLoss.isPositive ? 'rgba(16,185,129,0.15)' : 'rgba(239,68,68,0.15)' }]}>
                  <MaterialCommunityIcons
                    name={profitLoss.isPositive ? 'trending-up' : 'trending-down'}
                    size={14}
                    color={profitLoss.isPositive ? colors.success : colors.danger}
                  />
                  <Text style={[styles.heroReturnText, { color: profitLoss.isPositive ? colors.success : colors.danger }]}>
                    {profitLoss.isPositive ? '+' : ''}{formatCurrency(profitLoss.value)} ({profitLoss.isPositive ? '+' : ''}{profitLoss.percent.toFixed(2)}%)
                  </Text>
                </View>

                <View style={styles.heroDivider} />

                <View style={styles.compactSummaryRow}>
                  <Text style={styles.compactLabel}>Cash Available</Text>
                  <Text style={styles.compactValue}>{formatCurrency(portfolio?.cash_balance || 0)}</Text>
                </View>
              </Animated.View>

              {/* Holdings Section */}
              <View style={styles.section}>
                <View style={styles.sectionHeader}>
                  <Text style={styles.sectionTitle}>Holdings</Text>
                  <Text style={styles.holdingsCount}>
                    {portfolio?.holdings?.length || 0} stocks
                  </Text>
                </View>

                {!portfolio?.holdings || portfolio.holdings.length === 0 ? (
                  <View style={styles.emptyHoldings}>
                    <MaterialCommunityIcons name="briefcase-outline" size={48} color="#4B5563" />
                    <Text style={styles.emptyText}>No holdings yet</Text>
                    <Text style={styles.emptySubtext}>
                      Start trading to build your portfolio
                    </Text>
                    <TouchableOpacity
                      style={styles.browseButton}
                      onPress={() => router.push('/(tabs)/stocks')}
                    >
                      <LinearGradient
                        colors={['#3B82F6', '#1D4ED8']}
                        style={styles.browseButtonGradient}
                      >
                        <MaterialCommunityIcons name="magnify" size={18} color="#FFFFFF" />
                        <Text style={styles.browseButtonText}>Browse Stocks</Text>
                      </LinearGradient>
                    </TouchableOpacity>
                  </View>
                ) : (
                  portfolio.holdings.map((holding, holdingIndex) => {
                    const currentValuePence = holding.quantity * (holding.current_price || 0);
                    const costBasisPence = holding.quantity * (holding.average_price || 0);
                    const currentValue = currentValuePence / 100;
                    const costBasis = costBasisPence / 100;
                    const holdingPL = currentValue - costBasis;
                    const holdingPLPercent = costBasis > 0 ? (holdingPL / costBasis) * 100 : 0;
                    const isPositive = holdingPL >= 0;

                    return (
                      <Animated.View key={holding.symbol} entering={FadeInDown.delay(holdingIndex * 60).duration(350)} style={styles.holdingCard}>
                        {/* Header row with symbol and price */}
                        <View style={styles.holdingHeader}>
                          <View style={styles.holdingLeft}>
                            <TouchableOpacity onPress={() => router.push(`/(tabs)/stocks?symbol=${holding.symbol}`)}>
                              <Text style={styles.holdingSymbol}>{holding.companyname || holding.company_name || holding.symbol}</Text>
                            </TouchableOpacity>
                            <Text style={styles.holdingName}>{holding.symbol}</Text>
                          </View>
                          <View style={styles.holdingRight}>
                            <Text style={styles.holdingPrice}>{formatPence(holding.current_price)}</Text>
                            <View style={styles.holdingPL}>
                              <MaterialCommunityIcons
                                name={isPositive ? 'trending-up' : 'trending-down'}
                                size={14}
                                color={isPositive ? '#60A5FA' : '#F87171'}
                              />
                              <Text
                                style={[
                                  styles.holdingPLText,
                                  { color: isPositive ? '#60A5FA' : '#F87171' },
                                ]}
                              >
                                {isPositive ? '+' : ''}{holdingPLPercent.toFixed(2)}%
                              </Text>
                            </View>
                          </View>
                        </View>

                        {/* Stats row */}
                        <View style={styles.holdingStats}>
                          <View style={styles.statItem}>
                            <Text style={styles.statLabel}>Shares</Text>
                            <Text style={styles.statValue}>{holding.quantity}</Text>
                          </View>
                          <View style={styles.statItem}>
                            <Text style={styles.statLabel}>Avg Cost</Text>
                            <Text style={styles.statValue}>{formatPence(holding.average_price)}</Text>
                          </View>
                          <View style={[styles.statItem, { alignItems: 'flex-end' }]}>
                            <Text style={styles.statLabel}>Value</Text>
                            <Text style={styles.statValue}>{formatCurrency(currentValue)}</Text>
                          </View>
                        </View>

                        {/* Gain/Loss row */}
                        <View style={styles.gainLossRow}>
                          <Text style={styles.gainLossLabel}>Gain/Loss</Text>
                          <Text style={[styles.gainLossValue, { color: isPositive ? '#60A5FA' : '#F87171' }]}>
                            {isPositive ? '+' : ''}{formatCurrency(holdingPL)}
                          </Text>
                        </View>

                        {/* Trade buttons */}
                        <View style={styles.tradeButtonsRow}>
                          <TouchableOpacity
                            style={styles.buyButton}
                            onPress={() => openTradeModal(holding, 'buy')}
                          >
                            <Text style={styles.tradeButtonText}>Buy</Text>
                          </TouchableOpacity>
                          <TouchableOpacity
                            style={styles.sellButton}
                            onPress={() => openTradeModal(holding, 'sell')}
                          >
                            <Text style={styles.tradeButtonText}>Sell</Text>
                          </TouchableOpacity>
                          <TouchableOpacity
                            style={styles.viewButton}
                            onPress={() => router.push(`/(tabs)/stocks?symbol=${holding.symbol}`)}
                          >
                            <Text style={styles.tradeButtonText}>View</Text>
                          </TouchableOpacity>
                        </View>
                      </Animated.View>
                    );
                  })
                )}
              </View>
            </>
          )}

          {/* Bottom padding for tab bar */}
          <View style={{ height: 100 }} />
        </ScrollView>
        <TradeModal
          visible={tradeModalVisible}
          onClose={() => setTradeModalVisible(false)}
          holding={tradeModalHolding}
          action={tradeModalAction}
          onExecute={handleExecuteTrade}
        />
        <XPGainToast
          amount={xpToastAmount}
          visible={xpToastVisible}
          onFinish={() => setXpToastVisible(false)}
        />
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  loadingContainer: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  loadingText: { color: '#9CA3AF', fontSize: 16, marginTop: 12 },
  safeArea: { flex: 1 },
  scrollView: { flex: 1 },
  scrollContent: { paddingHorizontal: 20 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 20,
  },
  headerTitle: { color: '#FFFFFF', fontSize: 28, fontWeight: 'bold' },
  historyButton: { padding: 8 },
  tabsContainer: { marginBottom: 20, marginHorizontal: -20, paddingHorizontal: 20 },
  tab: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.5)',
    marginRight: 10,
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
  },
  tabLabel: { color: '#9CA3AF', fontSize: 14, fontWeight: '600', marginLeft: 6 },
  summaryCard: {
    borderRadius: 20,
    padding: 20,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    marginBottom: 24,
  },
  summaryHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: 16 },
  iconBadge: {
    width: 40,
    height: 40,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  summaryTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: '600' },
  totalValueLabel: { color: '#9CA3AF', fontSize: 14, marginBottom: 4 },
  totalValue: { color: '#FFFFFF', fontSize: 36, fontWeight: 'bold', marginBottom: 16 },
  summaryRow: { flexDirection: 'row', justifyContent: 'space-between' },
  summaryItem: { flex: 1 },
  summaryItemLabel: { color: '#9CA3AF', fontSize: 12, marginBottom: 4 },
  summaryItemValue: { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
  profitLossContainer: { flexDirection: 'row', alignItems: 'center' },
  chartSection: { marginBottom: 24 },
  chartCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  section: { marginBottom: 24 },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  sectionTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold' },
  holdingsCount: { color: '#9CA3AF', fontSize: 14 },
  emptyHoldings: {
    alignItems: 'center',
    paddingVertical: 40,
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  emptyText: { color: '#FFFFFF', fontSize: 18, fontWeight: '600', marginTop: 16 },
  emptySubtext: { color: '#9CA3AF', fontSize: 14, marginTop: 8, marginBottom: 20 },
  browseButton: { borderRadius: 12, overflow: 'hidden' },
  browseButtonGradient: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  browseButtonText: { color: '#FFFFFF', fontSize: 14, fontWeight: '600', marginLeft: 8 },
  holdingCard: {
    backgroundColor: 'rgba(15, 23, 42, 0.8)',
    borderRadius: 12,
    padding: 12,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.5)',
  },
  holdingHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 8,
  },
  holdingLeft: { flex: 1, marginRight: 8 },
  holdingSymbol: { color: '#FFFFFF', fontSize: 16, fontWeight: 'bold' },
  holdingName: { color: '#9CA3AF', fontSize: 12, marginTop: 2 },
  holdingRight: { alignItems: 'flex-end' },
  holdingPrice: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
  holdingPL: { flexDirection: 'row', alignItems: 'center', marginTop: 2 },
  holdingPLText: { fontSize: 13, fontWeight: 'bold', marginLeft: 4 },
  holdingStats: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  statItem: { flex: 1 },
  statLabel: { color: '#6B7280', fontSize: 11 },
  statValue: { color: '#FFFFFF', fontSize: 13, fontWeight: '500' },
  gainLossRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  gainLossLabel: { color: '#9CA3AF', fontSize: 12 },
  gainLossValue: { fontSize: 13, fontWeight: 'bold' },
  tradeButtonsRow: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 4,
  },
  buyButton: {
    flex: 1,
    backgroundColor: '#3B82F6',
    paddingVertical: 8,
    borderRadius: 6,
    alignItems: 'center',
  },
  sellButton: {
    flex: 1,
    backgroundColor: '#DC2626',
    paddingVertical: 8,
    borderRadius: 6,
    alignItems: 'center',
  },
  viewButton: {
    flex: 1,
    backgroundColor: '#475569',
    paddingVertical: 8,
    borderRadius: 6,
    alignItems: 'center',
  },
  tradeButtonText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '600',
  },
  errorContainer: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  errorText: { color: '#EF4444', fontSize: 16, marginTop: 16, textAlign: 'center' },
  retryButton: {
    marginTop: 20,
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: 'rgba(59, 130, 246, 0.2)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#3B82F6',
  },
  retryButtonText: { color: '#3B82F6', fontSize: 14, fontWeight: '600' },
  // Category toggle styles
  categoryToggle: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 16,
  },
  categoryButton: {
    flex: 1,
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 12,
    backgroundColor: 'rgba(31, 41, 55, 0.8)',
    alignItems: 'center',
  },
  categoryButtonActive: {
    backgroundColor: '#3B82F6',
  },
  categoryButtonText: {
    color: '#9CA3AF',
    fontSize: 14,
    fontWeight: '600',
  },
  categoryButtonTextActive: {
    color: '#FFFFFF',
  },
  tabEmoji: {
    fontSize: 16,
    marginRight: 4,
  },
  // No leagues styles
  noLeaguesContainer: {
    backgroundColor: 'rgba(31, 41, 55, 0.8)',
    borderRadius: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.5)',
    padding: 32,
    alignItems: 'center',
    marginBottom: 20,
  },
  noLeaguesEmoji: {
    fontSize: 48,
    marginBottom: 16,
  },
  noLeaguesTitle: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  noLeaguesText: {
    color: '#9CA3AF',
    fontSize: 14,
    marginBottom: 16,
  },
  browseLeaguesButton: {
    backgroundColor: '#3B82F6',
    paddingVertical: 10,
    paddingHorizontal: 24,
    borderRadius: 8,
  },
  browseLeaguesText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
  // League title styles
  leagueTitleContainer: {
    marginBottom: 8,
  },
  leagueTitle: {
    color: '#F59E0B',
    fontSize: 16,
    fontWeight: '600',
  },
  // Portfolio summary hero card
  compactSummaryCard: {
    ...glassStyle(0.5),
    padding: spacing.md,
    marginBottom: spacing.md,
  },
  heroRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginBottom: spacing.md,
  },
  heroIconBadge: {
    width: 36,
    height: 36,
    borderRadius: radii.sm,
    alignItems: 'center',
    justifyContent: 'center',
  },
  compactSummaryTitle: {
    color: colors.textPrimary,
    fontSize: typography.md,
    fontWeight: '600',
  },
  heroValue: {
    color: colors.textPrimary,
    fontSize: 32,
    fontWeight: 'bold',
    marginBottom: spacing.sm,
  },
  heroReturnBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    gap: 4,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: radii.sm,
    marginBottom: spacing.md,
  },
  heroReturnText: {
    fontSize: typography.body,
    fontWeight: '700',
  },
  heroDivider: {
    height: 1,
    backgroundColor: colors.border,
    marginBottom: spacing.sm,
  },
  compactSummaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 4,
  },
  compactLabel: {
    color: colors.textSecondary,
    fontSize: typography.sm,
  },
  compactValue: {
    color: colors.textPrimary,
    fontSize: typography.body,
    fontWeight: '500',
  },
});
