// screens/LeaderboardScreen.tsx
import React, { useState } from 'react';
import {
  View,
  Text,
  FlatList,
  RefreshControl,
  StyleSheet,
  ActivityIndicator,
  TouchableOpacity
} from 'react-native';
import { useLeaderboard, PortfolioType } from '../hooks/useLeaderboard';
import { formatCurrency, formatPercentage } from '../utils/formatting';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function LeaderboardScreen() {
  const [activeTab, setActiveTab] = useState<PortfolioType>('weekly');
  const { leaderboard, loading, error, refresh, lastUpdated } = useLeaderboard(activeTab);

  const renderPortfolioTab = (type: PortfolioType, label: string) => (
    <TouchableOpacity
      style={[
        styles.tab,
        activeTab === type && styles.activeTab
      ]}
      onPress={() => setActiveTab(type)}
    >
      <Text style={[
        styles.tabText,
        activeTab === type && styles.activeTabText
      ]}>
        {label}
      </Text>
    </TouchableOpacity>
  );

  const renderLeaderboardItem = ({ item, index }: { item: any; index: number }) => (
    <View style={[
      styles.leaderboardItem,
      item.is_current_user && styles.currentUserItem
    ]}>
      <View style={styles.rankContainer}>
        <Text style={styles.rankText}>{index + 1}</Text>
      </View>
      <View style={styles.userInfo}>
        <Text style={styles.username}>{item.username}</Text>
        <Text style={styles.holdingsCount}>{item.holdings_count} holdings</Text>
      </View>
      <View style={styles.performanceInfo}>
        <Text style={styles.portfolioValue}>
          {formatCurrency(item.portfolio_value)}
        </Text>
        <Text style={[
          styles.profitLoss,
          item.profit_loss >= 0 ? styles.profit : styles.loss
        ]}>
          {formatPercentage(item.profit_loss_percentage)}
        </Text>
      </View>
    </View>
  );

  if (error) {
    return (
      <View style={styles.centerContainer}>
        <Text style={styles.errorText}>{error}</Text>
        <TouchableOpacity style={styles.retryButton} onPress={refresh}>
          <Text style={styles.retryButtonText}>Try Again</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.tabContainer}>
        {renderPortfolioTab('weekly', 'Weekly')}
        {renderPortfolioTab('monthly', 'Monthly')}
        {renderPortfolioTab('annual', 'Annual')}
      </View>

      <FlatList
        data={leaderboard}
        renderItem={renderLeaderboardItem}
        keyExtractor={(item) => item.user_id}
        contentContainerStyle={styles.listContainer}
        refreshControl={
          <RefreshControl
            refreshing={loading}
            onRefresh={refresh}
            tintColor="#0066cc"
          />
        }
        ListEmptyComponent={
          !loading ? (
            <View style={styles.emptyContainer}>
              <Text style={styles.emptyText}>No entries yet</Text>
              <Text style={styles.emptySubText}>
                Be the first to join this competition!
              </Text>
            </View>
          ) : null
        }
      />

      {lastUpdated && (
        <Text style={styles.lastUpdated}>
          Last updated: {lastUpdated.toLocaleTimeString()}
        </Text>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  tabContainer: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: '#f5f5f5',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  tab: {
    flex: 1,
    paddingVertical: 8,
    alignItems: 'center',
    borderRadius: 8,
    marginHorizontal: 4,
  },
  activeTab: {
    backgroundColor: '#0066cc',
  },
  tabText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#666',
  },
  activeTabText: {
    color: '#fff',
  },
  listContainer: {
    flexGrow: 1,
    padding: 16,
  },
  leaderboardItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#fff',
    borderRadius: 8,
    marginBottom: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  currentUserItem: {
    backgroundColor: '#f0f7ff',
    borderWidth: 1,
    borderColor: '#0066cc',
  },
  rankContainer: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#f5f5f5',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  rankText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  userInfo: {
    flex: 1,
  },
  username: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  holdingsCount: {
    fontSize: 12,
    color: '#666',
    marginTop: 2,
  },
  performanceInfo: {
    alignItems: 'flex-end',
  },
  portfolioValue: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  profitLoss: {
    fontSize: 14,
    fontWeight: '500',
    marginTop: 2,
  },
  profit: {
    color: '#22c55e',
  },
  loss: {
    color: '#ef4444',
  },
  centerContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
  },
  errorText: {
    fontSize: 16,
    color: '#ef4444',
    textAlign: 'center',
    marginBottom: 16,
  },
  retryButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: '#0066cc',
    borderRadius: 8,
  },
  retryButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 32,
  },
  emptyText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  emptySubText: {
    fontSize: 14,
    color: '#666',
  },
  lastUpdated: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
    paddingVertical: 8,
    backgroundColor: '#f5f5f5',
  },
});
