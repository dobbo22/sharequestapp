// ...existing imports...

// Format time left as a human readable countdown (days/hours/minutes)
const formatTimeLeft = (timeLeft?: string | number) => {
  const n = Number(timeLeft);
  if (!n || isNaN(n) || n < 0 || n > 315360000) return '--'; // sanity check
  const days = Math.floor(n / (60 * 60 * 24));
  const hours = Math.floor((n % (60 * 60 * 24)) / 3600);
  const minutes = Math.floor((n % 3600) / 60);
  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours}h ${minutes}m`;
  if (minutes > 0) return `${minutes}m`;
  return '<1m';
};
import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  RefreshControl,
  TouchableOpacity,
  FlatList,
  ActivityIndicator,
  Modal,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useAuth } from '../../src/hooks/useAuth';
import { apiService } from '../../src/services/api';
import { PlayerLevelBadge } from '../../src/components/gamification';
import LeaderboardChampionCard from '../../components/LeaderboardChampionCard';
import LeaderboardContenderCard from '../../components/LeaderboardContenderCard';
import LeaderboardOtherCard from '../../components/LeaderboardOtherCard';

type CompetitionType = 'weekly' | 'monthly' | 'annual';

interface LeaderboardEntry {
  rank: number;
  user_id: string;
  username: string;
  total_portfolio_value: number;
  total_assets?: number;
  profit_loss: number;
  profit_loss_percent: number;
  cash_balance?: number;
  player_level?: number;
  avatar_url?: string | null;
}

interface CompetitionInfo {
  status?: string;
  start_date?: string;
  end_date?: string;
  prize_pool?: number;
  time_remaining?: string;
  total_participants?: number;
}

interface UserPortfolio {
  rank?: number;
  cash_balance: number;
  holdings: Array<{
    symbol: string;
    company_name?: string;
    quantity: number;
    average_price: number;
    current_price: number;
  }>;
}

const COMPETITION_CONFIG: Record<CompetitionType, { label: string; title: string; color: string; icon: keyof typeof MaterialCommunityIcons.glyphMap }> = {
  weekly: { label: 'Weekly', title: 'Weekly ShareQuest', color: '#3B82F6', icon: 'calendar-week-outline' },
  monthly: { label: 'Monthly', title: 'Monthly ShareQuest', color: '#8B5CF6', icon: 'calendar-month' },
  annual: { label: 'Annual', title: 'Annual ShareQuest', color: '#F59E0B', icon: 'trophy' },
};

export default function LeaderboardsScreen() {
  const router = useRouter();
  const { user } = useAuth();

  // Only show competitions that are active and user is subscribed to
  const [availableTypes, setAvailableTypes] = useState<CompetitionType[]>([]);
  const [activeType, setActiveType] = useState<CompetitionType>('weekly');
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);
  const [competitionInfo, setCompetitionInfo] = useState<CompetitionInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // User portfolio modal
  const [selectedUser, setSelectedUser] = useState<LeaderboardEntry | null>(null);
  const [userPortfolio, setUserPortfolio] = useState<UserPortfolio | null>(null);
  const [showUserModal, setShowUserModal] = useState(false);
  const [userLoading, setUserLoading] = useState(false);

  const fetchLeaderboard = useCallback(async () => {
    try {
      setError(null);
      // Fetch all competitions to determine which are active and user is subscribed to
      const allTypes: CompetitionType[] = ['weekly', 'monthly', 'annual'];
      const available: CompetitionType[] = [];
      let foundActive = false;
      for (const type of allTypes) {
        const response = await apiService.getLeaderboard(type);
        if (response.success && response.data && response.data.competition?.status === 'active' && response.data.leaderboard?.length > 0) {
          available.push(type);
          // Set the first active competition as default if not already set
          if (!foundActive) {
            setActiveType(type);
            foundActive = true;
          }
          // If this is the current activeType, update leaderboard and info
          if (type === activeType) {
            const data = response.data;
            setLeaderboard(data.leaderboard || []);
            setCompetitionInfo(data.competition || {
              total_participants: data.totalParticipants,
              ...data,
            });
          }
        }
      }
      setAvailableTypes(available);
      if (available.length === 0) {
        setLeaderboard([]);
        setCompetitionInfo(null);
      }
    } catch (err) {
      console.error('Error fetching leaderboard:', err);
      setError('Unable to load leaderboard');
    } finally {
      setLoading(false);
    }
  }, [activeType]);

  useEffect(() => {
    setLoading(true);
    fetchLeaderboard();
  }, [fetchLeaderboard]);

  const onRefresh = async () => {
    setRefreshing(true);
    await fetchLeaderboard();
    setRefreshing(false);
  };

  const openUserPortfolio = async (entry: LeaderboardEntry) => {
    setSelectedUser(entry);
    setShowUserModal(true);
    setUserLoading(true);

    try {
      const response = await apiService.getLeaderboardUserPortfolio(activeType, entry.user_id);
      if (response.success && response.data) {
        setUserPortfolio(response.data);
      }
    } catch (err) {
      console.error('Error fetching user portfolio:', err);
    } finally {
      setUserLoading(false);
    }
  };

  const formatCurrency = (pence: number) => {
    const pounds = pence / 100;
    return new Intl.NumberFormat('en-GB', {
      style: 'currency',
      currency: 'GBP',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(pounds);
  };

  const formatPence = (pence: number) => {
    return `${pence.toFixed(2)}p`;
  };

  const formatDate = (dateString?: string) => {
    if (!dateString) return '--';
    try {
      return new Date(dateString).toLocaleDateString('en-GB', {
        day: 'numeric',
        month: 'short',
      });
    } catch {
      return '--';
    }
  };

  const getRankBadge = (rank: number) => {
    if (rank === 1) return { color: '#F59E0B', icon: 'trophy' as const };
    if (rank === 2) return { color: '#9CA3AF', icon: 'medal' as const };
    if (rank === 3) return { color: '#CD7F32', icon: 'medal-outline' as const };
    return null;
  };

  const currentUserEntry = leaderboard.find((e) => e.user_id === user?.id || e.username === user?.username);
  const config = COMPETITION_CONFIG[activeType];

  // Helper for avatar initials
  const getInitials = (name: string) => {
    if (!name) return '';
    const parts = name.split(' ');
    if (parts.length === 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  };

  // Find leader value for progress bars - API returns total_assets
  const getTotal = (e: LeaderboardEntry) => e.total_assets ?? e.total_portfolio_value ?? 0;
  const leaderValue = leaderboard.length > 0 ? getTotal(leaderboard[0]) : 1;

  const renderLeaderboardItem = ({ item, index }: { item: LeaderboardEntry; index: number }) => {
    const isCurrentUser = item.user_id === user?.id || item.username === user?.username;
    const totalVal = getTotal(item);
    const progress = leaderValue > 0 ? totalVal / leaderValue : 0;
    if (item.rank === 1) {
      return (
        <LeaderboardChampionCard
          username={item.username}
          value={totalVal}
          percent={progress * 100}
          gain={item.profit_loss_percent}
          avatar={getInitials(item.username)}
          avatarUrl={item.avatar_url}
        />
      );
    } else if (item.rank === 2 || item.rank === 3) {
      return (
        <LeaderboardContenderCard
          rank={item.rank}
          username={item.username}
          value={totalVal}
          percent={progress * 100}
          gain={item.profit_loss_percent}
          medal={item.rank === 2 ? '🥈' : '🥉'}
          progress={progress}
          avatarUrl={item.avatar_url}
        />
      );
    } else {
      return (
        <LeaderboardOtherCard
          rank={item.rank}
          username={item.username}
          value={totalVal}
          percent={progress * 100}
          gain={item.profit_loss_percent}
          progress={progress}
          avatarUrl={item.avatar_url}
        />
      );
    }
  };

  if (loading) {
    return (
      <View style={styles.container}>
        <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#3B82F6" />
          <Text style={styles.loadingText}>Loading leaderboard...</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />

      <SafeAreaView style={styles.safeArea} edges={['top']}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.headerTitle}>Leaderboard</Text>
        </View>

        {/* Competition Type Tabs */}
        <View style={{paddingHorizontal: 20, marginBottom: 16}}>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{flexGrow: 1, flexDirection: 'row'}}>
            {availableTypes.map((type) => {
              const typeConfig = COMPETITION_CONFIG[type];
              const isActive = type === activeType;
              return (
                <TouchableOpacity
                  key={type}
                  style={[styles.tab, isActive && { borderColor: typeConfig.color }]}
                  onPress={() => setActiveType(type)}
                >
                  <MaterialCommunityIcons
                    name={typeConfig.icon}
                    size={18}
                    color={isActive ? typeConfig.color : '#9CA3AF'}
                  />
                  <Text style={[styles.tabLabel, isActive && { color: typeConfig.color }]} numberOfLines={1} ellipsizeMode="tail">
                    {typeConfig.label}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </ScrollView>
        </View>

        {error ? (
          <View style={styles.errorContainer}>
            <MaterialCommunityIcons name="alert-circle-outline" size={48} color="#EF4444" />
            <Text style={styles.errorText}>{error}</Text>
            <TouchableOpacity style={styles.retryButton} onPress={fetchLeaderboard}>
              <Text style={styles.retryButtonText}>Retry</Text>
            </TouchableOpacity>
          </View>
        ) : (
          <>
            {/* Competition Info Card */}
            <View
              style={[styles.competitionCard, { backgroundColor: '#FF9800', borderColor: '#E68900', paddingVertical: 14, paddingHorizontal: 16, minHeight: 0, marginBottom: 10 }]}
            >
              <View style={[styles.competitionHeader, { marginBottom: 0 }]}>
                <View style={[styles.competitionIcon, { backgroundColor: 'rgba(0,0,0,0.15)' }]}>
                  <MaterialCommunityIcons name={config.icon} size={24} color="#1a1a1a" />
                </View>
                <View style={styles.competitionInfo}>
                  <Text style={[styles.competitionTitle, { color: '#1a1a1a' }]} numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.7}>
                    {config.title}
                  </Text>
                  {competitionInfo?.status && (
                    <View style={[styles.statusBadge, { backgroundColor: 'rgba(0,0,0,0.12)' }]}>
                      <Text style={[styles.statusText, { color: '#1a1a1a' }]}>{competitionInfo.status}</Text>
                    </View>
                  )}
                </View>
                {(competitionInfo?.daysRemaining !== undefined || competitionInfo?.hoursRemaining !== undefined || competitionInfo?.time_remaining !== undefined) && (
                  <View style={[styles.competitionStat, { alignItems: 'flex-end', marginLeft: 8 }]}>
                    <Text style={[styles.competitionStatLabel, { color: '#3d2600' }]}>Time Left</Text>
                    <Text style={[styles.competitionStatValue, { color: '#1a1a1a' }]}>
                      {competitionInfo?.daysRemaining !== undefined && competitionInfo?.hoursRemaining !== undefined
                        ? `${competitionInfo.daysRemaining}d ${competitionInfo.hoursRemaining}h`
                        : competitionInfo?.time_remaining !== undefined
                          ? formatTimeLeft(competitionInfo.time_remaining)
                          : '--'}
                    </Text>
                  </View>
                )}
              </View>
              {competitionInfo?.prize_pool && (
                <View style={[styles.competitionStat, { marginTop: 6, alignItems: 'flex-start' }]}>
                  <Text style={[styles.competitionStatLabel, { color: '#3d2600' }]}>Prize Pool</Text>
                  <Text style={[styles.competitionStatValue, { color: '#1a1a1a' }]}>£{competitionInfo.prize_pool}</Text>
                </View>
              )}
              {(competitionInfo?.start_date || competitionInfo?.end_date) && (
                <Text style={[styles.competitionDates, { color: '#3d2600' }]}>
                  {formatDate(competitionInfo.start_date)} - {formatDate(competitionInfo.end_date)}
                </Text>
              )}
            </View>

            {/* Current User Position */}
            {currentUserEntry && (
              <View style={styles.yourPosition}>
                <Text style={styles.yourPositionLabel}>Your Position</Text>
                <View style={styles.yourPositionContent}>
                  <Text style={styles.yourPositionRank}>#{isNaN(currentUserEntry.rank) ? '--' : currentUserEntry.rank}</Text>
                  <View style={styles.yourPositionStats}>
                    <Text style={styles.yourPositionValue}>
                      {formatCurrency(getTotal(currentUserEntry))}
                    </Text>
                    <Text style={[
                      styles.yourPositionPL,
                      { color: currentUserEntry.profit_loss >= 0 ? '#10B981' : '#EF4444' }
                    ]}>
                      {currentUserEntry.profit_loss >= 0 ? '+' : ''}
                      {isNaN(currentUserEntry.profit_loss_percent) ? '--' : currentUserEntry.profit_loss_percent.toFixed(2)}%
                    </Text>
                  </View>
                </View>
              </View>
            )}

            {/* Leaderboard List */}
            {/* Subscription filter placeholder: filter leaderboard if needed */}
            <FlatList
              data={leaderboard /* TODO: filter for subscribed competitions if required */}
              renderItem={renderLeaderboardItem}
              keyExtractor={(item) => item.user_id}
              contentContainerStyle={styles.listContent}
              refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#3B82F6" />}
              ListEmptyComponent={
                <View style={styles.emptyContainer}>
                  <MaterialCommunityIcons name="trophy-outline" size={64} color="#4B5563" />
                  <Text style={styles.emptyTitle}>No participants yet</Text>
                  <Text style={styles.emptySubtext}>Be the first to join this competition!</Text>
                </View>
              }
            />
          </>
        )}
      </SafeAreaView>

      {/* User Portfolio Modal */}
      <Modal visible={showUserModal} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <LinearGradient colors={['#1e293b', '#0f172a']} style={StyleSheet.absoluteFillObject} />

            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={() => setShowUserModal(false)}>
                <MaterialCommunityIcons name="close" size={28} color="#FFFFFF" />
              </TouchableOpacity>
              <Text style={styles.modalTitle}>{selectedUser?.username}'s Portfolio</Text>
              <View style={{ width: 28 }} />
            </View>

            {userLoading ? (
              <View style={styles.loadingContainer}>
                <ActivityIndicator size="large" color="#3B82F6" />
              </View>
            ) : (
              <ScrollView style={styles.modalScroll} showsVerticalScrollIndicator={false}>
                {/* User Stats */}
                <View style={styles.userStats}>
                  <View style={styles.userStat}>
                    <Text style={styles.userStatLabel}>Rank</Text>
                    <Text style={styles.userStatValue}>#{selectedUser?.rank || userPortfolio?.rank || '--'}</Text>
                  </View>
                  <View style={styles.userStat}>
                    <Text style={styles.userStatLabel}>Total Value</Text>
                    <Text style={styles.userStatValue}>
                      {selectedUser ? formatCurrency(getTotal(selectedUser)) : '--'}
                    </Text>
                  </View>
                  <View style={styles.userStat}>
                    <Text style={styles.userStatLabel}>Cash</Text>
                    <Text style={styles.userStatValue}>
                      {formatCurrency(userPortfolio?.cash_balance || 0)}
                    </Text>
                  </View>
                </View>

                {/* Holdings */}
                <Text style={styles.sectionTitle}>Holdings</Text>

                {!userPortfolio?.holdings || userPortfolio.holdings.length === 0 ? (
                  <View style={styles.noHoldings}>
                    <Text style={styles.noHoldingsText}>No holdings in this portfolio</Text>
                  </View>
                ) : (
                  userPortfolio.holdings.map((holding) => {
                    const value = holding.quantity * holding.current_price;
                    const cost = holding.quantity * holding.average_price;
                    const pl = value - cost;
                    const plPercent = cost > 0 ? (pl / cost) * 100 : 0;
                    const isPositive = pl >= 0;

                    return (
                      <View key={holding.symbol} style={styles.holdingRow}>
                        <View style={styles.holdingInfo}>
                          <Text style={styles.holdingSymbol}>{holding.symbol}</Text>
                          <Text style={styles.holdingQuantity}>
                            {holding.quantity} @ {formatPence(holding.average_price)}
                          </Text>
                        </View>
                        <View style={styles.holdingValues}>
                          <Text style={styles.holdingValue}>{formatCurrency(value)}</Text>
                          <Text style={[styles.holdingPL, { color: isPositive ? '#10B981' : '#EF4444' }]}>
                            {isPositive ? '+' : ''}{plPercent.toFixed(1)}%
                          </Text>
                        </View>
                      </View>
                    );
                  })
                )}

                <View style={{ height: 40 }} />
              </ScrollView>
            )}
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  loadingContainer: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  loadingText: { color: '#9CA3AF', fontSize: 16, marginTop: 12 },
  safeArea: { flex: 1 },
  header: { paddingHorizontal: 20, paddingVertical: 16 },
  headerTitle: { color: '#FFFFFF', fontSize: 28, fontWeight: 'bold' },
  tabsContainer: { marginBottom: 16, marginHorizontal: -20, paddingHorizontal: 20 },
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
  errorContainer: { flex: 1, justifyContent: 'center', alignItems: 'center', paddingHorizontal: 20 },
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
  competitionCard: {
    marginHorizontal: 20,
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    marginBottom: 16,
  },
  competitionHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: 16 },
  competitionIcon: {
    width: 44,
    height: 44,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  competitionInfo: { flex: 1 },
  competitionTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: '600' },
  statusBadge: {
    alignSelf: 'flex-start',
    marginTop: 4,
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 8,
    backgroundColor: 'rgba(107, 114, 128, 0.2)',
  },
  statusActive: { backgroundColor: 'rgba(16, 185, 129, 0.2)' },
  statusText: { color: '#10B981', fontSize: 11, fontWeight: '600', textTransform: 'capitalize' },
  competitionStats: { flexDirection: 'row', justifyContent: 'space-around' },
  competitionStat: { alignItems: 'center' },
  competitionStatLabel: { color: '#9CA3AF', fontSize: 12 },
  competitionStatValue: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold', marginTop: 4 },
  competitionDates: { color: '#6B7280', fontSize: 12, textAlign: 'center', marginTop: 12 },
  yourPosition: {
    marginHorizontal: 20,
    backgroundColor: 'rgba(59, 130, 246, 0.1)',
    borderRadius: 12,
    padding: 12,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: 'rgba(59, 130, 246, 0.3)',
  },
  yourPositionLabel: { color: '#3B82F6', fontSize: 12, fontWeight: '600' },
  yourPositionContent: { flexDirection: 'row', alignItems: 'center', marginTop: 8 },
  yourPositionRank: { color: '#FFFFFF', fontSize: 24, fontWeight: 'bold', marginRight: 16 },
  yourPositionStats: { flex: 1 },
  yourPositionValue: { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
  yourPositionPL: { fontSize: 14, marginTop: 2 },
  listContent: { paddingHorizontal: 20, paddingBottom: 100 },
  leaderboardRow: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 12,
    padding: 14,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 6,
    elevation: 4,
  },
  goldRow: {
    backgroundColor: 'linear-gradient(90deg, #FFD700 60%, #FFFACD 100%)',
    borderColor: '#FFD700',
  },
  silverRow: {
    backgroundColor: 'linear-gradient(90deg, #C0C0C0 60%, #F0F0F0 100%)',
    borderColor: '#C0C0C0',
  },
  bronzeRow: {
    backgroundColor: 'linear-gradient(90deg, #CD7F32 60%, #FFDAB9 100%)',
    borderColor: '#CD7F32',
  },
  currentUserRow: {
    backgroundColor: 'rgba(59, 130, 246, 0.15)',
    borderColor: '#3B82F6',
    shadowColor: '#3B82F6',
    shadowOpacity: 0.25,
    shadowRadius: 8,
    elevation: 6,
  },
  rankContainer: { width: 40, alignItems: 'center' },
  rankBadge: {
    width: 32,
    height: 32,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
  },
  rankNumber: { color: '#9CA3AF', fontSize: 16, fontWeight: '600' },
  userInfo: { flex: 1, marginLeft: 12 },
  username: { color: '#FFFFFF', fontSize: 15, fontWeight: '600' },
  currentUserText: { color: '#3B82F6' },
  portfolioValue: { color: '#9CA3AF', fontSize: 13, marginTop: 2 },
  profitContainer: { alignItems: 'flex-end' },
  profitRow: { flexDirection: 'row', alignItems: 'center' },
  profitPercent: { fontSize: 15, fontWeight: '600', marginLeft: 2 },
  profitValue: { fontSize: 12, marginTop: 2 },
  emptyContainer: { alignItems: 'center', paddingVertical: 60 },
  emptyTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold', marginTop: 16 },
  emptySubtext: { color: '#9CA3AF', fontSize: 14, marginTop: 8 },
  // Modal styles
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.7)', justifyContent: 'flex-end' },
  modalContent: { height: '75%', borderTopLeftRadius: 24, borderTopRightRadius: 24, overflow: 'hidden' },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
  },
  modalTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold' },
  modalScroll: { flex: 1, padding: 20 },
  userStats: { flexDirection: 'row', marginBottom: 24 },
  userStat: {
    flex: 1,
    alignItems: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 12,
    marginRight: 8,
  },
  userStatLabel: { color: '#9CA3AF', fontSize: 12 },
  userStatValue: { color: '#FFFFFF', fontSize: 16, fontWeight: 'bold', marginTop: 4 },
  sectionTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold', marginBottom: 12 },
  noHoldings: { alignItems: 'center', paddingVertical: 20 },
  noHoldingsText: { color: '#9CA3AF', fontSize: 14 },
  holdingRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 10,
    padding: 12,
    marginBottom: 8,
  },
  holdingInfo: { flex: 1 },
  holdingSymbol: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
  holdingQuantity: { color: '#9CA3AF', fontSize: 12, marginTop: 2 },
  holdingValues: { alignItems: 'flex-end' },
  holdingValue: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
  holdingPL: { fontSize: 12, marginTop: 2 },
});
