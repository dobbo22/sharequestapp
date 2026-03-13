import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  RefreshControl,
  TextInput,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import Animated, {
  FadeInDown,
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSpring,
  withRepeat,
  withSequence,
  Easing,
} from 'react-native-reanimated';
import { apiService } from '../src/services/api';
import XPGainToast from '../src/components/gamification/XPGainToast';

const CHALLENGE_ACTIONS: Record<string, { route: string; label: string; icon: string }> = {
  portfolio_check: { route: '/(tabs)/portfolio', label: 'Check Portfolios', icon: 'briefcase-outline' },
  leaderboard: { route: '/(tabs)/leaderboards', label: 'View Leaderboards', icon: 'trophy-outline' },
  watchlist: { route: '/(tabs)/stocks', label: 'Browse Stocks', icon: 'chart-line-variant' },
  pnl_check: { route: '/(tabs)/portfolio', label: 'Review P&L', icon: 'chart-box-outline' },
  sector: { route: '/(tabs)/stocks', label: 'Explore Sectors', icon: 'view-grid-outline' },
  stock_view: { route: '/(tabs)/stocks', label: 'Explore Stocks', icon: 'chart-line-variant' },
};

interface Challenge {
  id: number;
  code: string;
  name: string;
  description: string;
  criteria_type: string;
  criteria_value: number;
  xp_reward: number;
  day_of_week: number;
  date: string;
  progress: number;
  completed: boolean;
  isToday: boolean;
  isPast: boolean;
  isFuture: boolean;
}

interface StreakAchievement {
  code: string;
  name: string;
  description: string;
  xpReward: number;
  tier: string;
  icon: string;
  progress: number;
  target: number;
  unlocked: boolean;
}

interface StockHuntData {
  template: {
    name: string;
    description: string;
    hint: string | null;
    xp_reward: number;
    difficulty: string;
  } | null;
  completed: boolean;
  matchingStockCount: number;
}

interface WeeklyData {
  challenges: Challenge[];
  weeklyStats: { completed: number; total: number; totalXP: number };
  streak: { current: number; longest: number };
  streakAchievements: StreakAchievement[];
}

const TIER_COLORS: Record<string, { bg: string; text: string; border: string }> = {
  bronze: { bg: 'rgba(205, 127, 50, 0.15)', text: '#CD7F32', border: 'rgba(205, 127, 50, 0.3)' },
  silver: { bg: 'rgba(192, 192, 192, 0.15)', text: '#C0C0C0', border: 'rgba(192, 192, 192, 0.3)' },
  gold: { bg: 'rgba(255, 215, 0, 0.15)', text: '#FFD700', border: 'rgba(255, 215, 0, 0.3)' },
  platinum: { bg: 'rgba(229, 228, 226, 0.15)', text: '#E5E4E2', border: 'rgba(229, 228, 226, 0.3)' },
};

