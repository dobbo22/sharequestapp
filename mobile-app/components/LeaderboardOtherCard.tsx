import React from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';

interface Props {
  rank: number;
  username: string;
  value: number;
  percent: number;
  gain: number;
  progress: number; // 0-1
  avatarUrl?: string | null;
}

const RANK_COLORS = [
  '#3B82F6', // blue
  '#8B5CF6', // violet
  '#06B6D4', // cyan
  '#EC4899', // pink
  '#F97316', // orange
  '#14B8A6', // teal
  '#6366F1', // indigo
];

function getAvatarColor(rank: number) {
  return RANK_COLORS[(rank - 1) % RANK_COLORS.length];
}

function getInitials(name: string) {
  if (!name) return '?';
  const parts = name.trim().split(' ');
  if (parts.length === 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

export default function LeaderboardOtherCard({ rank, username, value = 0, percent, gain, progress, avatarUrl }: Props) {
  const accentColor = getAvatarColor(rank);
  const isPositive = gain >= 0;

  return (
    <View style={styles.card}>
      {/* Rank */}
      <View style={styles.rankContainer}>
        <Text style={styles.rankText}>{rank}</Text>
      </View>

      {/* Avatar */}
      <View style={[styles.avatar, { backgroundColor: `${accentColor}30`, borderColor: accentColor }]}>
        {avatarUrl ? (
          <Image source={{ uri: avatarUrl }} style={styles.avatarImage} />
        ) : (
          <Text style={[styles.avatarText, { color: accentColor }]}>{getInitials(username)}</Text>
        )}
      </View>

      {/* Info */}
      <View style={styles.info}>
        <Text style={styles.username} numberOfLines={1}>{username.toUpperCase()}</Text>
        <View style={styles.statsRow}>
          <Text style={styles.value}>
            {typeof value === 'number' && !isNaN(value)
              ? `\u00A3${(value / 100).toLocaleString('en-GB', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
              : '--'}
          </Text>
          <Text style={[styles.gain, { color: isPositive ? '#34D399' : '#F87171' }]}>
            {isPositive ? '+' : ''}{gain.toFixed(2)}%
          </Text>
        </View>
        {/* Progress bar */}
        <View style={styles.progressBarBg}>
          <View style={[styles.progressBarFill, { width: `${Math.round(progress * 100)}%`, backgroundColor: accentColor }]} />
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(30, 41, 59, 0.8)',
    borderRadius: 14,
    padding: 12,
    marginVertical: 4,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  rankContainer: {
    width: 28,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 10,
  },
  rankText: {
    fontSize: 15,
    fontWeight: 'bold',
    color: '#9CA3AF',
  },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
    borderWidth: 2,
    overflow: 'hidden',
  },
  avatarImage: {
    width: 40,
    height: 40,
    borderRadius: 20,
  },
  avatarText: {
    fontSize: 15,
    fontWeight: 'bold',
  },
  info: {
    flex: 1,
  },
  username: {
    fontSize: 15,
    fontWeight: '600',
    color: '#FFFFFF',
    marginBottom: 2,
  },
  statsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  value: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#E2E8F0',
  },
  gain: {
    fontSize: 13,
    fontWeight: '700',
  },
  progressBarBg: {
    height: 4,
    backgroundColor: 'rgba(75, 85, 99, 0.4)',
    borderRadius: 2,
    marginTop: 6,
    width: '100%',
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    borderRadius: 2,
  },
});
