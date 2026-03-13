import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Animated, { FadeInDown } from 'react-native-reanimated';
import { colors, spacing, radii, typography, glassStyle } from '../../lib/theme';

interface XPEntry {
  source: string;
  amount: number;
  description: string;
  created_at: string;
}

interface Props {
  entries: XPEntry[];
}

const SOURCE_CONFIG: Record<string, { icon: keyof typeof Ionicons.glyphMap; color: string; label: string }> = {
  trade: { icon: 'swap-horizontal', color: colors.primary, label: 'Trade' },
  daily_login: { icon: 'log-in', color: colors.success, label: 'Login' },
  streak_bonus: { icon: 'flame', color: colors.streak, label: 'Streak' },
  achievement: { icon: 'trophy', color: colors.xp, label: 'Achievement' },
  challenge: { icon: 'flag', color: colors.secondary, label: 'Challenge' },
  diversification: { icon: 'grid', color: colors.info, label: 'Diversity' },
  first_trade: { icon: 'rocket', color: '#EC4899', label: 'First Trade' },
  portfolio_milestone: { icon: 'trending-up', color: colors.success, label: 'Milestone' },
};

function getSourceConfig(source: string) {
  return SOURCE_CONFIG[source] || { icon: 'star' as const, color: colors.xp, label: source };
}

function formatTimeAgo(dateStr: string): string {
  const now = new Date();
  const date = new Date(dateStr);
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;
  return date.toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });
}

export default function XPActivityFeed({ entries }: Props) {
  if (!entries || entries.length === 0) return null;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Ionicons name="flash" size={18} color={colors.xp} />
        <Text style={styles.title}>Recent XP Activity</Text>
      </View>
      <View style={styles.feed}>
        {entries.slice(0, 10).map((entry, index) => {
          const config = getSourceConfig(entry.source);
          return (
            <Animated.View
              key={`${entry.source}-${entry.created_at}-${index}`}
              entering={FadeInDown.delay(index * 40).duration(300)}
              style={styles.entry}
            >
              <View style={[styles.iconWrap, { backgroundColor: `${config.color}20` }]}>
                <Ionicons name={config.icon} size={16} color={config.color} />
              </View>
              <View style={styles.entryContent}>
                <Text style={styles.entryDesc} numberOfLines={1}>
                  {entry.description || config.label}
                </Text>
                <Text style={styles.entryTime}>{formatTimeAgo(entry.created_at)}</Text>
              </View>
              <Text style={[styles.entryXP, { color: entry.amount > 0 ? colors.xp : colors.danger }]}>
                {entry.amount > 0 ? '+' : ''}{entry.amount} XP
              </Text>
            </Animated.View>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginTop: spacing.xl,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: spacing.md,
  },
  title: {
    color: colors.textPrimary,
    fontSize: typography.lg,
    fontWeight: 'bold',
  },
  feed: {
    ...glassStyle(0.4),
    padding: spacing.sm,
    overflow: 'hidden',
  },
  entry: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    paddingHorizontal: spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: colors.borderLight,
  },
  iconWrap: {
    width: 32,
    height: 32,
    borderRadius: radii.sm,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.sm,
  },
  entryContent: {
    flex: 1,
    marginRight: spacing.sm,
  },
  entryDesc: {
    color: colors.textPrimary,
    fontSize: typography.body,
    fontWeight: '500',
  },
  entryTime: {
    color: colors.textMuted,
    fontSize: typography.xs,
    marginTop: 2,
  },
  entryXP: {
    fontSize: typography.body,
    fontWeight: '700',
  },
});