export default function ChallengesScreen() {
  const router = useRouter();
  const [data, setData] = useState<WeeklyData | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [xpToastAmount, setXpToastAmount] = useState(0);
  const [xpToastVisible, setXpToastVisible] = useState(false);
  const [stockHunt, setStockHunt] = useState<StockHuntData | null>(null);
  const [hideDailyChallenge, setHideDailyChallenge] = useState(false);
  const [hideStockHunt, setHideStockHunt] = useState(false);

  // Stock hunt search & claim state
  const [huntSearch, setHuntSearch] = useState('');
  const [huntResults, setHuntResults] = useState<{ symbol: string; companyname: string; matches: boolean }[]>([]);
  const [huntSearching, setHuntSearching] = useState(false);
  const [huntClaiming, setHuntClaiming] = useState(false);
  const searchTimeoutRef = React.useRef<ReturnType<typeof setTimeout> | null>(null);

  const fetchData = useCallback(async () => {
    try {
      const [weeklyRes, huntRes] = await Promise.all([
        apiService.getWeeklyChallenges(),
        apiService.getStockHunt(),
      ]);
      if (weeklyRes.success && weeklyRes.data) {
        setData(weeklyRes.data as WeeklyData);
      }
      if (huntRes.success && huntRes.data) {
        setStockHunt(huntRes.data as StockHuntData);
      }
    } catch (err) {
      console.error('Failed to fetch challenges:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const onRefresh = async () => {
    setRefreshing(true);
    await fetchData();
    setRefreshing(false);
  };

  const todayChallenge = data?.challenges?.find(c => c.isToday) ?? null;

  // Auto-hide completed challenge cards after 10 seconds
  useEffect(() => {
    if (todayChallenge?.completed && !hideDailyChallenge) {
      const timer = setTimeout(() => setHideDailyChallenge(true), 10000);
      return () => clearTimeout(timer);
    }
  }, [todayChallenge?.completed, hideDailyChallenge]);

  useEffect(() => {
    if (stockHunt?.completed && !hideStockHunt) {
      const timer = setTimeout(() => setHideStockHunt(true), 10000);
      return () => clearTimeout(timer);
    }
  }, [stockHunt?.completed, hideStockHunt]);

  const handleChallengeAction = (challenge: Challenge) => {
    const action = CHALLENGE_ACTIONS[challenge.criteria_type];
    if (action) {
      router.push(action.route as any);
    }
  };

  // Stock hunt search with debounce
  const handleHuntSearch = (text: string) => {
    setHuntSearch(text);
    if (searchTimeoutRef.current) clearTimeout(searchTimeoutRef.current);
    if (text.length < 2) {
      setHuntResults([]);
      return;
    }
    setHuntSearching(true);
    searchTimeoutRef.current = setTimeout(async () => {
      try {
        const res = await apiService.searchStockHunt(text);
        if (res.success && res.data) {
          setHuntResults((res.data as any[]).slice(0, 8));
        }
      } catch {
        setHuntResults([]);
      } finally {
        setHuntSearching(false);
      }
    }, 400);
  };

  // Claim a stock for the hunt
  const handleClaimStock = async (symbol: string) => {
    setHuntClaiming(true);
    try {
      const res = await apiService.claimStockHunt(symbol) as any;
      if (res.success && res.data?.matched) {
        setXpToastAmount(res.data.xpReward || 35);
        setXpToastVisible(true);
        setStockHunt(prev => prev ? { ...prev, completed: true } : prev);
        setHuntSearch('');
        setHuntResults([]);
      }
    } catch {
      // Claim failed silently
    } finally {
      setHuntClaiming(false);
    }
  };

  if (loading) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#FBBF24" />
        </View>
      </SafeAreaView>
    );
  }

  if (!data) {
    return (
      <SafeAreaView style={styles.container}>
        <View style={styles.loadingContainer}>
          <Text style={{ color: '#9CA3AF', fontSize: 16 }}>Failed to load challenges</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
          <MaterialCommunityIcons name="chevron-left" size={28} color="#FFFFFF" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Daily Challenges</Text>
        <View style={{ width: 28 }} />
      </View>

      {/* Main ScrollView content */}
      <ScrollView
        style={styles.content}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#FBBF24" />
        }
      >
        {/* Stats Row */}
        <Animated.View entering={FadeInDown.duration(400)} style={styles.statsRow}>
          <View style={styles.statBox}>
            <MaterialCommunityIcons name="fire" size={20} color="#EF4444" />
            <Text style={styles.statValue}>{data.streak.current}</Text>
            <Text style={styles.statLabel}>Streak</Text>
          </View>
          <View style={styles.statBox}>
            <Ionicons name="checkmark-done" size={20} color="#10B981" />
            <Text style={styles.statValue}>{data.weeklyStats.completed}/{data.weeklyStats.total}</Text>
            <Text style={styles.statLabel}>Today</Text>
          </View>
          <View style={styles.statBox}>
            <MaterialCommunityIcons name="star-four-points" size={20} color="#FBBF24" />
            <Text style={styles.statValue}>{data.weeklyStats.totalXP}</Text>
            <Text style={styles.statLabel}>XP Earned</Text>
          </View>
          <View style={styles.statBox}>
            <MaterialCommunityIcons name="trophy" size={20} color="#8B5CF6" />
            <Text style={styles.statValue}>{data.streak.longest}</Text>
            <Text style={styles.statLabel}>Best Streak</Text>
          </View>
        </Animated.View>

        {/* Today Section */}
        <Text style={styles.sectionTitle}>Today</Text>

        {/* Daily Challenge Card */}
        {todayChallenge && !hideDailyChallenge && (
          <Animated.View entering={FadeInDown.delay(100).duration(400)}>
            <LinearGradient
              colors={todayChallenge.completed
                ? ['rgba(16, 185, 129, 0.15)', 'rgba(16, 185, 129, 0.05)']
                : ['rgba(251, 191, 36, 0.15)', 'rgba(251, 191, 36, 0.05)']}
              style={styles.heroCard}
            >
              <View style={styles.heroHeader}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.heroLabel}>Daily Challenge</Text>
                  <Text style={styles.heroName}>{todayChallenge.name}</Text>
                </View>
                {todayChallenge.completed ? (
                  <View style={styles.completedBadge}>
                    <Ionicons name="checkmark-circle" size={20} color="#10B981" />
                    <Text style={styles.completedText}>Done!</Text>
                  </View>
                ) : (
                  <View style={styles.xpBadge}>
                    <Text style={styles.xpBadgeText}>+{todayChallenge.xp_reward} XP</Text>
                  </View>
                )}
              </View>
              <Text style={styles.heroDescription}>{todayChallenge.description}</Text>
              {!todayChallenge.completed && (
                <>
                  <View style={styles.heroProgressBar}>
                    <LinearGradient
                      colors={['#FBBF24', '#F59E0B']}
                      start={{ x: 0, y: 0 }}
                      end={{ x: 1, y: 0 }}
                      style={[
                        styles.heroProgressFill,
                        { width: `${Math.min((todayChallenge.progress / todayChallenge.criteria_value) * 100, 100)}%` },
                      ]}
                    />
                  </View>
                  <Text style={styles.heroProgressText}>
                    {todayChallenge.progress}/{todayChallenge.criteria_value}
                  </Text>
                  {CHALLENGE_ACTIONS[todayChallenge.criteria_type] && (
                    <TouchableOpacity
                      style={styles.actionButton}
                      onPress={() => handleChallengeAction(todayChallenge)}
                    >
                      <MaterialCommunityIcons
                        name={CHALLENGE_ACTIONS[todayChallenge.criteria_type].icon as any}
                        size={18}
                        color="#FFFFFF"
                      />
                      <Text style={styles.actionButtonText}>
                        {CHALLENGE_ACTIONS[todayChallenge.criteria_type].label}
                      </Text>
                      <MaterialCommunityIcons name="chevron-right" size={18} color="#FFFFFF" />
                    </TouchableOpacity>
                  )}
                </>
              )}
            </LinearGradient>
          </Animated.View>
        )}

        {/* Stock Hunt Card */}
        {stockHunt?.template && !hideStockHunt && (
          <Animated.View entering={FadeInDown.delay(200).duration(400)}>
            <LinearGradient
              colors={stockHunt.completed
                ? ['rgba(16, 185, 129, 0.15)', 'rgba(16, 185, 129, 0.05)']
                : ['rgba(139, 92, 246, 0.15)', 'rgba(139, 92, 246, 0.05)']}
              style={[styles.heroCard, { borderColor: stockHunt.completed ? 'rgba(16, 185, 129, 0.3)' : 'rgba(139, 92, 246, 0.3)' }]}
            >
              <View style={styles.heroHeader}>
                <View style={{ flex: 1 }}>
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                    <Text style={[styles.heroLabel, { color: '#8B5CF6' }]}>Stock Hunt</Text>
                    <View style={[
                      styles.difficultyBadge,
                      { backgroundColor: stockHunt.template.difficulty === 'hard'
                          ? 'rgba(239, 68, 68, 0.2)'
                          : stockHunt.template.difficulty === 'medium'
                            ? 'rgba(251, 191, 36, 0.2)'
                            : 'rgba(16, 185, 129, 0.2)' },
                    ]}>
                      <Text style={[
                        styles.difficultyText,
                        { color: stockHunt.template.difficulty === 'hard'
                            ? '#EF4444'
                            : stockHunt.template.difficulty === 'medium'
                              ? '#FBBF24'
                              : '#10B981' },
                      ]}>
                        {stockHunt.template.difficulty?.toUpperCase()}
                      </Text>
                    </View>
                  </View>
                  <Text style={styles.heroName}>{stockHunt.template.name}</Text>
                </View>
                {stockHunt.completed ? (
                  <View style={styles.completedBadge}>
                    <Ionicons name="checkmark-circle" size={20} color="#10B981" />
                    <Text style={styles.completedText}>Done!</Text>
                  </View>
                ) : (
                  <View style={styles.xpBadge}>
                    <Text style={styles.xpBadgeText}>+{stockHunt.template.xp_reward} XP</Text>
                  </View>
                )}
              </View>
              <Text style={styles.heroDescription}>{stockHunt.template.description}</Text>
              {stockHunt.template.hint && (
                <Text style={styles.huntHint}>{stockHunt.template.hint}</Text>
              )}
              {!stockHunt.completed && stockHunt.matchingStockCount > 0 && (
                <Text style={styles.huntMatchCount}>
                  {stockHunt.matchingStockCount} stock{stockHunt.matchingStockCount !== 1 ? 's' : ''} match this criteria
                </Text>
              )}
              {!stockHunt.completed && (
                <>
                  <View style={styles.huntSearchContainer}>
                    <MaterialCommunityIcons name="magnify" size={20} color="#8B5CF6" />
                    <TextInput
                      style={styles.huntSearchInput}
                      placeholder="Search for a matching stock..."
                      placeholderTextColor="#6B7280"
                      value={huntSearch}
                      onChangeText={handleHuntSearch}
                      autoCapitalize="characters"
                    />
                    {huntSearching && <ActivityIndicator size="small" color="#8B5CF6" />}
                  </View>
                  {huntResults.length > 0 && (
                    <View style={styles.huntResultsList}>
                      {huntResults.map(stock => (
                        <View key={stock.symbol} style={[styles.huntResultItem, !stock.matches && styles.huntResultMiss]}>
                          <View style={{ flex: 1 }}>
                            <Text style={[styles.huntResultName, !stock.matches && { color: '#6B7280' }]} numberOfLines={1}>{stock.companyname}</Text>
                            <Text style={styles.huntResultSymbol}>{stock.symbol}</Text>
                          </View>
                          {stock.matches ? (
                            <TouchableOpacity
                              style={styles.huntClaimButton}
                              onPress={() => handleClaimStock(stock.symbol)}
                              disabled={huntClaiming}
                            >
                              {huntClaiming ? (
                                <ActivityIndicator size="small" color="#FFFFFF" />
                              ) : (
                                <Text style={styles.huntClaimText}>Claim</Text>
                              )}
                            </TouchableOpacity>
                          ) : (
                            <Ionicons name="close-circle-outline" size={20} color="#4B5563" />
                          )}
                        </View>
                      ))}
                    </View>
                  )}
                </>
              )}
            </LinearGradient>
          </Animated.View>
        )}

        {/* Streak Achievements */}
        {data.streakAchievements.length > 0 && (
          <Animated.View entering={FadeInDown.delay(300).duration(400)}>
            <Text style={[styles.sectionTitle, { marginTop: 8 }]}>Streak Achievements</Text>
            {data.streakAchievements.map(achievement => {
              const tier = TIER_COLORS[achievement.tier] || TIER_COLORS.bronze;
              const pct = achievement.target > 0
                ? Math.min((achievement.progress / achievement.target) * 100, 100)
                : 0;

              return (
                <View
                  key={achievement.code}
                  style={[styles.achievementCard, { borderColor: tier.border }]}
                >
                  <View style={styles.achievementHeader}>
                    <View style={[styles.achievementIcon, { backgroundColor: tier.bg }]}>
                      <Ionicons
                        name={achievement.unlocked ? 'flame' : 'flame-outline'}
                        size={22}
                        color={tier.text}
                      />
                    </View>
                    <View style={styles.achievementInfo}>
                      <Text style={styles.achievementName}>{achievement.name}</Text>
                      <Text style={styles.achievementDesc}>{achievement.description}</Text>
                    </View>
                    <View>
                      {achievement.unlocked ? (
                        <Ionicons name="checkmark-circle" size={22} color="#10B981" />
                      ) : (
                        <Text style={[styles.achievementXP, { color: tier.text }]}>
                          +{achievement.xpReward} XP
                        </Text>
                      )}
                    </View>
                  </View>
                  <View style={styles.achievementProgressBar}>
                    <View
                      style={[
                        styles.achievementProgressFill,
                        { width: `${pct}%`, backgroundColor: achievement.unlocked ? '#10B981' : tier.text },
                      ]}
                    />
                  </View>
                  <Text style={styles.achievementProgressText}>
                    {achievement.progress}/{achievement.target} days
                    {achievement.unlocked && ' - Unlocked!'}
                  </Text>
                </View>
              );
            })}
          </Animated.View>
        )}
      </ScrollView>

      <XPGainToast
        amount={xpToastAmount}
        visible={xpToastVisible}
        onFinish={() => setXpToastVisible(false)}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0f172a' },
  loadingContainer: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
  },
  backButton: { padding: 4 },
  headerTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: '700' },
  content: { padding: 16, paddingBottom: 40 },

  // Hero
  heroCard: {
    borderRadius: 16,
    padding: 20,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: 'rgba(251, 191, 36, 0.3)',
  },
  heroHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start' },
  heroLabel: { color: '#FBBF24', fontSize: 12, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 0.5 },
  heroName: { color: '#FFFFFF', fontSize: 20, fontWeight: 'bold', marginTop: 4 },
  heroDescription: { color: '#D1D5DB', fontSize: 14, marginTop: 12 },
  completedBadge: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  completedText: { color: '#10B981', fontWeight: '700', fontSize: 14 },
  xpBadge: {
    backgroundColor: 'rgba(251, 191, 36, 0.2)',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
  },
  xpBadgeText: { color: '#FBBF24', fontWeight: 'bold', fontSize: 14 },
  heroProgressBar: {
    height: 8,
    backgroundColor: 'rgba(55, 65, 81, 0.6)',
    borderRadius: 4,
    marginTop: 16,
    overflow: 'hidden',
  },
  heroProgressFill: { height: '100%', borderRadius: 4 },
  heroProgressText: { color: '#9CA3AF', fontSize: 12, marginTop: 4, textAlign: 'right' },

  // Stats
  statsRow: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 24,
  },
  statBox: {
    flex: 1,
    backgroundColor: 'rgba(31, 41, 55, 0.6)',
    borderRadius: 12,
    padding: 12,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  statValue: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold', marginTop: 4 },
  statLabel: { color: '#9CA3AF', fontSize: 10, marginTop: 2, textAlign: 'center' },

  // Section
  sectionTitle: { color: '#FFFFFF', fontSize: 16, fontWeight: '700', marginBottom: 12 },

  // Achievements
  achievementCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.6)',
    borderRadius: 12,
    padding: 16,
    marginBottom: 10,
    borderWidth: 1,
  },
  achievementHeader: { flexDirection: 'row', alignItems: 'center' },
  achievementIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  achievementInfo: { flex: 1, marginLeft: 12, marginRight: 8 },
  achievementName: { color: '#FFFFFF', fontSize: 14, fontWeight: '700' },
  achievementDesc: { color: '#9CA3AF', fontSize: 12, marginTop: 2 },
  achievementXP: { fontWeight: 'bold', fontSize: 12 },
  achievementProgressBar: {
    height: 4,
    backgroundColor: '#374151',
    borderRadius: 2,
    marginTop: 12,
    overflow: 'hidden',
  },
  achievementProgressFill: { height: '100%', borderRadius: 2 },
  achievementProgressText: { color: '#6B7280', fontSize: 10, marginTop: 4 },

  // Stock Hunt
  difficultyBadge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 8,
  },
  difficultyText: {
    fontSize: 9,
    fontWeight: '800',
    letterSpacing: 0.5,
  },
  huntHint: {
    color: '#9CA3AF',
    fontSize: 12,
    marginTop: 8,
    fontStyle: 'italic',
  },
  huntMatchCount: {
    color: '#8B5CF6',
    fontSize: 12,
    fontWeight: '600',
    marginTop: 8,
  },
  huntSearchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.8)',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginTop: 12,
    borderWidth: 1,
    borderColor: 'rgba(139, 92, 246, 0.3)',
    gap: 8,
  },
  huntSearchInput: {
    flex: 1,
    color: '#FFFFFF',
    fontSize: 14,
    padding: 0,
  },
  huntResultsList: {
    marginTop: 8,
    borderRadius: 10,
    overflow: 'hidden',
  },
  huntResultItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.6)',
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
  },
  huntResultMiss: {
    opacity: 0.5,
  },
  huntResultName: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '700',
  },
  huntResultSymbol: {
    color: '#9CA3AF',
    fontSize: 11,
    marginTop: 1,
  },
  huntClaimButton: {
    backgroundColor: '#8B5CF6',
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 8,
  },
  huntClaimText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: '700',
  },
  huntMismatch: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: 10,
    backgroundColor: 'rgba(239, 68, 68, 0.1)',
    padding: 10,
    borderRadius: 8,
  },
  huntMismatchText: {
    color: '#EF4444',
    fontSize: 12,
    flex: 1,
  },

  // Action button
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#3B82F6',
    borderRadius: 12,
    paddingVertical: 12,
    paddingHorizontal: 16,
    marginTop: 16,
    gap: 8,
  },
  actionButtonText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '700',
    flex: 1,
  },
});