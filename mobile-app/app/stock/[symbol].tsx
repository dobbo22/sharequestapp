import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
  Dimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { apiService } from '../../src/services/api';
import { useWatchlistStore } from '../../src/stores/watchlistStore';
import { useSubscriptions } from '../../src/hooks/useSubscriptions';

// Tab components
import OverviewTab from '../../src/components/stock-detail/OverviewTab';
import LivePriceTab from '../../src/components/stock-detail/LivePriceTab';
import PerformanceTab from '../../src/components/stock-detail/PerformanceTab';
import FinancialsTab from '../../src/components/stock-detail/FinancialsTab';
import StatementsTab from '../../src/components/stock-detail/StatementsTab';
import BalanceSheetTab from '../../src/components/stock-detail/BalanceSheetTab';
import FinancialHistoryTab from '../../src/components/stock-detail/FinancialHistoryTab';
import DividendsTab from '../../src/components/stock-detail/DividendsTab';
import PriceHistoryTab from '../../src/components/stock-detail/PriceHistoryTab';
import ShareQuestAnalysisTab from '../../src/components/stock-detail/ShareQuestAnalysisTab';
import TradeTab from '../../src/components/stock-detail/TradeTab';
import SubscriptionGate from '../../src/components/ui/SubscriptionGate';

const { width } = Dimensions.get('window');

type TabType = 'overview' | 'price' | 'performance' | 'financials' | 'statements' | 'balance' | 'history' | 'dividends' | 'priceHistory' | 'analysis' | 'trade';

const GATED_TABS: TabType[] = ['performance', 'financials', 'statements', 'balance', 'history', 'analysis'];

interface StockData {
  symbol: string;
  companyName: string;
  quote: {
    price: number;
    change: number;
    changePercent: number;
    dayHigh: number;
    dayLow: number;
    volume: number;
    previousClose: number;
    bid?: number;
    ask?: number;
  };
  performance?: {
    oneWeek: number | null;
    oneMonth: number | null;
    threeMonth: number | null;
    sixMonth: number | null;
    oneYear: number | null;
    ytd: number | null;
  };
  fiftyTwoWeek?: {
    high: number | null;
    low: number | null;
  };
  profile: {
    sector: string;
    industry?: string;
    country: string;
    marketCap?: number;
    description?: string;
  };
}

interface FundamentalsData {
  peRatio?: number;
  eps?: number;
  dividendYield?: number;
  marketCap?: number;
  revenue?: number;
  netIncome?: number;
  debtToEquity?: number;
  currentRatio?: number;
  beta?: number;
  fiftyTwoWeekHigh?: number;
  fiftyTwoWeekLow?: number;
  taxonomies?: {
    income_statement?: any;
    balance_sheet?: any;
    period_kpi?: any;
    cash_flow_statement?: any;
  } | null;
  dividendInfo?: {
    yield: number | null;
    annualRate: number | null;
    payoutRatio: number | null;
    exDate: string | null;
  } | null;
}

// Format helpers
const formatPrice = (pence?: number) => {
  if (!pence && pence !== 0) return '--';
  return `${pence.toFixed(2)}p`;
};

const formatMarketCap = (cap?: number) => {
  if (!cap) return '--';
  if (cap >= 1e12) return `£${(cap / 1e12).toFixed(1)}T`;
  if (cap >= 1e9) return `£${(cap / 1e9).toFixed(1)}B`;
  if (cap >= 1e6) return `£${(cap / 1e6).toFixed(0)}M`;
  return `£${cap.toLocaleString()}`;
};

const formatVolume = (vol?: number) => {
  if (!vol) return '--';
  if (vol >= 1e6) return `${(vol / 1e6).toFixed(1)}M`;
  if (vol >= 1e3) return `${(vol / 1e3).toFixed(0)}K`;
  return vol.toLocaleString();
};

// FPL-style stat box component
function StatBox({ label, value, subLabel }: { label: string; value: string; subLabel?: string }) {
  return (
    <View style={styles.statBox}>
      <Text style={styles.statBoxLabel}>{label}</Text>
      <Text style={styles.statBoxValue}>{value}</Text>
      {subLabel ? <Text style={styles.statBoxSub}>{subLabel}</Text> : null}
    </View>
  );
}

