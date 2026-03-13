import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSpring,
  withRepeat,
  withSequence,
  Easing,
} from 'react-native-reanimated';

interface Challenge {
  id: number;
  name: string;
  description: string;
  criteria_value: number;
  xp_reward: number;
  progress: number;
  completed: boolean;
}

interface Props {
  challenges: Challenge[];
}

function ChallengeRow({ challenge, index }: { challenge: Challenge; index: number }) {
  const pct = Math.min((challenge.progress / challenge.criteria_value) * 100, 100);
  const progressWidth = useSharedValue(0);
  const checkScale = useSharedValue(challenge.completed ? 1 : 0);
  const xpPulse = useSharedValue(1);
  const rowOpacity = useSharedValue(0);

  useEffect(() => {
    // Staggered entry
    rowOpacity.value = withTiming(1, { duration: 300, easing: Easing.out(Easing.ease) });
    // Animate progress bar
    progressWidth.value = withTiming(pct, { duration: 800, easing: Easing.out(Easing.cubic) });
  }, []);

  useEffect(() => {
    progressWidth.value = withTiming(pct, { duration: 600, easing: Easing.out(Easing.cubic) });
    if (challenge.completed) {
      checkScale.value = withSpring(1, { damping: 8, stiffness: 200 });
    }
  }, [pct, challenge.completed]);

  useEffect(() => {
    if (!challenge.completed) {
      xpPulse.value = withRepeat(
        withSequence(
          withTiming(1.1, { duration: 1000 }),
          withTiming(1, { duration: 1000 })
        ),
        -1,
        true
      );
    }
  }, [challenge.completed]);

  const progressStyle = useAnimatedStyle(() => ({
    width: `${progressWidth.value}%` as any,
  }));

  const checkStyle = useAnimatedStyle(() => ({
    transform: [{ scale: checkScale.value }],
  }));

  const xpStyle = useAnimatedStyle(() => ({
    transform: [{ scale: xpPulse.value }],
  }));

  const rowStyle = useAnimatedStyle(() => ({
    opacity: rowOpacity.value,
  }));

  return (
    <Animated.View style={[styles.challenge, rowStyle]}>
      <View style={styles.challengeTop}>
        <Text style={styles.challengeName} numberOfLines={1}>{challenge.name}</Text>
        {challenge.completed ? (
          <Animated.View style={checkStyle}>
            <Ionicons name="checkmark-circle" size={20} color="#10B981" />
          </Animated.View>
        ) : (
          <Animated.View style={xpStyle}>
            <Text style={styles.xpLabel}>+{challenge.xp_reward} XP</Text>
          </Animated.View>
        )}
      </View>
      <Text style={styles.challengeDesc} numberOfLines={1}>{challenge.description}</Text>
      <View style={styles.progressBar}>
        <Animated.View
          style={[
            styles.progressFill,
            { backgroundColor: challenge.completed ? '#10B981' : '#3B82F6' },
            progressStyle,
          ]}
        />
      </View>
      <Text style={styles.progressText}>{challenge.progress}/{challenge.criteria_value}</Text>
    </Animated.View>
  );
}

export default function DailyChallengeCard({ challenges }: Props) {
  if (!challenges || challenges.length === 0) return null;

  const completedCount = challenges.filter(c => c.completed).length;

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Ionicons name="today-outline" size={18} color="#FBBF24" />
        <Text style={styles.title}>Daily Challenges</Text>
        <View style={styles.countBadge}>
          <Text style={styles.countText}>{completedCount}/{challenges.length}</Text>
        </View>
      </View>
      {challenges.map((c, i) => (
        <ChallengeRow key={c.id} challenge={c} index={i} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: 'rgba(30, 58, 95, 0.5)',
    borderRadius: 16,
    padding: 16,
    marginHorizontal: 16,
    marginTop: 12,
    borderWidth: 1,
    borderColor: 'rgba(59,130,246,0.3)',
  },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: 12 },
  title: { color: '#FBBF24', fontWeight: 'bold', fontSize: 16, marginLeft: 8, flex: 1 },
  countBadge: {
    backgroundColor: 'rgba(251,191,36,0.15)',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 10,
  },
  countText: { color: '#FBBF24', fontSize: 11, fontWeight: '700' },
  challenge: { marginBottom: 10 },
  challengeTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  challengeName: { color: '#E5E7EB', fontWeight: '600', fontSize: 14, flex: 1, marginRight: 8 },
  challengeDesc: { color: '#9CA3AF', fontSize: 12, marginTop: 2 },
  xpLabel: { color: '#FBBF24', fontSize: 12, fontWeight: 'bold' },
  progressBar: { height: 6, backgroundColor: '#374151', borderRadius: 3, marginTop: 8, overflow: 'hidden' },
  progressFill: { height: '100%', borderRadius: 3 },
  progressText: { color: '#6B7280', fontSize: 10, marginTop: 2, textAlign: 'right' },
});
