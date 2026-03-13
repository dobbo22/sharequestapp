import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import Svg, { Circle } from 'react-native-svg';
import { colors } from '../../lib/theme';

const LEVEL_COLORS: Record<number, string> = {
  1: '#60A5FA',
  2: '#38BDF8',
  3: '#34D399',
  4: '#A78BFA',
  5: '#FB923C',
  6: '#F472B6',
  7: '#FACC15',
  8: '#F87171',
  9: '#2DD4BF',
  10: '#FFD700',
};

const LEVEL_ICONS: Record<number, keyof typeof Ionicons.glyphMap> = {
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

interface Props {
  level: number;
  levelName: string;
  totalXP: number;
  nextLevelXP: number;
  xpToNextLevel: number;
  showProgress?: boolean;
  compact?: boolean;
}

export default function PlayerLevelBadge({ level, levelName, totalXP, nextLevelXP, xpToNextLevel, showProgress, compact }: Props) {
  const color = LEVEL_COLORS[level] || '#3B82F6';
  const icon = LEVEL_ICONS[level] || 'star-outline';

  const scale = useSharedValue(0.8);
  const progressWidth = useSharedValue(0);

  const pct = xpToNextLevel > 0
    ? Math.min(((totalXP - (nextLevelXP - xpToNextLevel)) / (nextLevelXP - (nextLevelXP - xpToNextLevel))) * 100, 100)
    : 100;

  useEffect(() => {
    scale.value = withSpring(1, { damping: 12, stiffness: 200 });
  }, []);

  useEffect(() => {
    progressWidth.value = withTiming(Math.max(pct, 0), {
      duration: 800,
      easing: Easing.out(Easing.cubic),
    });
  }, [pct]);

  const scaleStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const progressStyle = useAnimatedStyle(() => ({
    width: `${progressWidth.value}%` as any,
  }));

  if (compact) {
    const ringSize = 30;
    const strokeWidth = 2.5;
    const radius = (ringSize - strokeWidth) / 2;
    const circumference = 2 * Math.PI * radius;
    const progressFraction = pct / 100;

    return (
      <Animated.View style={[styles.compactContainer, scaleStyle]}>
        <View style={styles.compactRingWrapper}>
          <Svg width={ringSize} height={ringSize} style={styles.compactRing}>
            <Circle
              cx={ringSize / 2}
              cy={ringSize / 2}
              r={radius}
              stroke="rgba(255,255,255,0.1)"
              strokeWidth={strokeWidth}
              fill="none"
            />
            <Circle
              cx={ringSize / 2}
              cy={ringSize / 2}
              r={radius}
              stroke={color}
              strokeWidth={strokeWidth}
              fill="none"
              strokeDasharray={`${circumference}`}
              strokeDashoffset={circumference * (1 - progressFraction)}
              strokeLinecap="round"
              rotation="-90"
              origin={`${ringSize / 2}, ${ringSize / 2}`}
            />
          </Svg>
          <View style={[styles.compactIconCenter, { backgroundColor: `${color}20` }]}>
            <Ionicons name={icon} size={14} color={color} />
          </View>
        </View>
        <View style={styles.compactTextContainer}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
            <Text style={[styles.compactLevel, { color }]}>{`Lv.${level}`}</Text>
            <Text style={[styles.compactLevel, { color: colors.textSecondary }]}>{levelName}</Text>
          </View>
          <Text style={[styles.compactXP, { color: colors.xp }]}>{`${totalXP}/${nextLevelXP}`}</Text>
        </View>
      </Animated.View>
    );
  }

  return (
    <Animated.View style={[styles.container, scaleStyle]}>
      <View style={styles.row}>
        <View style={[styles.iconCircle, { borderColor: color, shadowColor: color }]}>
          <Ionicons name={icon} size={24} color={color} />
        </View>
        <View style={styles.info}>
          <Text style={[styles.levelName, { color }]}>{levelName}</Text>
          <Text style={styles.xpText}>{totalXP.toLocaleString()} XP</Text>
        </View>
        <View style={[styles.levelBadge, { backgroundColor: color }]}>
          <Text style={styles.levelNumber}>Lv.{level}</Text>
        </View>
      </View>
      {showProgress && xpToNextLevel > 0 && (
        <View style={styles.progressSection}>
          <View style={styles.progressBar}>
            <Animated.View style={[styles.progressFill, { backgroundColor: color }, progressStyle]} />
          </View>
          <Text style={styles.progressLabel}>{xpToNextLevel.toLocaleString()} XP to next level</Text>
        </View>
      )}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {},
  row: { flexDirection: 'row', alignItems: 'center' },
  iconCircle: {
    width: 48, height: 48, borderRadius: 24, borderWidth: 2,
    alignItems: 'center', justifyContent: 'center',
    backgroundColor: 'rgba(30,58,95,0.5)',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.4, shadowRadius: 8,
  },
  info: { flex: 1, marginLeft: 12 },
  levelName: { fontWeight: 'bold', fontSize: 16 },
  xpText: { color: '#9CA3AF', fontSize: 12, marginTop: 2 },
  levelBadge: { paddingHorizontal: 10, paddingVertical: 4, borderRadius: 12 },
  levelNumber: { color: '#FFF', fontWeight: 'bold', fontSize: 13 },
  progressSection: { marginTop: 10 },
  progressBar: { height: 6, backgroundColor: '#374151', borderRadius: 3, overflow: 'hidden' },
  progressFill: { height: '100%', borderRadius: 3 },
  progressLabel: { color: '#6B7280', fontSize: 10, marginTop: 4, textAlign: 'right' },
  compactContainer: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  compactRingWrapper: { width: 30, height: 30, alignItems: 'center', justifyContent: 'center' },
  compactRing: { position: 'absolute' },
  compactIconCenter: { width: 22, height: 22, borderRadius: 11, alignItems: 'center', justifyContent: 'center' },
  compactTextContainer: { alignItems: 'flex-start' },
  compactLevel: { fontWeight: '800', fontSize: 14, lineHeight: 16 },
  compactXP: { fontWeight: '600', fontSize: 13, lineHeight: 15, marginTop: 2 },
});
