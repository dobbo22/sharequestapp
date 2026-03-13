import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  RefreshControl,
  TouchableOpacity,
  TextInput,
  FlatList,
  ActivityIndicator,
  ScrollView,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { apiService } from '../../src/services/api';
import { useWatchlistStore } from '../../src/stores/watchlistStore';

// Sector colors for pie chart
const SECTOR_COLORS = [
  '#3B82F6', '#8B5CF6', '#EC4899', '#10B981', '#F59E0B',
  '#EF4444', '#06B6D4', '#6366F1', '#14B8A6', '#F97316',
  '#84CC16', '#A855F7', '#22D3EE', '#FB923C', '#4ADE80',
];


type TabType = 'ftse100' | 'ftse250' | 'sectors' | 'watchlist' | 'search';

interface SectorData {
  sector: string;
  count: number;
  stock_count?: number;
}

interface SubsectorData {
  subsector: string;
  count: number;
  stock_count?: number;
  stocks: Array<{
    symbol: string;
    companyname: string;
    listing_id: string | null;
    ytd?: number | null;
  }>;
}

interface StockWithQuote {
  symbol: string;
  companyname: string;
  listing_id: string | null;
  price?: number;
  change?: number;
  changePercent?: number;
  ytd?: number | null;
}

interface Stock {
  symbol: string;
  company_name?: string;
  companyname?: string;
  name?: string;
  current_price?: number;
  price?: number;
  change_amount?: number;
  change?: number;
  change_percent?: number;
  changePercent?: number;
  ytd?: number | null;
  sector?: string;
  market_cap?: number;
  marketCap?: number;
}

