import React from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';

interface Props {
  rank: number;
  username: string;
  value: number;
  percent: number;
  gain: number;
  medal: string;
  progress: number; // 0-1
  avatarUrl?: string | null;
}

function getInitials(name: string) {
  if (!name) return '?';
  const parts = name.trim().split(' ');
  if (parts.length === 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

export default function LeaderboardContenderCard({ rank, username, value = 0, percent, gain, medal, progress, avatarUrl }: Props) {
  const isSilver = rank === 2;
  const accentColor = isSilver ? '#C0C0C0' : '#CD7F32';
  const bgColor = isSilver ? 'rgba(40, 45, 55, 0.9)' : 'rgba(50, 35, 20, 0.9)';
  const isPositive = gain >= 0;

  return (
    <View style={[styles.card, { backgroundColor: bgColor, borderColor: accentColor }]}>
      {/* Avatar with medal */}
      <View style={styles.avatarSection}>
        <Text style={styles.medal}>{medal}</Text>
        <View style={[styles.avatar, { borderColor: accentColor, backgroundColor: `${accentColor}20` }]}>
          {avatarUrl ? (
            <Image source={{ uri: avatarUrl }} style={styles.avatarImage} />
          ) : (
            <Text style={[styles.avatarText, { color: accentColor }]}>{getInitials(username)}</Text>
          )}
        </View>
      </View>

      {/* Info */}
      <View style={styles.info}>
        <Text style={[styles.rankText, { color: accentColor }]}>#{rank}</Text>
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
    borderRadius: 14,
    padding: 12,
    marginVertical: 4,
    borderWidth: 1.5,
    shadowColor: '#000',
    shadowOpacity: 0.15,
    shadowRadius: 6,
    elevation: 3,
  },
  avatarSection: {
    alignItems: 'center',
    marginRight: 12,
  },
  medal: {
    fontSize: 18,
    marginBottom: -4,
  },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    overflow: 'hidden',
  },
  avatarImage: {
    width: 44,
    height: 44,
    borderRadius: 22,
  },
  avatarText: {
    fontSize: 16,
    fontWeight: 'bold',
  },
  info: {
    flex: 1,
  },
  rankText: {
    fontSize: 14,
    fontWeight: 'bold',
    marginBottom: 2,
  },
  username: {
    fontSize: 16,
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
    fontSize: 15,
    fontWeight: 'bold',
    color: '#E2E8F0',
  },
  gain: {
    fontSize: 13,
    fontWeight: '700',
  },
  progressBarBg: {
    height: 5,
    backgroundColor: 'rgba(75, 85, 99, 0.4)',
    borderRadius: 3,
    marginTop: 7,
    width: '100%',
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    borderRadius: 3,
  },
});
