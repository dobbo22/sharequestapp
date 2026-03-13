import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withSequence,
  withTiming,
  withSpring,
  Easing,
} from 'react-native-reanimated';

interface Props {
  streak: number;
}

export default function StreakCounter({ streak }: Props) {
  const flameScale = useSharedValue(1);
  const badgeScale = useSharedValue(0.8);
  const glowOpacity = useSharedValue(0);

  const isMilestone = streak === 7 || streak === 14 || streak === 30;
  const isMaxStreak = streak >= 30;
  const flameColor = streak >= 30 ? '#EF4444' : streak >= 7 ? '#F59E0B' : '#FB923C';

  useEffect(() => {
    if (streak > 0) {
      // Pulse flame
      flameScale.value = withRepeat(
        withSequence(
          withTiming(1.15, { duration: 500, easing: Easing.inOut(Easing.ease) }),
          withTiming(0.95, { duration: 500, easing: Easing.inOut(Easing.ease) })
        ),
        -1,
        true
      );
      // Entry animation
      badgeScale.value = withSpring(1, { damping: 12, stiffness: 200 });

      // Milestone glow
      if (isMilestone || isMaxStreak) {
        glowOpacity.value = withRepeat(
          withSequence(
            withTiming(0.6, { duration: 800 }),
            withTiming(0.1, { duration: 800 })
          ),
          -1,
          true
        );
      }
    }
  }, [streak]);

  const flameStyle = useAnimatedStyle(() => ({
    transform: [{ scale: flameScale.value }],
  }));

  const badgeStyle = useAnimatedStyle(() => ({
    transform: [{ scale: badgeScale.value }],
  }));

  const glowStyle = useAnimatedStyle(() => ({
    opacity: glowOpacity.value,
  }));

  if (streak <= 0) return null;

  return (
    <Animated.View style={[styles.container, isMaxStreak && styles.maxContainer, badgeStyle]}>
      {/* Glow ring for milestones */}
      {(isMilestone || isMaxStreak) && (
        <Animated.View style={[styles.glowRing, { borderColor: flameColor }, glowStyle]} />
      )}
      <Animated.View style={flameStyle}>
        <Ionicons name="flame" size={18} color={flameColor} />
      </Animated.View>
      <Text style={[styles.count, { color: flameColor }]}>{streak}</Text>
      {isMaxStreak && <Text style={styles.maxLabel}>MAX</Text>}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(251,146,60,0.15)',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 16,
    overflow: 'visible',
  },
  maxContainer: {
    backgroundColor: 'rgba(239,68,68,0.2)',
    borderWidth: 1,
    borderColor: 'rgba(239,68,68,0.4)',
  },
  glowRing: {
    position: 'absolute',
    top: -3,
    left: -3,
    right: -3,
    bottom: -3,
    borderRadius: 19,
    borderWidth: 2,
  },
  count: { fontWeight: 'bold', fontSize: 14, marginLeft: 4 },
  maxLabel: { color: '#EF4444', fontWeight: '800', fontSize: 9, marginLeft: 3 },
});