export default function StocksScreen() {
  const router = useRouter();
  const params = useLocalSearchParams();

  // Watchlist store
  const { watchlist, loadWatchlist, isInWatchlist, toggleWatchlist } = useWatchlistStore();
  const [watchlistStocks, setWatchlistStocks] = useState<Stock[]>([]);

  const [activeTab, setActiveTab] = useState<TabType>('ftse100');
  const [stocks, setStocks] = useState<Stock[]>([]);
  const [searchResults, setSearchResults] = useState<Stock[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  // Sectors state
  const [sectors, setSectors] = useState<SectorData[]>([]);
  const [subsectors, setSubsectors] = useState<SubsectorData[]>([]);
  const [selectedSector, setSelectedSector] = useState<string | null>(null);
  const [selectedSubsector, setSelectedSubsector] = useState<SubsectorData | null>(null);
  const [, setSectorCache] = useState<Record<string, SubsectorData[]>>({});
  const [sectorsLoading, setSectorsLoading] = useState(false);

  // Stock quotes state (for sector drill-down)
  const [stockQuotes, setStockQuotes] = useState<Record<string, StockWithQuote>>({});

  // Sort subsector stocks alphabetically by company name
  const sortedStockQuotes = useMemo(() => {
    return Object.values(stockQuotes).slice().sort((a, b) => {
      const aStr = (a.companyname || a.symbol || '').toUpperCase();
      const bStr = (b.companyname || b.symbol || '').toUpperCase();
      return aStr < bStr ? -1 : aStr > bStr ? 1 : 0;
    });
  }, [stockQuotes]);

  // Load watchlist on mount
  useEffect(() => {
    loadWatchlist();
  }, []);

  // Fetch sectors for the stocks page
  const fetchSectors = useCallback(async () => {
    setSectorsLoading(true);
    try {
      const response = await apiService.request<{ sectors?: SectorData[] }>(`/stocks/sectors`);
      if (response.success && response.data) {
        const sectorList = (response.data.sectors || []).map((s: SectorData & { stock_count?: number }) => ({
          sector: s.sector,
          count: s.stock_count || s.count || 0,
        }));
        setSectors(sectorList);
      }
    } catch (err) {
      console.error('Error fetching sectors:', err);
    } finally {
      setSectorsLoading(false);
    }
  }, []);

  // Fetch subsectors for a sector
  const fetchSubsectors = useCallback(async (sectorName: string) => {
    setSectorsLoading(true);
    try {
      const response = await apiService.request<{ subsectors?: SubsectorData[] }>(`/stocks/sectors?sector=${encodeURIComponent(sectorName)}`);
      if (response.success && response.data) {
        const subsectorList = (response.data.subsectors || []).map((s: SubsectorData & { stock_count?: number }) => ({
          subsector: s.subsector,
          count: s.stock_count || s.count,
          stocks: s.stocks || [],
        }));
        setSubsectors(subsectorList);
        setSectorCache(prev => ({ ...prev, [sectorName]: subsectorList }));
      }
    } catch (err) {
      console.error('Error fetching subsectors:', err);
    } finally {
      setSectorsLoading(false);
    }
  }, []);

  // Fetch stock prices using the mobile batch-prices endpoint (max 50 per request)
  const fetchStockPrices = useCallback(async (stocksList: Array<{ symbol: string; companyname: string; listing_id: string | null }>) => {
    setSectorsLoading(true);
    try {
      const symbols = stocksList.map(s => s.symbol);
      if (symbols.length === 0) {
        setStockQuotes({});
        setSectorsLoading(false);
        return;
      }

      // Batch into chunks of 50 (API limit)
      const batchSize = 50;
      let allPriceData: Record<string, { price?: number; change?: number; changePercent?: number; ytd?: number }> = {};
      for (let i = 0; i < symbols.length; i += batchSize) {
        const batch = symbols.slice(i, i + batchSize);
        const priceResponse = await apiService.getBatchPrices(batch);
        if (priceResponse.success && priceResponse.data) {
          allPriceData = { ...allPriceData, ...priceResponse.data };
        }
      }

      const quotes: Record<string, StockWithQuote> = {};
      stocksList.forEach(s => {
        const priceData = allPriceData[s.symbol] || null;
        quotes[s.symbol] = {
          ...s,
          price: priceData?.price,
          change: priceData?.change,
          changePercent: priceData?.changePercent,
          ytd: priceData?.ytd ?? null,
        };
      });

      setStockQuotes(quotes);
    } catch (err) {
      console.error('Error fetching stock prices:', err);
    } finally {
      setSectorsLoading(false);
    }
  }, []);

  // Handle sector selection
  const handleSectorSelect = useCallback((sectorName: string) => {
    setSelectedSector(sectorName);
    setSelectedSubsector(null);
    setStockQuotes({});
    fetchSubsectors(sectorName);
  }, [fetchSubsectors]);

  // Handle subsector selection
  const handleSubsectorSelect = useCallback(async (subsector: SubsectorData) => {
    setSelectedSubsector(subsector);
    setSectorsLoading(true);
    try {
      const response = await apiService.request<{ subsectors?: SubsectorData[] }>(`/stocks/sectors?sector=${encodeURIComponent(selectedSector || '')}`);
      if (response.success && response.data && Array.isArray(response.data.subsectors)) {
        const match = response.data.subsectors.find((s: any) => s.subsector === subsector.subsector);
        if (match && Array.isArray(match.stocks)) {
          await fetchStockPrices(match.stocks);
        } else {
          setStockQuotes({});
        }
      } else {
        setStockQuotes({});
      }
    } catch (err) {
      setStockQuotes({});
      console.error('Error fetching stocks for subsector:', err);
    } finally {
      setSectorsLoading(false);
    }
  }, [fetchStockPrices, selectedSector]);

  // Handle back navigation in sectors
  const handleSectorsBack = useCallback(() => {
    if (selectedSubsector) {
      setSelectedSubsector(null);
      setStockQuotes({});
    } else if (selectedSector) {
      setSelectedSector(null);
      setSubsectors([]);
    }
  }, [selectedSector, selectedSubsector]);

  // Load sectors when tab changes
  useEffect(() => {
    if (activeTab === 'sectors' && sectors.length === 0) {
      fetchSectors();
    }
    if (activeTab === 'sectors') {
      apiService.updateChallengeProgress('sector').catch(() => {});
    }
  }, [activeTab, sectors.length, fetchSectors]);

  const fetchStocks = useCallback(async () => {
    try {
      let response;
      if (activeTab === 'ftse100') {
        response = await apiService.getFTSE100(100);
      } else if (activeTab === 'ftse250') {
        response = await apiService.getFTSE250(250);
      } else if (activeTab === 'watchlist') {
        if (watchlist.length > 0) {
          const symbols = watchlist.map(w => w.symbol);
          const priceResponse = await apiService.getBatchPrices(symbols);
          if (priceResponse.success && priceResponse.data) {
            const priceData = priceResponse.data;
            const watchlistData: Stock[] = symbols.map(symbol => ({
              symbol,
              current_price: priceData[symbol]?.price,
              change_amount: priceData[symbol]?.change,
              change_percent: priceData[symbol]?.changePercent,
              ytd: priceData[symbol]?.ytd ?? null,
              company_name: priceData[symbol]?.companyName || symbol,
            }));
            setWatchlistStocks(watchlistData);
          }
        } else {
          setWatchlistStocks([]);
        }
        setLoading(false);
        return;
      }

      if (response?.success && response.data) {
        const stockData = Array.isArray(response.data) ? response.data : [];
        setStocks(stockData);

        // Enrich with live Infront prices in batches of 50
        const symbols = stockData.map((s: { symbol: string }) => s.symbol).filter(Boolean);
        if (symbols.length > 0) {
          const batchSize = 50;
          const allPrices: Record<string, { price?: number; change?: number; changePercent?: number; bid?: number; ask?: number; ytd?: number | null }> = {};
          for (let i = 0; i < symbols.length; i += batchSize) {
            const batch = symbols.slice(i, i + batchSize);
            try {
              const priceResponse = await apiService.getBatchPrices(batch);
              if (priceResponse.success && priceResponse.data) {
                Object.assign(allPrices, priceResponse.data);
              }
            } catch (batchErr) {
              console.warn('Batch price fetch failed for batch', i, batchErr);
            }
          }
          // Merge live prices into stock data
          if (Object.keys(allPrices).length > 0) {
            setStocks(prev => prev.map(stock => {
              const live = allPrices[stock.symbol];
              if (!live) return stock;
              return {
                ...stock,
                price: live.price || stock.price,
                current_price: live.price || stock.current_price,
                change: live.change ?? stock.change,
                change_amount: live.change ?? stock.change_amount,
                changePercent: live.changePercent ?? stock.changePercent,
                change_percent: live.changePercent ?? stock.change_percent,
              };
            }));
          }
        }
      }
    } catch (err) {
      console.error('Error fetching stocks:', err);
    } finally {
      setLoading(false);
    }
  }, [activeTab, watchlist]);

  useEffect(() => {
    if (activeTab !== 'search') {
      setLoading(true);
      fetchStocks();
    }
  }, [fetchStocks, activeTab]);

  useEffect(() => {
    if (params.symbol) {
      openStockDetail({ symbol: params.symbol as string });
    }
  }, [params.symbol]);

  const onRefresh = async () => {
    setRefreshing(true);
    await fetchStocks();
    setRefreshing(false);
  };

  const handleSearch = async (query: string) => {
    setSearchQuery(query);
    if (query.length < 2) {
      setSearchResults([]);
      return;
    }

    try {
      const response = await apiService.searchStocks(query);
      if (response.success && response.data) {
        setSearchResults(Array.isArray(response.data) ? response.data : []);
      }
    } catch (err) {
      console.error('Search error:', err);
    }
  };

  const openStockDetail = (stock: Stock | { symbol: string }) => {
    router.push(`/stock/${stock.symbol}`);
  };

  const formatPrice = (pence?: number) => {
    if (!pence) return '--';
    return `${pence.toFixed(2)}p`;
  };

  const formatChange = (change?: number, percent?: number) => {
    if (change === undefined || percent === undefined) return { text: '--', isPositive: true };
    const sign = change >= 0 ? '+' : '';
    return {
      text: `${sign}${change.toFixed(2)}p (${sign}${percent.toFixed(2)}%)`,
      isPositive: change >= 0,
    };
  };

  const formatMarketCap = (cap?: number) => {
    if (!cap) return null;
    if (cap >= 1e12) return `£${(cap / 1e12).toFixed(1)}T`;
    if (cap >= 1e9) return `£${(cap / 1e9).toFixed(1)}B`;
    if (cap >= 1e6) return `£${(cap / 1e6).toFixed(1)}M`;
    return null;
  };

  const renderStockItem = ({ item }: { item: Stock }) => {
        if (item.symbol === 'AZN.L') {
          console.log('AZN.L debug:', {
            market_cap: item.market_cap,
            marketCap: item.marketCap,
            formatted: formatMarketCap(item.market_cap || item.marketCap),
          });
        }
    const price = item.current_price || item.price || 0;
    const change = item.change_amount || item.change || 0;
    const changePercent = item.change_percent || item.changePercent || 0;
    const changeInfo = formatChange(change, changePercent);
    const name = item.company_name || item.companyname || item.name || item.symbol;
    const marketCap = formatMarketCap(item.market_cap || item.marketCap);

    return (
      <TouchableOpacity style={styles.stockCard} onPress={() => openStockDetail(item)}>
        <View style={styles.stockLeft}>
          {/* Company name on its own line */}
          <View style={{ flexDirection: 'row', alignItems: 'center' }}>
            <Text style={styles.stockName} numberOfLines={1}>{name.toUpperCase()}</Text>
            <TouchableOpacity
              onPress={() => toggleWatchlist(item.symbol)}
              style={{ marginLeft: 8 }}
              hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
            >
              <MaterialCommunityIcons
                name={isInWatchlist(item.symbol) ? 'star' : 'star-outline'}
                size={16}
                color={isInWatchlist(item.symbol) ? '#F59E0B' : '#6B7280'}
              />
            </TouchableOpacity>
          </View>
          {/* Symbol and price on the same line */}
          <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 2 }}>
            <Text style={styles.stockSymbol}>{item.symbol}</Text>
            <Text style={[styles.stockPrice, { marginLeft: 12 }]}>{formatPrice(price)}</Text>
          </View>
          {/* Sector (optional) */}
          {item.sector && <Text style={styles.stockSector}>{item.sector}</Text>}
          {/* Market cap with title */}
          {marketCap && (
            <Text style={styles.stockMarketCap}>
              Market Cap: {marketCap}
            </Text>
          )}
        </View>
        <View style={styles.stockRight}>
          <View style={styles.changeContainer}>
            <MaterialCommunityIcons
              name={changeInfo.isPositive ? 'menu-up' : 'menu-down'}
              size={16}
              color={changeInfo.isPositive ? '#10B981' : '#EF4444'}
            />
            <Text style={[styles.stockChange, { color: changeInfo.isPositive ? '#10B981' : '#EF4444' }]}> 
              {changeInfo.text}
            </Text>
          </View>
          {item.ytd != null && (
            <Text style={[styles.stockYtd, { color: item.ytd >= 0 ? '#10B981' : '#EF4444' }]}> 
              YTD: {item.ytd >= 0 ? '+' : ''}{item.ytd.toFixed(1)}%
            </Text>
          )}
        </View>
      </TouchableOpacity>
    );
  };

  const displayStocks = activeTab === 'search' ? searchResults : activeTab === 'watchlist' ? watchlistStocks : stocks;

  return (
    <View style={styles.container}>
      <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />

      <SafeAreaView style={styles.safeArea} edges={['top']}>
        <View style={styles.header}>
          <Text style={styles.headerTitle}>Stocks</Text>
        </View>

        <View style={styles.searchContainer}>
          <MaterialCommunityIcons name="magnify" size={20} color="#9CA3AF" style={styles.searchIcon} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search stocks..."
            placeholderTextColor="#6B7280"
            value={searchQuery}
            onChangeText={handleSearch}
            onFocus={() => setActiveTab('search')}
          />
          {searchQuery.length > 0 && (
            <TouchableOpacity onPress={() => { setSearchQuery(''); setSearchResults([]); }}>
              <MaterialCommunityIcons name="close-circle" size={20} color="#6B7280" />
            </TouchableOpacity>
          )}
        </View>

        <View style={styles.tabsWrapper}>
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
            contentContainerStyle={{ paddingHorizontal: 16, gap: 8, alignItems: 'center' }}
          >
            <TouchableOpacity
              style={[styles.tab, activeTab === 'ftse100' && styles.activeTab]}
              onPress={() => { setActiveTab('ftse100'); setSearchQuery(''); }}
            >
              <Text style={[styles.tabText, activeTab === 'ftse100' && styles.activeTabText]}>Top 100</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.tab, activeTab === 'ftse250' && styles.activeTab]}
              onPress={() => { setActiveTab('ftse250'); setSearchQuery(''); }}
            >
              <Text style={[styles.tabText, activeTab === 'ftse250' && styles.activeTabText]}>Top 250</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.tab, activeTab === 'sectors' && styles.sectorsTab]}
              onPress={() => { setActiveTab('sectors'); setSearchQuery(''); setSelectedSector(null); setSelectedSubsector(null); }}
            >
              <MaterialCommunityIcons
                name="chart-pie"
                size={14}
                color={activeTab === 'sectors' ? '#FFFFFF' : '#9CA3AF'}
                style={{ marginRight: 4 }}
              />
              <Text style={[styles.tabText, activeTab === 'sectors' && styles.sectorsTabText]}>Sectors</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.tab, activeTab === 'watchlist' && styles.watchlistTab]}
              onPress={() => { setActiveTab('watchlist'); setSearchQuery(''); }}
            >
              <MaterialCommunityIcons
                name={activeTab === 'watchlist' ? 'star' : 'star-outline'}
                size={14}
                color={activeTab === 'watchlist' ? '#FFFFFF' : '#9CA3AF'}
                style={{ marginRight: 4 }}
              />
              <Text style={[styles.tabText, activeTab === 'watchlist' && styles.watchlistTabText]}>
                Watchlist
              </Text>
            </TouchableOpacity>
          </ScrollView>
        </View>

        {/* Pie chart now scrolls with content in sectors view */}
        {/* For stocks list (FlatList), use ListHeaderComponent. For sectors/subsectors, place at top of ScrollView. */}

        {loading && activeTab !== 'sectors' ? (
          <View style={styles.loadingContainer}>
            <ActivityIndicator size="large" color="#3B82F6" />
          </View>
        ) : activeTab === 'search' && searchQuery.length < 2 ? (
          <View style={styles.emptyContainer}>
            <MaterialCommunityIcons name="magnify" size={48} color="#4B5563" />
            <Text style={styles.emptyText}>Enter at least 2 characters to search</Text>
          </View>
        ) : activeTab === 'sectors' ? (
          <View style={styles.sectorsContainer}>
            {/* Back button when drilled down */}
            {(selectedSector || selectedSubsector) && (
              <TouchableOpacity style={styles.backButton} onPress={handleSectorsBack}>
                <MaterialCommunityIcons name="chevron-left" size={20} color="#8B5CF6" />
                <Text style={styles.backButtonText}>
                  {selectedSubsector ? selectedSector : 'All Sectors'}
                </Text>
              </TouchableOpacity>
            )}

            {/* Current view title */}
            <View style={styles.sectorHeader}>
              <MaterialCommunityIcons name="chart-pie" size={24} color="#8B5CF6" />
              <Text style={styles.sectorHeaderTitle}>
                {selectedSubsector ? selectedSubsector.subsector : selectedSector || 'Sectors'}
              </Text>
              {selectedSubsector && (
                <Text style={styles.sectorHeaderCount}>{Array.isArray(selectedSubsector.stocks) ? selectedSubsector.stocks.length : 0} stocks</Text>
              )}
            </View>

            {sectorsLoading ? (
              <View style={styles.loadingContainer}>
                <ActivityIndicator size="large" color="#8B5CF6" />
              </View>
            ) : selectedSubsector ? (
              /* Stocks list view - reuses same card style as Top 100/250 */
              <FlatList
                data={sortedStockQuotes}
                keyExtractor={(item) => item.symbol}
                contentContainerStyle={styles.listContent}
                renderItem={({ item }) => {
                  const price = item.price || 0;
                  const change = item.change || 0;
                  const changePct = item.changePercent || 0;
                  const changeInfo = formatChange(change, changePct);
                  const name = item.companyname || item.symbol;
                  return (
                    <TouchableOpacity style={styles.stockCard} onPress={() => openStockDetail({ symbol: item.symbol })}>
                      <View style={styles.stockLeft}>
                        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                          <Text style={styles.stockName} numberOfLines={1}>{name.toUpperCase()}</Text>
                          <TouchableOpacity
                            onPress={() => toggleWatchlist(item.symbol)}
                            style={{ marginLeft: 8 }}
                            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                          >
                            <MaterialCommunityIcons
                              name={isInWatchlist(item.symbol) ? 'star' : 'star-outline'}
                              size={16}
                              color={isInWatchlist(item.symbol) ? '#F59E0B' : '#6B7280'}
                            />
                          </TouchableOpacity>
                        </View>
                        <Text style={styles.stockSymbol}>{item.symbol}</Text>
                      </View>
                      <View style={styles.stockRight}>
                        <Text style={styles.stockPrice}>{formatPrice(price)}</Text>
                        <View style={styles.changeContainer}>
                          <MaterialCommunityIcons
                            name={changeInfo.isPositive ? 'menu-up' : 'menu-down'}
                            size={16}
                            color={changeInfo.isPositive ? '#10B981' : '#EF4444'}
                          />
                          <Text style={[styles.stockChange, { color: changeInfo.isPositive ? '#10B981' : '#EF4444' }]}>
                            {changeInfo.text}
                          </Text>
                        </View>
                        {item.ytd != null && (
                          <Text style={[styles.stockYtd, { color: (item.ytd ?? 0) >= 0 ? '#10B981' : '#EF4444' }]}>
                            YTD: {item.ytd >= 0 ? '+' : ''}{item.ytd.toFixed(1)}%
                          </Text>
                        )}
                      </View>
                    </TouchableOpacity>
                  );
                }}
                ListEmptyComponent={
                  <View style={styles.emptyContainer}>
                    <Text style={styles.emptyText}>No stocks found</Text>
                  </View>
                }
              />
            ) : selectedSector ? (
              /* Subsectors list view - clean cards with proportional bars */
              <ScrollView
                contentContainerStyle={styles.listContent}
                refreshControl={
                  <RefreshControl
                    refreshing={sectorsLoading}
                    onRefresh={fetchSectors}
                    tintColor="#8B5CF6"
                  />
                }
              >
                {subsectors.length > 0 ? (
                  (() => {
                    const maxCount = Math.max(...subsectors.map(s => Number(s.count ?? s.stock_count ?? 0)));
                    return subsectors.map((item, index) => {
                      const count = Number(item.count ?? item.stock_count ?? 0);
                      const barWidth = maxCount > 0 ? (count / maxCount) * 100 : 0;
                      const color = SECTOR_COLORS[index % SECTOR_COLORS.length];
                      return (
                        <TouchableOpacity
                          key={item.subsector}
                          style={styles.sectorCard}
                          onPress={() => handleSubsectorSelect(item)}
                        >
                          <View style={{ flex: 1 }}>
                            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                              <View style={{ flexDirection: 'row', alignItems: 'center', flex: 1 }}>
                                <View style={[styles.sectorColorDot, { backgroundColor: color }]} />
                                <Text style={styles.sectorCardTitle} numberOfLines={1}>{item.subsector}</Text>
                              </View>
                              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                                <Text style={styles.sectorCardCount}>{count} stocks</Text>
                                <MaterialCommunityIcons name="chevron-right" size={18} color="#6B7280" style={{ marginLeft: 8 }} />
                              </View>
                            </View>
                            {/* Proportional bar */}
                            <View style={{ height: 4, backgroundColor: 'rgba(75, 85, 99, 0.3)', borderRadius: 2 }}>
                              <View style={{ height: 4, width: `${barWidth}%`, backgroundColor: color, borderRadius: 2 }} />
                            </View>
                          </View>
                        </TouchableOpacity>
                      );
                    });
                  })()
                ) : (
                  <View style={styles.emptyContainer}>
                    <Text style={styles.emptyText}>No subsectors found</Text>
                  </View>
                )}
              </ScrollView>
            ) : (
              /* Sectors list view - clean cards with proportional bars */
              <ScrollView
                contentContainerStyle={styles.listContent}
                refreshControl={
                  <RefreshControl
                    refreshing={sectorsLoading}
                    onRefresh={fetchSectors}
                    tintColor="#8B5CF6"
                  />
                }
              >
                {sectors.length > 0 ? (
                  (() => {
                    const maxCount = Math.max(...sectors.map(s => s.count ?? 0));
                    return sectors.map((item, index) => {
                      const barWidth = maxCount > 0 ? ((item.count ?? 0) / maxCount) * 100 : 0;
                      const color = SECTOR_COLORS[index % SECTOR_COLORS.length];
                      return (
                        <TouchableOpacity
                          key={item.sector}
                          style={styles.sectorCard}
                          onPress={() => handleSectorSelect(item.sector)}
                        >
                          <View style={{ flex: 1 }}>
                            <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                              <View style={{ flexDirection: 'row', alignItems: 'center', flex: 1 }}>
                                <View style={[styles.sectorColorDot, { backgroundColor: color }]} />
                                <Text style={styles.sectorCardTitle} numberOfLines={1}>{item.sector}</Text>
                              </View>
                              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                                <Text style={styles.sectorCardCount}>{item.count} stocks</Text>
                                <MaterialCommunityIcons name="chevron-right" size={18} color="#6B7280" style={{ marginLeft: 8 }} />
                              </View>
                            </View>
                            {/* Proportional bar */}
                            <View style={{ height: 4, backgroundColor: 'rgba(75, 85, 99, 0.3)', borderRadius: 2 }}>
                              <View style={{ height: 4, width: `${barWidth}%`, backgroundColor: color, borderRadius: 2 }} />
                            </View>
                          </View>
                        </TouchableOpacity>
                      );
                    });
                  })()
                ) : (
                  <View style={styles.emptyContainer}>
                    <MaterialCommunityIcons name="chart-pie" size={48} color="#4B5563" />
                    <Text style={styles.emptyText}>No sectors available</Text>
                  </View>
                )}
              </ScrollView>
            )}
          </View>
        ) : (
          <FlatList
            data={displayStocks}
            renderItem={renderStockItem}
            keyExtractor={(item) => item.symbol}
            contentContainerStyle={styles.listContent}
            refreshControl={
              activeTab !== 'search' ? (
                <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#3B82F6" />
              ) : undefined
            }
            ListEmptyComponent={
              <View style={styles.emptyContainer}>
                <MaterialCommunityIcons
                  name={activeTab === 'watchlist' ? 'star-outline' : 'chart-line'}
                  size={48}
                  color="#4B5563"
                />
                <Text style={styles.emptyText}>
                  {activeTab === 'search' ? 'No stocks found' : activeTab === 'watchlist' ? 'Your watchlist is empty' : 'No stocks available'}
                </Text>
                {activeTab === 'watchlist' && (
                  <Text style={styles.emptySubtext}>Tap the star icon on any stock to add it here</Text>
                )}
              </View>
            }
          />
        )}
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  safeArea: { flex: 1 },
  header: { paddingHorizontal: 20, paddingVertical: 16 },
  headerTitle: { color: '#FFFFFF', fontSize: 28, fontWeight: 'bold' },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.8)',
    marginHorizontal: 20,
    borderRadius: 12,
    paddingHorizontal: 12,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  searchIcon: { marginRight: 8 },
  searchInput: { flex: 1, color: '#FFFFFF', fontSize: 16, paddingVertical: 12 },
  tabsWrapper: {
    height: 52,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
    justifyContent: 'center',
  },
  tab: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: 'rgba(31, 41, 55, 0.6)',
  },
  activeTab: { backgroundColor: '#3B82F6' },
  watchlistTab: { backgroundColor: '#D97706' },
  sectorsTab: { backgroundColor: '#7C3AED' },
  tabText: { color: '#9CA3AF', fontSize: 13, fontWeight: '600' },
  activeTabText: { color: '#FFFFFF' },
  watchlistTabText: { color: '#FFFFFF' },
  sectorsTabText: { color: '#FFFFFF' },
  loadingContainer: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  emptyContainer: { flex: 1, justifyContent: 'center', alignItems: 'center', paddingTop: 60 },
  emptyText: { color: '#9CA3AF', fontSize: 16, marginTop: 16 },
  emptySubtext: { color: '#6B7280', fontSize: 14, marginTop: 8, textAlign: 'center' },
  listContent: { paddingHorizontal: 20, paddingBottom: 100 },
  stockCard: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    backgroundColor: 'rgba(31, 41, 55, 0.6)',
    borderRadius: 12,
    padding: 16,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.4)',
  },
  stockLeft: { flex: 1, marginRight: 12 },
  stockName: { color: '#FFFFFF', fontSize: 16, fontWeight: 'bold', flex: 1 },
  stockSymbol: { color: '#D1D5DB', fontSize: 14, marginTop: 3 },
  stockSector: { color: '#9CA3AF', fontSize: 12, marginTop: 4 },
  stockRight: { alignItems: 'flex-end' },
  stockPrice: { color: '#FFFFFF', fontSize: 18, fontWeight: '700' },
  changeContainer: { flexDirection: 'row', alignItems: 'center', marginTop: 4 },
  stockChange: { fontSize: 13, fontWeight: '600', marginLeft: 2 },
  stockYtd: { fontSize: 12, fontWeight: '500', marginTop: 4 },
  stockMarketCap: { color: '#9CA3AF', fontSize: 12, marginTop: 4 },
  sectorsContainer: { flex: 1 },
  backButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 12,
    backgroundColor: 'rgba(139, 92, 246, 0.1)',
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(139, 92, 246, 0.2)',
  },
  backButtonText: { color: '#8B5CF6', fontSize: 14, fontWeight: '600', marginLeft: 4 },
  sectorHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
  },
  sectorHeaderTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold', marginLeft: 12, flex: 1 },
  sectorHeaderCount: { color: '#9CA3AF', fontSize: 14 },
  sectorCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 16,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  sectorCardLeft: { flexDirection: 'row', alignItems: 'center', flex: 1 },
  sectorCardTitle: { color: '#FFFFFF', fontSize: 15, fontWeight: '600' },
  sectorCardCount: { color: '#6B7280', fontSize: 12, marginTop: 2 },
  sectorColorDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 12,
  },
});
