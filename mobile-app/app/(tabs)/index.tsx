import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  RefreshControl,
  Dimensions,
  TouchableOpacity,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialCommunityIcons, Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import Animated, { FadeInDown } from 'react-native-reanimated';

import { useAuth } from '../../src/hooks/useAuth';
import { apiService } from '../../src/services/api';
import { colors, spacing, radii, typography, glassStyle } from '../../src/lib/theme';
import LoadingSpinner from '../../src/components/ui/LoadingSpinner';
import StockTicker from '../../src/components/ui/StockTicker';
import SwipeablePortfolioCards from '../../src/components/ui/SwipeablePortfolioCards';
import type { PortfolioCardData } from '../../src/components/ui/SwipeablePortfolioCards';
import {
  StreakCounter,
  DailyChallengeCard,
  AchievementUnlockedModal,
  PlayerLevelBadge,
  XPGainToast,
  XPActivityFeed,
} from '../../src/components/gamification';

const { width } = Dimensions.get('window');

interface UserSubscriptions {
  weekly: boolean;
  monthly: boolean;
  annual: boolean;
  default: boolean;
}

interface MarketSentimentData {
  overall: {
    score: number;
    sentiment: 'bullish' | 'neutral' | 'bearish';
    direction: 'up' | 'down' | 'sideways';
  };
  metrics: {
    gainerCount: number;
    loserCount: number;
  };
  topGainers: Array<{
    symbol: string;
    name: string;
    price: number;
    changePercent: number;
  }>;
  topLosers: Array<{
    symbol: string;
    name: string;
    price: number;
    changePercent: number;
  }>;
}

// Quick action button component
function QuickActionButton({ icon, label, color, onPress }: {
  icon: keyof typeof Ionicons.glyphMap;
  label: string;
  color: string;
  onPress: () => void;
}) {
  return (
    <TouchableOpacity style={styles.quickAction} onPress={onPress} activeOpacity={0.7}>
      <View style={[styles.quickActionIcon, { backgroundColor: `${color}20` }]}>
        <Ionicons name={icon} size={22} color={color} />
      </View>
      <Text style={styles.quickActionLabel}>{label}</Text>
    </TouchableOpacity>
  );
}

