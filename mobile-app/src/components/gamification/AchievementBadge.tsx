import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

const TIER_COLORS: Record<string, string> = {
  bronze: '#CD7F32',
  silver: '#C0C0C0',
  gold: '#FFD700',
  platinum: '#E5E4E2',
};

const ICON_MAP: Record<string, keyof typeof Ionicons.glyphMap> = {
  'rocket': 'rocket-outline',
  'trending-up': 'trending-up-outline',
  'activity': 'pulse-outline',
  'award': 'ribbon-outline',
  'zap': 'flash-outline',
  'dollar-sign': 'cash-outline',
  'target': 'locate-outline',
  'star': 'star-outline',
  'pie-chart': 'pie-chart-outline',
  'crown': 'trophy-outline',
  'layers': 'layers-outline',
  'gem': 'diamond-outline',
  'clock': 'time-outline',
  'users': 'people-outline',
  'flag': 'flag-outline',
  'message-circle': 'chatbubble-outline',
  'flame': 'flame-outline',
};

interface Props {
  name: string;
  icon: string;
  tier: string;
  unlocked: boolean;
  compact?: boolean;
}

export default function AchievementBadge({ name, icon, tier, unlocked, compact }: Props) {
  const tierColor = TIER_COLORS[tier] || '#3B82F6';
  const ionIcon = ICON_MAP[icon] || 'medal-outline';
  const size = compact ? 48 : 64;

  return (
    <View style={[styles.container, { width: size + 16 }]}>
      <View style={[
        styles.badge,
        { width: size, height: size, borderColor: unlocked ? tierColor : '#374151' },
        !unlocked && styles.locked
      ]}>
        <Ionicons
          name={ionIcon}
          size={size * 0.45}
          color={unlocked ? tierColor : '#6B7280'}
        />
      </View>
      {!compact && (
        <Text style={[styles.name, !unlocked && styles.lockedText]} numberOfLines={2}>
          {name}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', marginHorizontal: 4 },
  badge: {
    borderRadius: 32,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(30, 58, 95, 0.5)',
  },
  locked: { opacity: 0.4 },
  name: { color: '#E5E7EB', fontSize: 10, textAlign: 'center', marginTop: 4 },
  lockedText: { color: '#6B7280' },
});
