import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { apiService } from '../src/services/api';

type PortfolioType = 'default' | 'weekly' | 'monthly' | 'annual';

interface Trade {
  id: string;
  symbol: string;
  company_name?: string;
  companyname?: string;
  quantity: number;
  price: number;
  action: 'buy' | 'sell' | 'BUY' | 'SELL';
  total_value?: number;
  total_amount?: number;
  created_at?: string;
  timestamp?: string;
  transaction_date?: string;
  portfolio_type?: string;
}

interface League {
  id: string;
  name: string;
  type: string;
  status: string;
}

const PORTFOLIO_CONFIG: Record<PortfolioType, { label: string; color: string }> = {
  default: { label: 'Practice', color: '#10B981' },
  weekly: { label: 'Weekly', color: '#3B82F6' },
  monthly: { label: 'Monthly', color: '#8B5CF6' },
  annual: { label: 'Annual', color: '#F59E0B' },
};

const LEAGUE_COLOR = '#EC4899';

export default function TradeHistoryScreen() {
  const router = useRouter();
  const params = useLocalSearchParams();

  const [activeType, setActiveType] = useState<PortfolioType>((params.type as PortfolioType) || 'default');
  const [trades, setTrades] = useState<Trade[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activeTypes, setActiveTypes] = useState<string[]>(['default']);
  const [leagues, setLeagues] = useState<League[]>([]);
  const [activeLeagueId, setActiveLeagueId] = useState<string | null>(null);

  // Fetch user's leagues on mount
  useEffect(() => {
    const fetchLeagues = async () => {
      try {
        const response = await apiService.getLeagues();
        if (response.success && response.data) {
          const data = response.data;
          const myLeagues = data.myLeagues || data.leagues || [];
          // Only show active leagues
          const active = myLeagues.filter((l: League) => l.status === 'active');
          setLeagues(active);
        }
      } catch (err) {
        console.error('Error fetching leagues:', err);
      }
    };
    fetchLeagues();
  }, []);

  const fetchTrades = useCallback(async () => {
    try {
      setError(null);

      if (activeLeagueId) {
        // Fetch league portfolio transactions
        const response = await apiService.request<any>(`/mobile/leagues/${activeLeagueId}/portfolio`);
        if (response.success && response.data) {
          const txs = response.data.transactions || [];
          // Map league transaction format to Trade format
          const mapped = txs.map((t: any) => ({
            ...t,
            company_name: t.companyname || t.company_name,
            total_value: t.total_amount || t.total_value,
            created_at: t.transaction_date || t.created_at,
            timestamp: t.transaction_date || t.created_at,
          }));
          setTrades(mapped);
        } else {
          setTrades([]);
          if (response.error) setError(response.error);
        }
      } else {
        // Fetch regular portfolio transactions
        const response = await apiService.getPortfolioTransactions(activeType);
        if (response.success && response.data) {
          const data = Array.isArray(response.data) ? { transactions: response.data } : response.data;
          setTrades(data.transactions || data.trades || []);
          if (data.activeTypes && Array.isArray(data.activeTypes)) {
            setActiveTypes(data.activeTypes);
          }
        } else {
          setError(response.error || 'Failed to load trade history');
        }
      }
    } catch (err) {
      console.error('Error fetching trades:', err);
      setError('Unable to load trade history');
    } finally {
      setLoading(false);
    }
  }, [activeType, activeLeagueId]);

  useEffect(() => {
    setLoading(true);
    fetchTrades();
  }, [fetchTrades]);

  const onRefresh = async () => {
    setRefreshing(true);
    await fetchTrades();
    setRefreshing(false);
  };

  const handleSelectPortfolioType = (type: PortfolioType) => {
    setActiveLeagueId(null);
    setActiveType(type);
  };

  const handleSelectLeague = (leagueId: string) => {
    setActiveLeagueId(leagueId);
  };

  const formatCurrency = (pence: number) => {
    const pounds = pence / 100;
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP',
      minimumFractionDigits: 2,
    }).format(pounds);
  };

  const formatPence = (pence: number) => {
    return `${pence.toFixed(2)}p`;
  };

  const formatDate = (dateString?: string) => {
    if (!dateString) return 'Unknown';
    try {
      const date = new Date(dateString);
      return date.toLocaleDateString('en-GB', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return 'Unknown';
    }
  };

  // Determine current color based on selection
  const currentColor = activeLeagueId
    ? LEAGUE_COLOR
    : (PORTFOLIO_CONFIG[activeType] || PORTFOLIO_CONFIG.default).color;
  const currentLabel = activeLeagueId
    ? (leagues.find(l => l.id === activeLeagueId)?.name || 'League')
    : (PORTFOLIO_CONFIG[activeType] || PORTFOLIO_CONFIG.default).label;

  // Filter portfolio tabs to only show active types (always include default)
  const visibleTypes = (Object.keys(PORTFOLIO_CONFIG) as PortfolioType[]).filter(
    type => type === 'default' || activeTypes.includes(type)
  );

  return (
    <View style={styles.container}>
      <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />

      <SafeAreaView style={styles.safeArea} edges={['top']}>
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity style={styles.backButton} onPress={() => router.back()}>
            <Ionicons name="arrow-back" size={24} color="#FFFFFF" />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Trade History</Text>
          <View style={{ width: 40 }} />
        </View>

        {/* Portfolio Type Tabs */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.tabsContainer}>
          {visibleTypes.map((type) => {
            const typeConfig = PORTFOLIO_CONFIG[type];
            const isActive = type === activeType && !activeLeagueId;

            return (
              <TouchableOpacity
                key={type}
                style={[styles.tab, isActive && { borderColor: typeConfig.color, backgroundColor: `${typeConfig.color}20` }]}
                onPress={() => handleSelectPortfolioType(type)}
              >
                <Text style={[styles.tabLabel, isActive && { color: typeConfig.color }]}>
                  {typeConfig.label}
                </Text>
              </TouchableOpacity>
            );
          })}
        </ScrollView>

        {/* League Tabs (second row) */}
        {leagues.length > 0 && (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.tabsContainer}>
            {leagues.map((league) => {
              const isActive = activeLeagueId === league.id;

              return (
                <TouchableOpacity
                  key={league.id}
                  style={[styles.tab, isActive && { borderColor: LEAGUE_COLOR, backgroundColor: `${LEAGUE_COLOR}20` }]}
                  onPress={() => handleSelectLeague(league.id)}
                >
                  <View style={styles.leagueTabContent}>
                    <Ionicons
                      name="trophy-outline"
                      size={14}
                      color={isActive ? LEAGUE_COLOR : '#9CA3AF'}
                      style={{ marginRight: 6 }}
                    />
                    <Text style={[styles.tabLabel, isActive && { color: LEAGUE_COLOR }]} numberOfLines={1}>
                      {league.name}
                    </Text>
                  </View>
                </TouchableOpacity>
              );
            })}
          </ScrollView>
        )}

        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#3B82F6" />}
          showsVerticalScrollIndicator={false}
        >
          {loading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="large" color={currentColor} />
              <Text style={styles.loadingText}>Loading trades...</Text>
            </View>
          ) : error ? (
            <View style={styles.errorContainer}>
              <Ionicons name="alert-circle-outline" size={48} color="#EF4444" />
              <Text style={styles.errorText}>{error}</Text>
              <TouchableOpacity style={styles.retryButton} onPress={fetchTrades}>
                <Text style={styles.retryButtonText}>Retry</Text>
              </TouchableOpacity>
            </View>
          ) : trades.length === 0 ? (
            <View style={styles.emptyContainer}>
              <Ionicons name="swap-horizontal-outline" size={64} color="#4B5563" />
              <Text style={styles.emptyTitle}>No Trades Yet</Text>
              <Text style={styles.emptySubtext}>
                Your {currentLabel.toLowerCase()} trade history will appear here
              </Text>
              <TouchableOpacity
                style={styles.browseButton}
                onPress={() => router.push('/(tabs)/stocks')}
              >
                <LinearGradient colors={[currentColor, currentColor + 'CC']} style={styles.browseButtonGradient}>
                  <Ionicons name="trending-up" size={18} color="#FFFFFF" />
                  <Text style={styles.browseButtonText}>Start Trading</Text>
                </LinearGradient>
              </TouchableOpacity>
            </View>
          ) : (
            <>
              {/* Summary */}
              <View style={styles.summaryCard}>
                <Text style={styles.summaryTitle}>Summary</Text>
                <View style={styles.summaryRow}>
                  <View style={styles.summaryItem}>
                    <Text style={styles.summaryLabel}>Total Trades</Text>
                    <Text style={styles.summaryValue}>{trades.length}</Text>
                  </View>
                  <View style={styles.summaryItem}>
                    <Text style={styles.summaryLabel}>Buys</Text>
                    <Text style={[styles.summaryValue, { color: '#10B981' }]}>
                      {trades.filter(t => t.action.toUpperCase() === 'BUY').length}
                    </Text>
                  </View>
                  <View style={styles.summaryItem}>
                    <Text style={styles.summaryLabel}>Sells</Text>
                    <Text style={[styles.summaryValue, { color: '#EF4444' }]}>
                      {trades.filter(t => t.action.toUpperCase() === 'SELL').length}
                    </Text>
                  </View>
                </View>
              </View>

              {/* Trade List */}
              <View style={styles.tradesSection}>
                <Text style={styles.sectionTitle}>All Trades</Text>
                {trades.map((trade, index) => {
                  const isBuy = trade.action.toUpperCase() === 'BUY';
                  const totalValue = trade.total_value || trade.total_amount || trade.quantity * trade.price;

                  return (
                    <TouchableOpacity
                      key={trade.id || index}
                      style={styles.tradeCard}
                      onPress={() => router.push(`/(tabs)/stocks?symbol=${trade.symbol}`)}
                    >
                      <View style={styles.tradeLeft}>
                        <View style={[styles.actionBadge, { backgroundColor: isBuy ? '#10B98120' : '#EF444420' }]}>
                          <Ionicons
                            name={isBuy ? 'arrow-down' : 'arrow-up'}
                            size={16}
                            color={isBuy ? '#10B981' : '#EF4444'}
                          />
                        </View>
                        <View style={styles.tradeInfo}>
                          <View style={styles.tradeHeader}>
                            <Text style={styles.tradeName} numberOfLines={1}>
                              {trade.company_name || trade.companyname || trade.symbol}
                            </Text>
                            <Text style={[styles.tradeAction, { color: isBuy ? '#10B981' : '#EF4444' }]}>
                              {isBuy ? 'BUY' : 'SELL'}
                            </Text>
                          </View>
                          <Text style={styles.tradeSymbol}>{trade.symbol}</Text>
                          <Text style={styles.tradeDate}>
                            {formatDate(trade.created_at || trade.timestamp)}
                          </Text>
                        </View>
                      </View>
                      <View style={styles.tradeRight}>
                        <Text style={styles.tradeValue}>{formatCurrency(totalValue)}</Text>
                        <Text style={styles.tradeDetails}>
                          {trade.quantity} × {formatPence(trade.price)}
                        </Text>
                      </View>
                    </TouchableOpacity>
                  );
                })}
              </View>
            </>
          )}

          <View style={{ height: 40 }} />
        </ScrollView>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  safeArea: { flex: 1 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
  },
  backButton: {
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerTitle: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: 'bold',
  },
  tabsContainer: {
    flexGrow: 0,
    paddingHorizontal: 20,
    marginBottom: 8,
  },
  tab: {
    paddingHorizontal: 20,
    paddingVertical: 8,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.5)',
    marginRight: 10,
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
  },
  tabLabel: {
    color: '#9CA3AF',
    fontSize: 14,
    fontWeight: '600',
  },
  leagueTabContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  scrollView: { flex: 1 },
  scrollContent: { paddingHorizontal: 20 },
  loadingContainer: {
    paddingVertical: 60,
    alignItems: 'center',
  },
  loadingText: {
    color: '#9CA3AF',
    fontSize: 16,
    marginTop: 12,
  },
  errorContainer: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  errorText: {
    color: '#EF4444',
    fontSize: 16,
    marginTop: 16,
    textAlign: 'center',
  },
  retryButton: {
    marginTop: 20,
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: 'rgba(59, 130, 246, 0.2)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#3B82F6',
  },
  retryButtonText: {
    color: '#3B82F6',
    fontSize: 14,
    fontWeight: '600',
  },
  emptyContainer: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  emptyTitle: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: 'bold',
    marginTop: 16,
  },
  emptySubtext: {
    color: '#9CA3AF',
    fontSize: 14,
    marginTop: 8,
    textAlign: 'center',
    paddingHorizontal: 20,
  },
  browseButton: {
    marginTop: 24,
    borderRadius: 12,
    overflow: 'hidden',
  },
  browseButtonGradient: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 24,
    paddingVertical: 14,
  },
  browseButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
  summaryCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    marginBottom: 20,
  },
  summaryTitle: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 16,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  summaryItem: {
    alignItems: 'center',
  },
  summaryLabel: {
    color: '#9CA3AF',
    fontSize: 12,
    marginBottom: 4,
  },
  summaryValue: {
    color: '#FFFFFF',
    fontSize: 24,
    fontWeight: 'bold',
  },
  tradesSection: {
    marginBottom: 20,
  },
  sectionTitle: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 16,
  },
  tradeCard: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 14,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  tradeLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  actionBadge: {
    width: 36,
    height: 36,
    borderRadius: 10,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  tradeInfo: {
    flex: 1,
  },
  tradeHeader: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  tradeSymbol: {
    color: '#9CA3AF',
    fontSize: 12,
    marginTop: 2,
  },
  tradeAction: {
    fontSize: 11,
    fontWeight: '700',
  },
  tradeName: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: 'bold',
    flex: 1,
    marginRight: 8,
  },
  tradeDate: {
    color: '#6B7280',
    fontSize: 11,
    marginTop: 2,
  },
  tradeRight: {
    alignItems: 'flex-end',
  },
  tradeValue: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '600',
  },
  tradeDetails: {
    color: '#9CA3AF',
    fontSize: 12,
    marginTop: 2,
  },
});
