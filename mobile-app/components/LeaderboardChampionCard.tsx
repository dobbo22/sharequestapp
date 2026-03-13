import React from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';

interface Props {
  username: string;
  value: number;
  percent: number;
  gain: number;
  avatar?: string;
  avatarUrl?: string | null;
}

function getInitials(name: string) {
  if (!name) return '?';
  const parts = name.trim().split(' ');
  if (parts.length === 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

export default function LeaderboardChampionCard({ username, value = 0, percent, gain, avatar, avatarUrl }: Props) {
  const isPositive = gain >= 0;

  return (
    <View style={styles.card}>
      {/* Avatar with crown */}
      <View style={styles.avatarSection}>
        <View style={styles.crownWrap}>
          <MaterialCommunityIcons name="crown" size={22} color="#FFD700" />
        </View>
        <View style={styles.avatar}>
          {avatarUrl ? (
            <Image source={{ uri: avatarUrl }} style={styles.avatarImage} />
          ) : (
            <Text style={styles.avatarText}>{getInitials(username)}</Text>
          )}
        </View>
      </View>

      {/* Info */}
      <View style={styles.info}>
        <View style={styles.headerRow}>
          <Text style={styles.rankLabel}>#1</Text>
          <View style={styles.championBadge}>
            <MaterialCommunityIcons name="trophy" size={12} color="#FFD700" />
            <Text style={styles.championText}>CHAMPION</Text>
          </View>
        </View>
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
          <View style={[styles.progressBarFill, { width: '100%' }]} />
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(45, 35, 15, 0.9)',
    borderRadius: 16,
    padding: 14,
    marginVertical: 6,
    borderWidth: 1.5,
    borderColor: '#FFD700',
    shadowColor: '#FFD700',
    shadowOpacity: 0.25,
    shadowRadius: 10,
    elevation: 6,
  },
  avatarSection: {
    alignItems: 'center',
    marginRight: 14,
  },
  crownWrap: {
    marginBottom: -6,
    zIndex: 1,
  },
  avatar: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: 'rgba(255, 215, 0, 0.2)',
    borderWidth: 2.5,
    borderColor: '#FFD700',
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  avatarImage: {
    width: 52,
    height: 52,
    borderRadius: 26,
  },
  avatarText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#FFD700',
  },
  info: {
    flex: 1,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 2,
  },
  rankLabel: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FFD700',
  },
  championBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255, 215, 0, 0.15)',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 10,
    gap: 4,
  },
  championText: {
    color: '#FFD700',
    fontSize: 11,
    fontWeight: 'bold',
    letterSpacing: 1,
  },
  username: {
    fontSize: 17,
    fontWeight: '700',
    color: '#FFFFFF',
    marginBottom: 2,
  },
  statsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  value: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#FDE68A',
  },
  gain: {
    fontSize: 14,
    fontWeight: '700',
  },
  progressBarBg: {
    height: 5,
    backgroundColor: 'rgba(255, 215, 0, 0.15)',
    borderRadius: 3,
    marginTop: 8,
    width: '100%',
    overflow: 'hidden',
  },
  progressBarFill: {
    height: '100%',
    borderRadius: 3,
    backgroundColor: '#FFD700',
  },
});
