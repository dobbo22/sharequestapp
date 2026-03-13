import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  Switch,
  Alert,
  Linking,
  ActivityIndicator,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import Animated, { FadeInDown } from 'react-native-reanimated';
import { useAuth } from '../../src/hooks/useAuth';
import { apiService } from '../../src/services/api';
import Constants from 'expo-constants';
import { PlayerLevelBadge, AchievementBadge } from '../../src/components/gamification';
import { colors, spacing, radii, typography, glassStyle } from '../../src/lib/theme';

interface UserStats {
  totalTrades?: number;
  portfoliosCount?: number;
  leaguesJoined?: number;
  memberSince?: string;
}

interface SettingsItem {
  id: string;
  label: string;
  icon: keyof typeof MaterialCommunityIcons.glyphMap;
  type: 'link' | 'toggle' | 'action';
  value?: boolean;
  onPress?: () => void;
  onToggle?: (value: boolean) => void;
  color?: string;
  danger?: boolean;
}

export default function ProfileScreen() {
  const router = useRouter();
  const { user, signOut } = useAuth();

  const [loading, setLoading] = useState(false);
  const [userStats, setUserStats] = useState<UserStats>({});
  const [notifications, setNotifications] = useState(true);
  const [darkMode, setDarkMode] = useState(true);
  const [biometrics, setBiometrics] = useState(false);
  const [gamProfile, setGamProfile] = useState<any>(null);

  useEffect(() => {
    fetchUserStats();
    fetchGamificationProfile();
  }, []);

  const fetchUserStats = async () => {
    try {
      const response = await apiService.getProfile();
      if (response.success && response.data) {
        const stats: UserStats = {
          memberSince: response.data.created_at,
        };

        // Fetch subscribed portfolio count from dashboard
        try {
          const dashResponse = await apiService.request<{ portfolios?: Array<{ isSubscribed?: boolean }> }>('/mobile/dashboard');
          if (dashResponse.success && dashResponse.data?.portfolios) {
            stats.portfoliosCount = dashResponse.data.portfolios.filter(p => p.isSubscribed).length;
          }
        } catch {}

        // Fetch league count
        try {
          const leagueResponse = await apiService.request<{ myLeagues?: any[] }>('/mobile/leagues');
          if (leagueResponse.success && leagueResponse.data?.myLeagues) {
            stats.leaguesJoined = leagueResponse.data.myLeagues.length;
          }
        } catch {}

        setUserStats(stats);
      }
    } catch (err) {
      console.log('Could not fetch user stats');
    }
  };

  const fetchGamificationProfile = async () => {
    try {
      const res = await apiService.getGamificationProfile();
      if (res.success && res.data) {
        setGamProfile(res.data);
      }
    } catch (err) {
      console.warn('Could not fetch gamification profile');
    }
  };

  const handleLogout = () => {
    Alert.alert(
      'Logout',
      'Are you sure you want to logout?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Logout',
          style: 'destructive',
          onPress: async () => {
            setLoading(true);
            try {
              await signOut();
              router.replace('/(auth)/login');
            } catch (err) {
              Alert.alert('Error', 'Failed to logout');
            } finally {
              setLoading(false);
            }
          },
        },
      ]
    );
  };

  const openURL = async (url: string) => {
    try {
      await Linking.openURL(url);
    } catch (err) {
      Alert.alert('Error', 'Could not open link');
    }
  };

  const formatDate = (dateString?: string) => {
    if (!dateString) return 'Unknown';
    try {
      return new Date(dateString).toLocaleDateString('en-GB', {
        month: 'long',
        year: 'numeric',
      });
    } catch {
      return 'Unknown';
    }
  };

  const settingsSections: { title: string; items: SettingsItem[] }[] = [
    {
      title: 'Account',
      items: [
        {
          id: 'subscription',
          label: 'Subscription',
          icon: 'card-outline',
          type: 'link',
          onPress: () => Alert.alert('Subscription', 'Manage your subscription in the web app'),
        },
        {
          id: 'notifications',
          label: 'Push Notifications',
          icon: 'bell-outline',
          type: 'toggle',
          value: notifications,
          onToggle: setNotifications,
        },
        {
          id: 'biometrics',
          label: 'Face ID / Touch ID',
          icon: 'fingerprint',
          type: 'toggle',
          value: biometrics,
          onToggle: setBiometrics,
        },
      ],
    },
    {
      title: 'Preferences',
      items: [
        {
          id: 'darkMode',
          label: 'Dark Mode',
          icon: 'weather-night',
          type: 'toggle',
          value: darkMode,
          onToggle: setDarkMode,
        },
      ],
    },
    {
      title: 'Support',
      items: [
        {
          id: 'help',
          label: 'Help Center',
          icon: 'help-circle-outline',
          type: 'link',
          onPress: () => openURL('https://sta-trading.com/help'),
        },
        {
          id: 'feedback',
          label: 'Send Feedback',
          icon: 'message-text-outline',
          type: 'link',
          onPress: () => openURL('mailto:support@sta-trading.com'),
        },
        {
          id: 'rate',
          label: 'Rate the App',
          icon: 'star-outline',
          type: 'link',
          onPress: () => Alert.alert('Coming Soon', 'App Store rating will be available after launch'),
        },
      ],
    },
    {
      title: 'Legal',
      items: [
        {
          id: 'terms',
          label: 'Terms of Service',
          icon: 'file-document-outline',
          type: 'link',
          onPress: () => openURL('https://sta-trading.com/terms'),
        },
        {
          id: 'privacy',
          label: 'Privacy Policy',
          icon: 'shield-check-outline',
          type: 'link',
          onPress: () => openURL('https://sta-trading.com/privacy'),
        },
      ],
    },
    {
      title: 'Account Actions',
      items: [
        {
          id: 'logout',
          label: 'Logout',
          icon: 'logout',
          type: 'action',
          onPress: handleLogout,
          danger: true,
        },
      ],
    },
  ];

  const renderSettingsItem = (item: SettingsItem) => (
    <TouchableOpacity
      key={item.id}
      style={styles.settingsItem}
      onPress={item.type !== 'toggle' ? item.onPress : undefined}
      activeOpacity={item.type === 'toggle' ? 1 : 0.7}
    >
      <View style={styles.settingsItemLeft}>
        <View style={[styles.settingsIcon, item.danger && styles.settingsIconDanger]}>
          <MaterialCommunityIcons
            name={item.icon}
            size={20}
            color={item.danger ? '#EF4444' : '#3B82F6'}
          />
        </View>
        <Text style={[styles.settingsItemLabel, item.danger && styles.settingsItemLabelDanger]}>
          {item.label}
        </Text>
      </View>

      {item.type === 'toggle' && (
        <Switch
          value={item.value}
          onValueChange={item.onToggle}
          trackColor={{ false: 'rgba(75, 85, 99, 0.5)', true: 'rgba(59, 130, 246, 0.5)' }}
          thumbColor={item.value ? '#3B82F6' : '#9CA3AF'}
          ios_backgroundColor="rgba(75, 85, 99, 0.5)"
        />
      )}

      {item.type === 'link' && (
        <MaterialCommunityIcons name="chevron-right" size={20} color="#6B7280" />
      )}
    </TouchableOpacity>
  );

  const appVersion = Constants.expoConfig?.version || '1.0.0';

  return (
    <View style={styles.container}>
      <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />

      <SafeAreaView style={styles.safeArea} edges={['top']}>
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
        >
          {/* Header */}
          <View style={styles.header}>
            <Text style={styles.headerTitle}>Profile</Text>
          </View>

          {/* User Info Card */}
          <Animated.View entering={FadeInDown.duration(400)}>
            <LinearGradient
              colors={['rgba(59, 130, 246, 0.2)', 'rgba(139, 92, 246, 0.2)']}
              style={styles.userCard}
            >
              <View style={styles.avatarContainer}>
                {user?.avatar_url ? (
                  <Image source={{ uri: user.avatar_url }} style={styles.avatar} />
                ) : (
                  <LinearGradient colors={['#3B82F6', '#8B5CF6']} style={styles.avatar}>
                    <Text style={styles.avatarText}>
                      {user?.username?.charAt(0)?.toUpperCase() || user?.email?.charAt(0)?.toUpperCase() || 'U'}
                    </Text>
                  </LinearGradient>
                )}
                {/* XP level ring indicator */}
                {gamProfile && (
                  <View style={styles.levelRingBadge}>
                    <Text style={styles.levelRingText}>{gamProfile.level}</Text>
                  </View>
                )}
              </View>

              <View style={styles.userInfo}>
                <Text style={styles.userName}>{user?.username || 'User'}</Text>
                <Text style={styles.userEmail}>{user?.email || ''}</Text>
                {userStats.memberSince && (
                  <Text style={styles.memberSince}>Member since {formatDate(userStats.memberSince)}</Text>
                )}
              </View>

              <TouchableOpacity
                style={styles.editButton}
                onPress={() => router.push('/edit-profile')}
              >
                <MaterialCommunityIcons name="pencil" size={18} color="#3B82F6" />
              </TouchableOpacity>
            </LinearGradient>
          </Animated.View>

          {/* Player Level */}
          {gamProfile && (
            <Animated.View entering={FadeInDown.delay(100).duration(400)} style={styles.gamificationCard}>
              <PlayerLevelBadge
                level={gamProfile.level}
                levelName={gamProfile.levelName}
                totalXP={gamProfile.totalXP}
                nextLevelXP={gamProfile.nextLevelXP}
                xpToNextLevel={gamProfile.xpToNextLevel}
                showProgress
              />
              {/* Streak Stats - tappable to open challenges */}
              <TouchableOpacity onPress={() => router.push('/challenges')} activeOpacity={0.7}>
                <View style={styles.streakRow}>
                  <View style={styles.streakStat}>
                    <MaterialCommunityIcons name="flame" size={18} color="#FB923C" />
                    <Text style={styles.streakValue}>{gamProfile.currentStreak}</Text>
                    <Text style={styles.streakLabel}>Current Streak</Text>
                  </View>
                  <View style={styles.streakStat}>
                    <MaterialCommunityIcons name="trophy-outline" size={18} color="#FBBF24" />
                    <Text style={styles.streakValue}>{gamProfile.longestStreak}</Text>
                    <Text style={styles.streakLabel}>Best Streak</Text>
                  </View>
                </View>
              </TouchableOpacity>
            </Animated.View>
          )}

          {/* Achievements */}
          {gamProfile?.achievements?.length > 0 && (
            <View style={styles.achievementsSection}>
              <Text style={styles.sectionTitle}>Achievements</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.achievementScroll}>
                {gamProfile.achievements
                  .sort((a: any, b: any) => (b.unlocked ? 1 : 0) - (a.unlocked ? 1 : 0))
                  .map((ua: any) => (
                    <AchievementBadge
                      key={ua.achievement.code}
                      name={ua.achievement.name}
                      icon={ua.achievement.icon}
                      tier={ua.achievement.tier}
                      unlocked={ua.unlocked}
                    />
                  ))}
              </ScrollView>
            </View>
          )}

          {/* Quick Stats */}
          <Animated.View entering={FadeInDown.delay(200).duration(400)} style={styles.statsContainer}>
            <View style={styles.statCard}>
              <MaterialCommunityIcons name="swap-horizontal" size={24} color="#3B82F6" />
              <Text style={styles.statValue}>{userStats.totalTrades || 0}</Text>
              <Text style={styles.statLabel}>Trades</Text>
            </View>
            <View style={styles.statCard}>
              <MaterialCommunityIcons name="briefcase" size={24} color="#10B981" />
              <Text style={styles.statValue}>{userStats.portfoliosCount ?? 0}</Text>
              <Text style={styles.statLabel}>Portfolios</Text>
            </View>
            <View style={styles.statCard}>
              <MaterialCommunityIcons name="account-group" size={24} color="#8B5CF6" />
              <Text style={styles.statValue}>{userStats.leaguesJoined || 0}</Text>
              <Text style={styles.statLabel}>Leagues</Text>
            </View>
          </Animated.View>

          {/* Settings Sections */}
          {settingsSections.map((section) => (
            <View key={section.title} style={styles.settingsSection}>
              <Text style={styles.sectionTitle}>{section.title}</Text>
              <View style={styles.settingsCard}>
                {section.items.map(renderSettingsItem)}
              </View>
            </View>
          ))}

          {/* App Version */}
          <View style={styles.versionContainer}>
            <Text style={styles.versionText}>STA Trading App</Text>
            <Text style={styles.versionNumber}>Version {appVersion}</Text>
          </View>

          {/* Loading Overlay */}
          {loading && (
            <View style={styles.loadingOverlay}>
              <ActivityIndicator size="large" color="#3B82F6" />
            </View>
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
  scrollView: { flex: 1 },
  scrollContent: { paddingHorizontal: 20 },
  header: { paddingVertical: 16 },
  headerTitle: { color: '#FFFFFF', fontSize: 28, fontWeight: 'bold' },
  userCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 20,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    marginBottom: 20,
  },
  avatarContainer: { marginRight: 16, position: 'relative' },
  avatar: {
    width: 64,
    height: 64,
    borderRadius: 32,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 3,
    borderColor: 'rgba(251, 191, 36, 0.5)',
  },
  avatarText: { color: '#FFFFFF', fontSize: 28, fontWeight: 'bold' },
  levelRingBadge: {
    position: 'absolute',
    bottom: -4,
    right: -4,
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: colors.xp,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: colors.background,
  },
  levelRingText: {
    color: '#000',
    fontSize: 11,
    fontWeight: 'bold',
  },
  userInfo: { flex: 1 },
  userName: { color: '#FFFFFF', fontSize: 20, fontWeight: 'bold' },
  userEmail: { color: '#9CA3AF', fontSize: 14, marginTop: 2 },
  memberSince: { color: '#6B7280', fontSize: 12, marginTop: 4 },
  editButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(59, 130, 246, 0.2)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  gamificationCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 16,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  streakRow: { flexDirection: 'row', marginTop: 16, gap: 12 },
  streakStat: { flex: 1, flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(15,23,42,0.5)', borderRadius: 12, padding: 10, gap: 6 },
  streakValue: { color: '#FFF', fontWeight: 'bold', fontSize: 18 },
  streakLabel: { color: '#9CA3AF', fontSize: 11 },
  achievementsSection: { marginBottom: 16 },
  achievementScroll: { paddingVertical: 8 },
  statsContainer: {
    flexDirection: 'row',
    marginBottom: 24,
  },
  statCard: {
    flex: 1,
    alignItems: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 16,
    padding: 16,
    marginHorizontal: 4,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  statValue: { color: '#FFFFFF', fontSize: 24, fontWeight: 'bold', marginTop: 8 },
  statLabel: { color: '#9CA3AF', fontSize: 12, marginTop: 4 },
  settingsSection: { marginBottom: 24 },
  sectionTitle: { color: '#9CA3AF', fontSize: 13, fontWeight: '600', marginBottom: 8, marginLeft: 4, textTransform: 'uppercase' },
  settingsCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 16,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  settingsItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
  },
  settingsItemLeft: { flexDirection: 'row', alignItems: 'center', flex: 1 },
  settingsIcon: {
    width: 36,
    height: 36,
    borderRadius: 10,
    backgroundColor: 'rgba(59, 130, 246, 0.15)',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  settingsIconDanger: { backgroundColor: 'rgba(239, 68, 68, 0.15)' },
  settingsItemLabel: { color: '#FFFFFF', fontSize: 15 },
  settingsItemLabelDanger: { color: '#EF4444' },
  versionContainer: { alignItems: 'center', paddingVertical: 24 },
  versionText: { color: '#6B7280', fontSize: 14 },
  versionNumber: { color: '#4B5563', fontSize: 12, marginTop: 4 },
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
});