export default function StockDetailScreen() {
  const router = useRouter();
  const { symbol } = useLocalSearchParams<{ symbol: string }>();
  const { isInWatchlist, toggleWatchlist } = useWatchlistStore();
  const { subscriptions } = useSubscriptions();
  const isSubscribed = subscriptions.weekly || subscriptions.monthly || subscriptions.annual;

  const [activeTab, setActiveTab] = useState<TabType>('overview');
  const [stockData, setStockData] = useState<StockData | null>(null);
  const [sharequestScores, setSharequestScores] = useState<any>(null);
  const [fundamentals, setFundamentals] = useState<FundamentalsData | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchStockData = useCallback(async () => {
    if (!symbol) return;

    try {
      setError(null);
      const [quoteResponse, fundamentalsResponse] = await Promise.all([
        apiService.getStockQuote(symbol),
        apiService.request(`/mobile/stocks/${symbol}/fundamentals`, { method: 'GET' }).catch(() => ({ success: false }))
      ]);

      if (quoteResponse.success && quoteResponse.data) {
        setStockData(quoteResponse.data);
        if (quoteResponse.data.sharequestScores) {
          setSharequestScores(quoteResponse.data.sharequestScores);
        }
      } else {
        setError('Failed to load stock data');
      }

      if (fundamentalsResponse.success && fundamentalsResponse.data) {
        setFundamentals(fundamentalsResponse.data);
      }
    } catch (err) {
      console.error('Error fetching stock data:', err);
      setError('Failed to load stock data');
    } finally {
      setLoading(false);
    }
  }, [symbol]);

  useEffect(() => {
    fetchStockData();
    // Track stock exploration for daily challenges
    apiService.updateChallengeProgress('stock_view').catch(() => {});
  }, [fetchStockData]);

  const onRefresh = async () => {
    setRefreshing(true);
    await fetchStockData();
    setRefreshing(false);
  };

  const tabs: { id: TabType; label: string; icon: string }[] = [
    { id: 'overview', label: 'Overview', icon: 'information-circle-outline' },
    { id: 'price', label: 'Live Price', icon: 'pulse-outline' },
    { id: 'performance', label: 'Performance', icon: 'trending-up-outline' },
    { id: 'financials', label: 'Financials', icon: 'bar-chart-outline' },
    { id: 'statements', label: 'Statements', icon: 'document-text-outline' },
    { id: 'balance', label: 'Balance Sheet', icon: 'layers-outline' },
    { id: 'history', label: 'Fin. History', icon: 'time-outline' },
    { id: 'dividends', label: 'Dividends', icon: 'cash-outline' },
    { id: 'priceHistory', label: 'Price History', icon: 'stats-chart-outline' },
    { id: 'analysis', label: 'Analysis', icon: 'analytics-outline' },
    { id: 'trade', label: 'Trade', icon: 'swap-horizontal-outline' },
  ];

  if (loading) {
    return (
      <View style={styles.container}>
        <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />
        <SafeAreaView style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#3B82F6" />
          <Text style={styles.loadingText}>Loading {symbol}...</Text>
        </SafeAreaView>
      </View>
    );
  }

  if (error || !stockData) {
    return (
      <View style={styles.container}>
        <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />
        <SafeAreaView style={styles.errorContainer}>
          <Ionicons name="alert-circle-outline" size={64} color="#EF4444" />
          <Text style={styles.errorText}>{error || 'Stock not found'}</Text>
          <TouchableOpacity style={styles.retryButton} onPress={fetchStockData}>
            <Text style={styles.retryButtonText}>Retry</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.backButton} onPress={() => router.back()}>
            <Text style={styles.backButtonText}>Go Back</Text>
          </TouchableOpacity>
        </SafeAreaView>
      </View>
    );
  }

  const isUp = stockData.quote.change >= 0;
  const isFlat = stockData.quote.changePercent === 0;
  const mktCap = fundamentals?.marketCap || stockData.profile.marketCap;

  return (
    <View style={styles.container}>
      <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />

      <SafeAreaView style={styles.safeArea} edges={['top']}>
        {/* Header Card - FPL style */}
        <LinearGradient
          colors={['#1e293b', '#334155']}
          style={styles.headerCard}
        >
          {/* Top row: back, name, watchlist */}
          <View style={styles.headerRow}>
            <TouchableOpacity onPress={() => router.back()} style={styles.backBtn}>
              <Ionicons name="arrow-back" size={22} color="#FFFFFF" />
            </TouchableOpacity>
            <View style={styles.headerCenter}>
              <Text style={styles.headerName} numberOfLines={1}>{stockData.companyName}</Text>
              <View style={styles.headerMeta}>
                <View style={styles.symbolBadge}>
                  <Text style={styles.symbolBadgeText}>{symbol}</Text>
                </View>
                {stockData.profile.sector && stockData.profile.sector !== 'Unknown' && (
                  <Text style={styles.sectorChip}>{stockData.profile.sector}</Text>
                )}
              </View>
            </View>
            <TouchableOpacity onPress={() => { toggleWatchlist(symbol!); if (!isInWatchlist(symbol!)) apiService.updateChallengeProgress('watchlist').catch(() => {}); }} style={styles.watchlistBtn}>
              <Ionicons
                name={isInWatchlist(symbol!) ? 'star' : 'star-outline'}
                size={22}
                color={isInWatchlist(symbol!) ? '#F59E0B' : '#6B7280'}
              />
            </TouchableOpacity>
          </View>

          {/* Price row */}
          <View style={styles.priceSection}>
            <Text style={styles.priceMain}>{formatPrice(stockData.quote?.price)}</Text>
            <View style={[
              styles.changeBadge,
              isFlat ? styles.changeBadgeFlat : isUp ? styles.changeBadgeUp : styles.changeBadgeDown
            ]}>
              <Ionicons
                name={isUp ? 'caret-up' : 'caret-down'}
                size={14}
                color="#fff"
              />
              <Text style={styles.changeBadgeText}>
                {isUp ? '+' : ''}{stockData.quote.change.toFixed(2)}p ({isUp ? '+' : ''}{stockData.quote.changePercent.toFixed(2)}%)
              </Text>
            </View>
          </View>
        </LinearGradient>

        {/* FPL-style horizontal stats strip */}
        <View style={styles.statsStripContainer}>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={styles.statsStripContent}
          >
            <StatBox label="Mkt Cap" value={formatMarketCap(mktCap)} />
            <View style={styles.statsStripDivider} />
            <StatBox label="P/E" value={fundamentals?.peRatio ? fundamentals.peRatio.toFixed(1) : '--'} />
            <View style={styles.statsStripDivider} />
            <StatBox label="EPS" value={fundamentals?.eps ? `${fundamentals.eps.toFixed(2)}p` : '--'} />
            <View style={styles.statsStripDivider} />
            <StatBox label="Div Yield" value={fundamentals?.dividendYield ? `${fundamentals.dividendYield.toFixed(2)}%` : '--'} />
            <View style={styles.statsStripDivider} />
            <StatBox label="Volume" value={formatVolume(stockData.quote.volume)} />
            <View style={styles.statsStripDivider} />
            <StatBox label="Prev Close" value={formatPrice(stockData.quote.previousClose)} />
          </ScrollView>
        </View>

        {/* Tab Navigation - scrollable pills with underline indicator */}
        <View style={styles.tabContainer}>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.tabScroll}>
            {tabs.map((tab) => {
              const isActive = activeTab === tab.id;
              const isGated = !isSubscribed && GATED_TABS.includes(tab.id);
              return (
                <TouchableOpacity
                  key={tab.id}
                  style={[styles.tab, isActive && styles.activeTab]}
                  onPress={() => setActiveTab(tab.id)}
                  activeOpacity={0.7}
                >
                  <View style={styles.tabInner}>
                    <Ionicons
                      name={tab.icon as any}
                      size={14}
                      color={isActive ? '#FFFFFF' : '#6B7280'}
                      style={{ marginRight: 4 }}
                    />
                    <Text style={[styles.tabText, isActive && styles.activeTabText]}>
                      {tab.label}
                    </Text>
                    {isGated && (
                      <Ionicons name="lock-closed" size={9} color={isActive ? '#FFFFFF' : '#6B7280'} style={{ marginLeft: 3 }} />
                    )}
                  </View>
                  {isActive && <View style={styles.tabIndicator} />}
                </TouchableOpacity>
              );
            })}
          </ScrollView>
        </View>

        {/* Tab Content */}
        <ScrollView
          style={styles.content}
          refreshControl={
            <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#3B82F6" />
          }
          showsVerticalScrollIndicator={false}
        >
          {activeTab === 'overview' && (
            <OverviewTab stockData={stockData} fundamentals={fundamentals} />
          )}
          {activeTab === 'price' && (
            <LivePriceTab stockData={stockData} onRefresh={onRefresh} refreshing={refreshing} />
          )}
          {activeTab === 'performance' && (
            !isSubscribed ? <SubscriptionGate feature="performance data and analysis" /> : (
              <PerformanceTab
                performance={stockData.performance || null}
                fiftyTwoWeek={stockData.fiftyTwoWeek || null}
                currentPrice={stockData.quote.price}
              />
            )
          )}
          {activeTab === 'financials' && (
            !isSubscribed ? <SubscriptionGate feature="financial analysis and ratios" /> : (
              <FinancialsTab stockData={stockData} fundamentals={fundamentals} />
            )
          )}
          {activeTab === 'statements' && (
            !isSubscribed ? <SubscriptionGate feature="income statement data" /> : (
              <StatementsTab taxonomies={fundamentals?.taxonomies || null} />
            )
          )}
          {activeTab === 'balance' && (
            !isSubscribed ? <SubscriptionGate feature="balance sheet data" /> : (
              <BalanceSheetTab taxonomies={fundamentals?.taxonomies || null} />
            )
          )}
          {activeTab === 'history' && (
            !isSubscribed ? <SubscriptionGate feature="financial history trends" /> : (
              <FinancialHistoryTab taxonomies={fundamentals?.taxonomies || null} />
            )
          )}
          {activeTab === 'dividends' && (
            <DividendsTab
              taxonomies={fundamentals?.taxonomies || null}
              dividendInfo={fundamentals?.dividendInfo || null}
            />
          )}
          {activeTab === 'priceHistory' && (
            <PriceHistoryTab symbol={symbol!} />
          )}
          {activeTab === 'analysis' && (
            !isSubscribed ? <SubscriptionGate feature="ShareQuest analysis and score breakdowns" /> : (
              <ShareQuestAnalysisTab scores={sharequestScores} />
            )
          )}
          {activeTab === 'trade' && (
            <TradeTab stockData={stockData} symbol={symbol!} />
          )}
          <View style={{ height: 100 }} />
        </ScrollView>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  safeArea: { flex: 1 },
  loadingContainer: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  loadingText: { color: '#9CA3AF', marginTop: 16, fontSize: 16 },
  errorContainer: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20 },
  errorText: { color: '#EF4444', fontSize: 18, marginTop: 16, textAlign: 'center' },
  retryButton: {
    marginTop: 20,
    backgroundColor: '#3B82F6',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  retryButtonText: { color: '#FFFFFF', fontWeight: '600' },
  backButton: { marginTop: 12 },
  backButtonText: { color: '#9CA3AF', fontSize: 16 },

  // Header card - FPL style
  headerCard: {
    marginHorizontal: 0,
    paddingHorizontal: 16,
    paddingTop: 8,
    paddingBottom: 16,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  backBtn: { padding: 6, marginRight: 8 },
  headerCenter: { flex: 1 },
  headerName: { color: '#FFFFFF', fontSize: 22, fontWeight: 'bold' },
  headerMeta: { flexDirection: 'row', alignItems: 'center', marginTop: 4, gap: 8 },
  symbolBadge: {
    backgroundColor: 'rgba(59, 130, 246, 0.25)',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 6,
  },
  symbolBadgeText: { color: '#60A5FA', fontSize: 12, fontWeight: 'bold', letterSpacing: 0.5 },
  sectorChip: { color: '#9CA3AF', fontSize: 12, fontWeight: '500' },
  watchlistBtn: { padding: 6 },

  // Price section
  priceSection: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 12,
    paddingLeft: 4,
  },
  priceMain: { color: '#FFFFFF', fontSize: 20, fontWeight: 'bold' },
  changeBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 5,
  },
  changeBadgeUp: { backgroundColor: '#2563EB' },
  changeBadgeDown: { backgroundColor: '#DC2626' },
  changeBadgeFlat: { backgroundColor: '#6B7280' },
  changeBadgeText: { color: '#fff', fontWeight: 'bold', fontSize: 13, marginLeft: 2 },

  // FPL-style stats strip
  statsStripContainer: {
    backgroundColor: 'rgba(15, 23, 42, 0.8)',
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
  },
  statsStripContent: {
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  statsStripDivider: {
    width: 1,
    backgroundColor: 'rgba(75, 85, 99, 0.4)',
    marginHorizontal: 2,
    alignSelf: 'stretch',
  },
  statBox: {
    alignItems: 'center',
    paddingHorizontal: 12,
    minWidth: 70,
  },
  statBoxLabel: {
    color: '#9CA3AF',
    fontSize: 10,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.3,
    marginBottom: 2,
  },
  statBoxValue: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: 'bold',
  },
  statBoxSub: {
    color: '#6B7280',
    fontSize: 10,
    marginTop: 1,
  },

  // Tabs - compact pills with icon and underline indicator
  tabContainer: {
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
  },
  tabScroll: { paddingHorizontal: 12, paddingTop: 8, paddingBottom: 0 },
  tab: {
    paddingHorizontal: 12,
    paddingTop: 7,
    paddingBottom: 10,
    marginRight: 4,
    borderRadius: 0,
    backgroundColor: 'transparent',
    alignItems: 'center',
  },
  activeTab: {
    backgroundColor: 'transparent',
  },
  tabInner: { flexDirection: 'row', alignItems: 'center' },
  tabText: { color: '#6B7280', fontSize: 12, fontWeight: '600' },
  activeTabText: { color: '#FFFFFF' },
  tabIndicator: {
    position: 'absolute',
    bottom: 0,
    left: 8,
    right: 8,
    height: 2,
    backgroundColor: '#3B82F6',
    borderTopLeftRadius: 2,
    borderTopRightRadius: 2,
  },

  content: { flex: 1 },
});