export default function DashboardScreen() {
  const { user } = useAuth();
  const router = useRouter();
  const hasLoadedOnce = useRef(false);

  const [userSubscriptions, setUserSubscriptions] = useState<UserSubscriptions>({
    weekly: false,
    monthly: false,
    annual: false,
    default: true,
  });
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [marketOpen, setMarketOpen] = useState<boolean>(false);
  const [ukTime, setUkTime] = useState<string>('');
  const [sentiment, setSentiment] = useState<MarketSentimentData | null>(null);

  const [streak, setStreak] = useState(0);
  const [dailyChallenges, setDailyChallenges] = useState<any[]>([]);
  const [unlockedAchievement, setUnlockedAchievement] = useState<any>(null);
  const [gamProfile, setGamProfile] = useState<{
    totalXP: number;
    level: number;
    levelName: string;
    nextLevelXP: number;
    xpToNextLevel: number;
  } | null>(null);
  const [portfolioCards, setPortfolioCards] = useState<PortfolioCardData[]>([]);
  const [recentXP, setRecentXP] = useState<Array<{ source: string; amount: number; description: string; created_at: string }>>([]);

  // XP change detection
  const prevXP = useRef<number | null>(null);
  const [xpDelta, setXpDelta] = useState(0);
  const [showXpToast, setShowXpToast] = useState(false);

  // UK Market status
  useEffect(() => {
    const computeStatus = () => {
      try {
        const now = new Date();
        const parts = new Intl.DateTimeFormat('en-GB', {
          timeZone: 'Europe/London',
          hour12: false,
          weekday: 'short',
          hour: '2-digit',
          minute: '2-digit',
        }).formatToParts(now);

        const weekday = parts.find((p) => p.type === 'weekday')?.value || '';
        const hour = parseInt(parts.find((p) => p.type === 'hour')?.value || '0', 10);
        const minute = parseInt(parts.find((p) => p.type === 'minute')?.value || '0', 10);
        const isWeekend = weekday.startsWith('Sat') || weekday.startsWith('Sun');
        const afterOpen = hour > 8 || (hour === 8 && minute >= 0);
        const beforeClose = hour < 16 || (hour === 16 && minute <= 30);
        const openNow = !isWeekend && afterOpen && beforeClose;
        setMarketOpen(openNow);

        const timeStr = new Intl.DateTimeFormat('en-GB', {
          timeZone: 'Europe/London',
          hour: '2-digit',
          minute: '2-digit',
        }).format(now);
        setUkTime(`${timeStr} UK`);
      } catch {
        setMarketOpen(false);
        const local = new Date();
        setUkTime(`${String(local.getHours()).padStart(2, '0')}:${String(local.getMinutes()).padStart(2, '0')}`);
      }
    };

    computeStatus();
    const id = setInterval(computeStatus, 60 * 1000);
    return () => clearInterval(id);
  }, []);

  // Fetch unified dashboard data - returns subscriptions for downstream use
  const fetchDashboardData = useCallback(async (bypassCache = false): Promise<UserSubscriptions | null> => {
    try {
      const url = `/mobile/dashboard/unified${bypassCache ? '?bypassCache=1' : ''}`;
      const res = await apiService.request(url, { method: 'GET' });
      if (res.success && res.data) {
        const sentimentData = res.data.marketSentiment || res.data.market_sentiment;
        if (sentimentData) setSentiment(sentimentData);
        const rd = res.data as Record<string, unknown>;
        const subsData = rd.userSubscriptions || rd.user_subscriptions || rd.subscriptions;
        if (subsData) {
          const subs = { ...(subsData as UserSubscriptions), default: true };
          setUserSubscriptions(subs);
          return subs;
        }
      }
    } catch (err) {
      console.error('Error fetching dashboard data:', err);
    }
    return null;
  }, []);

  // Fetch portfolio data for swipeable cards
  const fetchPortfolioCards = useCallback(async (subs?: UserSubscriptions) => {
    const activeSubs = subs || userSubscriptions;
    const PORTFOLIO_CONFIGS: { type: 'default' | 'weekly' | 'monthly' | 'annual'; label: string; emoji: string; gradientColors: [string, string]; icon: keyof typeof MaterialCommunityIcons.glyphMap; subKey: keyof UserSubscriptions; darkText?: boolean }[] = [
      { type: 'default', label: 'Practice', emoji: '🎯', gradientColors: ['#3B82F6', '#2563EB'], icon: 'target', subKey: 'default' },
      { type: 'weekly', label: 'Weekly', emoji: '⚡', gradientColors: ['#6366F1', '#4338CA'], icon: 'calendar-week', subKey: 'weekly' },
      { type: 'monthly', label: 'Monthly', emoji: '📅', gradientColors: ['#8B5CF6', '#7C3AED'], icon: 'calendar-month', subKey: 'monthly' },
      { type: 'annual', label: 'Annual', emoji: '🏆', gradientColors: ['#F59E0B', '#D97706'], icon: 'trophy-variant', subKey: 'annual', darkText: true },
    ];

    const subscribedTypes = PORTFOLIO_CONFIGS.filter(c => activeSubs[c.subKey]);
    const cards: PortfolioCardData[] = [];

    await Promise.all(
      subscribedTypes.map(async (config) => {
        try {
          const res = await apiService.getPortfolio(config.type);
          if (res.success && res.data) {
            const d = res.data as Record<string, unknown>;
            const portfolio = (d.portfolio || d) as Record<string, unknown>;
            const holdings = (d.holdings || []) as unknown[];
            cards.push({
              type: config.type,
              label: config.label,
              emoji: config.emoji,
              gradientColors: config.gradientColors,
              icon: config.icon,
              cashBalance: Number(portfolio.cash_balance ?? portfolio.cashBalance ?? 0),
              totalValue: Number(portfolio.holdings_value ?? portfolio.holdingsValue ?? portfolio.total_value ?? portfolio.totalValue ?? 0),
              initialBalance: Number(portfolio.initial_balance ?? portfolio.initialBalance ?? 10000000),
              holdingsCount: Array.isArray(holdings) ? holdings.filter((h: unknown) => {
                const holding = h as Record<string, unknown>;
                return Number(holding.quantity ?? 0) > 0;
              }).length : 0,
              darkText: config.darkText,
            });
          }
        } catch {
          // Skip failed portfolio fetch
        }
      })
    );

    // Sort to match config order
    const typeOrder = subscribedTypes.map(c => c.type);
    cards.sort((a, b) => typeOrder.indexOf(a.type) - typeOrder.indexOf(b.type));
    setPortfolioCards(cards);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // subs always passed explicitly, no need to depend on userSubscriptions

  // Record daily login once per session
  const hasRecordedLogin = useRef(false);
  const recordLogin = useCallback(async () => {
    if (hasRecordedLogin.current) return;
    hasRecordedLogin.current = true;
    try {
      const loginRes = await apiService.recordDailyLogin();
      if (loginRes.success && loginRes.data) {
        setStreak(loginRes.data.currentStreak || loginRes.data.current_streak || 0);
        const achievements = loginRes.data.newAchievements || loginRes.data.new_achievements;
        if (achievements?.length > 0) {
          setUnlockedAchievement(achievements[0]);
        }
      }
      // Fetch challenges only on initial login, not on polls
      const challengeRes = await apiService.getDailyChallenges();
      if (challengeRes.success && challengeRes.data) {
        setDailyChallenges(challengeRes.data.challenges || challengeRes.data.daily_challenges || []);
      }
    } catch (err) {
      hasRecordedLogin.current = false; // allow retry on failure
      console.warn('Login record error:', err);
    }
  }, []);

  // Refresh gamification profile (XP, level) - safe for polling
  const fetchGamProfile = useCallback(async () => {
    try {
      const profileRes = await apiService.getGamificationProfile();
      if (profileRes.success && profileRes.data) {
        const d = profileRes.data as Record<string, unknown>;
        const newXP = Number(d.totalXP ?? d.total_xp ?? 0);

        // Detect XP change
        if (prevXP.current !== null && newXP > prevXP.current) {
          const delta = newXP - prevXP.current;
          setXpDelta(delta);
          setShowXpToast(true);
        }
        prevXP.current = newXP;

        setGamProfile({
          totalXP: newXP,
          level: Number(d.level ?? d.player_level ?? 1),
          levelName: String(d.levelName ?? d.level_name ?? 'Rookie'),
          nextLevelXP: Number(d.nextLevelXP ?? d.next_level_xp ?? 100),
          xpToNextLevel: Number(d.xpToNextLevel ?? d.xp_to_next_level ?? 100),
        });

        // Extract recent XP activity
        const xpLog = d.recentXP ?? d.recent_xp;
        if (Array.isArray(xpLog)) {
          setRecentXP(xpLog);
        }
      }
    } catch (err) {
      console.warn('Gamification profile fetch error:', err);
    }
  }, []);

  // Fetch all data (unified)
  const fetchData = useCallback(async (bypassCache = false) => {
    if (!hasLoadedOnce.current) setLoading(true);
    let finished = false;
    const timeout = setTimeout(() => {
      if (!finished) {
        setLoading(false);
        console.warn('Dashboard loading timed out');
      }
    }, 8000);
    try {
      // Fetch dashboard data, login (once), and profile in parallel
      const [subs] = await Promise.all([
        fetchDashboardData(bypassCache),
        recordLogin().catch(() => {}),
        fetchGamProfile().catch(() => {}),
      ]);
      // If unified endpoint didn't return subscriptions, fetch them directly
      let activeSubs = subs;
      if (!activeSubs) {
        try {
          const subRes = await apiService.request('/mobile/subscriptions', { method: 'GET' });
          if (subRes.success && subRes.data) {
            const sd = (subRes.data as Record<string, unknown>)?.subscriptions || subRes.data;
            const s = sd as Record<string, unknown>;
            activeSubs = { weekly: !!s?.weekly, monthly: !!s?.monthly, annual: !!s?.annual, default: true };
            setUserSubscriptions(activeSubs);
          }
        } catch {
          // Fall through with default subs
        }
      }
      // Portfolio cards depend on subscriptions, so fetch after we have them
      await fetchPortfolioCards(activeSubs || undefined).catch((err) => {
        console.error('Portfolio cards error:', err);
      });
    } finally {
      finished = true;
      hasLoadedOnce.current = true;
      clearTimeout(timeout);
      setLoading(false);
    }
  }, [fetchDashboardData, recordLogin, fetchGamProfile, fetchPortfolioCards]);

  // Poll every 60 seconds for live updates
  useEffect(() => {
    fetchData();
    const interval = setInterval(() => {
      fetchData(true); // bypass cache for polling
    }, 60000);
    return () => clearInterval(interval);
  }, [fetchData]);

  const onRefresh = async () => {
    setRefreshing(true);
    await fetchData(true);
    setRefreshing(false);
  };

  // Greeting based on time
  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />
        <LoadingSpinner />
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
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={colors.primary} />}
          showsVerticalScrollIndicator={false}
        >
          {/* Header */}
          <View style={styles.header}>
            <View style={styles.greetingRow}>
              <View style={styles.greetingLeft}>
                <Text style={styles.greeting}>{getGreeting()},</Text>
                <Text style={styles.username}>{user?.first_name || user?.username || 'Trader'}</Text>
              </View>
              {/* Market Status Pill */}
              <View style={[styles.marketPill, marketOpen ? styles.marketPillOpen : styles.marketPillClosed]}>
                <View style={[styles.statusDot, { backgroundColor: marketOpen ? colors.success : colors.danger }]} />
                <View>
                  <Text style={styles.marketPillText}>{marketOpen ? 'Open' : 'Closed'}</Text>
                  <Text style={styles.marketPillTime}>{ukTime}</Text>
                </View>
              </View>
            </View>

            {/* Gamification Bar */}
            {gamProfile && (
              <Animated.View entering={FadeInDown.delay(100).duration(400)} style={styles.gamBar}>
                <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', width: '100%' }}>
                  {/* Level and name in blue, left column (50%) */}
                  <View style={{ flex: 2, alignItems: 'center', justifyContent: 'center' }}>
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, justifyContent: 'center' }}>
                      {/* Badge icon for level */}
                      <Ionicons
                        name={(() => {
                          const icons = {
                            1: 'school-outline',
                            2: 'eye-outline',
                            3: 'trending-up-outline',
                            4: 'swap-horizontal-outline',
                            5: 'briefcase-outline',
                            6: 'stats-chart-outline',
                            7: 'cash-outline',
                            8: 'shield-outline',
                            9: 'diamond-outline',
                            10: 'trophy',
                          };
                          return icons[gamProfile.level] || 'star-outline';
                        })()}
                        size={18}
                        color={'#3B82F6'}
                        style={{ marginRight: 2 }}
                      />
                      <Text style={{ fontWeight: '800', fontSize: 16, color: '#3B82F6' }}>{`Lv.${gamProfile.level}`}</Text>
                      <Text style={{ fontWeight: '700', fontSize: 16, color: '#3B82F6' }}>{gamProfile.levelName}</Text>
                    </View>
                  </View>
                  {/* XP in yellow, center column (25%) */}
                  <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
                    <Text style={{ fontWeight: 'bold', fontSize: 16, color: '#FFD700' }}>{`${gamProfile.totalXP}/${gamProfile.nextLevelXP} XP`}</Text>
                  </View>
                  {/* Streak in orange, right column (25%) */}
                  <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
                    <StreakCounter streak={streak} />
                  </View>
                </View>
                {/* Removed text below XP bar for cleaner look */}
              </Animated.View>
            )}
          </View>

          {/* Quick Actions */}
          <Animated.View entering={FadeInDown.delay(200).duration(400)} style={styles.quickActions}>
          </Animated.View>

          {/* Swipeable Portfolio Cards */}
          <SwipeablePortfolioCards portfolios={portfolioCards} />

          {/* Stock Ticker */}
          <View style={styles.section}>
            <StockTicker />
          </View>

          {/* Daily Challenges */}
          {dailyChallenges.length > 0 && (
            <Animated.View entering={FadeInDown.delay(300).duration(400)} style={styles.section}>
              <TouchableOpacity onPress={() => router.push('/challenges')} activeOpacity={0.8}>
                <DailyChallengeCard challenges={dailyChallenges} />
              </TouchableOpacity>
              <TouchableOpacity
                onPress={() => router.push('/challenges')}
                style={{ alignItems: 'center', paddingVertical: 8, marginTop: 4 }}
              >
                <Text style={{ color: '#FBBF24', fontSize: 13, fontWeight: '600' }}>View All Challenges →</Text>
              </TouchableOpacity>
            </Animated.View>
          )}

          {/* XP Activity Feed */}
          {recentXP.length > 0 && (
            <XPActivityFeed entries={recentXP} />
          )}

          {/* Bottom padding for tab bar */}
          <View style={{ height: 100 }} />
        </ScrollView>
      </SafeAreaView>

      {/* XP Gain Toast */}
      <XPGainToast
        amount={xpDelta}
        visible={showXpToast}
        onFinish={() => setShowXpToast(false)}
      />

      {/* Achievement Unlocked Modal */}
      <AchievementUnlockedModal
        visible={!!unlockedAchievement}
        achievement={unlockedAchievement}
        onClose={() => setUnlockedAchievement(null)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  loadingContainer: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  safeArea: { flex: 1 },
  scrollView: { flex: 1 },
  scrollContent: { paddingHorizontal: spacing.lg },

  // Header
  header: { paddingTop: spacing.md, paddingBottom: spacing.sm },
  greetingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  greetingLeft: { flex: 1, marginRight: spacing.md },
  greeting: { color: colors.textSecondary, fontSize: typography.md },
  username: { color: colors.textPrimary, fontSize: typography.xxl, fontWeight: 'bold', marginTop: 2 },

  // Market status pill
  marketPill: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: radii.xl,
    gap: 8,
  },
  marketPillOpen: { backgroundColor: 'rgba(16, 185, 129, 0.15)', borderWidth: 1, borderColor: 'rgba(16, 185, 129, 0.3)' },
  marketPillClosed: { backgroundColor: 'rgba(239, 68, 68, 0.15)', borderWidth: 1, borderColor: 'rgba(239, 68, 68, 0.3)' },
  statusDot: { width: 8, height: 8, borderRadius: 4 },
  marketPillText: { color: colors.textPrimary, fontSize: typography.sm, fontWeight: '600' },
  marketPillTime: { color: colors.textSecondary, fontSize: typography.xs, marginTop: 1 },

  // Gamification bar
  gamBar: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: spacing.md,
    ...glassStyle(0.4),
    padding: spacing.md,
    gap: spacing.md,
  },
  gamBarCenter: { flex: 1 },
  xpValue: { color: colors.xp, fontSize: typography.body, fontWeight: '700' },
  xpBarTrack: {
    height: 4,
    backgroundColor: 'rgba(255,255,255,0.1)',
    borderRadius: 2,
    marginTop: 4,
    overflow: 'hidden',
  },
  xpBarFill: {
    height: '100%',
    backgroundColor: colors.xp,
    borderRadius: 2,
  },
  xpToNext: { color: colors.textMuted, fontSize: typography.xs, marginTop: 3 },

  // Quick actions
  quickActions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: spacing.lg,
    gap: spacing.sm,
  },
  quickAction: {
    flex: 1,
    alignItems: 'center',
    gap: 6,
  },
  quickActionIcon: {
    width: 48,
    height: 48,
    borderRadius: radii.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  quickActionLabel: {
    color: colors.textSecondary,
    fontSize: typography.xs,
    fontWeight: '600',
  },

  // Sections
  section: { marginTop: spacing.xl },
});
