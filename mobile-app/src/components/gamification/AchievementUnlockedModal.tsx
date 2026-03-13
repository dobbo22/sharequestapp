import React, { useEffect } from 'react';
import { View, Text, StyleSheet, Modal, TouchableOpacity, Dimensions } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  withRepeat,
  withSequence,
  withDelay,
  Easing,
} from 'react-native-reanimated';
import * as Haptics from 'expo-haptics';

const TIER_COLORS: Record<string, [string, string]> = {
  bronze: ['#CD7F32', '#8B5E3C'],
  silver: ['#C0C0C0', '#808080'],
  gold: ['#FFD700', '#DAA520'],
  platinum: ['#E5E4E2', '#B0AFA9'],
};

const TIER_GRADIENTS: Record<string, [string, string, string]> = {
  bronze: ['#1e3a5f', '#4a2c1a', '#1e3a5f'],
  silver: ['#1e3a5f', '#3d3d4d', '#1e3a5f'],
  gold: ['#1e3a5f', '#5c4a0a', '#581c87'],
  platinum: ['#1e3a5f', '#4a3a6e', '#581c87'],
};

interface Props {
  visible: boolean;
  achievement: { name: string; description: string; icon: string; tier: string; xp_reward: number } | null;
  onClose: () => void;
}

// Radial burst line
function BurstLine({ index, color, total }: { index: number; color: string; total: number }) {
  const scale = useSharedValue(0);
  const opacity = useSharedValue(0);
  const angle = (index / total) * 360;

  useEffect(() => {
    scale.value = withDelay(
      200 + index * 40,
      withSequence(
        withSpring(1, { damping: 6, stiffness: 150 }),
        withDelay(600, withTiming(0, { duration: 400 }))
      )
    );
    opacity.value = withDelay(200 + index * 40, withSequence(
      withTiming(0.6, { duration: 200 }),
      withDelay(600, withTiming(0, { duration: 400 }))
    ));
  }, []);

  const style = useAnimatedStyle(() => ({
    position: 'absolute' as const,
    width: 2,
    height: 40,
    backgroundColor: color,
    opacity: opacity.value,
    transform: [
      { rotate: `${angle}deg` },
      { translateY: -50 },
      { scaleY: scale.value },
    ],
  }));

  return <Animated.View style={style} />;
}

export default function AchievementUnlockedModal({ visible, achievement, onClose }: Props) {
  const cardScale = useSharedValue(0);
  const cardOpacity = useSharedValue(0);
  const starRotation = useSharedValue(0);
  const shimmerX = useSharedValue(-200);

  useEffect(() => {
    if (visible) {
      try { Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium); } catch {}

      cardScale.value = withSpring(1, { damping: 8, stiffness: 120 });
      cardOpacity.value = withTiming(1, { duration: 300 });
      starRotation.value = withRepeat(
        withTiming(360, { duration: 4000, easing: Easing.linear }),
        -1,
        false
      );

      // Shimmer for gold/platinum
      if (achievement?.tier === 'gold' || achievement?.tier === 'platinum') {
        shimmerX.value = withDelay(500, withRepeat(
          withTiming(400, { duration: 1500, easing: Easing.inOut(Easing.ease) }),
          -1,
          false
        ));
      }
    } else {
      cardScale.value = 0;
      cardOpacity.value = 0;
      starRotation.value = 0;
      shimmerX.value = -200;
    }
  }, [visible]);

  const cardStyle = useAnimatedStyle(() => ({
    transform: [{ scale: cardScale.value }],
    opacity: cardOpacity.value,
  }));

  const starStyle = useAnimatedStyle(() => ({
    transform: [{ rotate: `${starRotation.value}deg` }],
  }));

  const shimmerStyle = useAnimatedStyle(() => ({
    position: 'absolute' as const,
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    opacity: 0.15,
    transform: [{ translateX: shimmerX.value }],
  }));

  if (!achievement) return null;

  const tierColors = TIER_COLORS[achievement.tier] || TIER_COLORS.bronze;
  const gradientColors = TIER_GRADIENTS[achievement.tier] || TIER_GRADIENTS.bronze;
  const isHighTier = achievement.tier === 'gold' || achievement.tier === 'platinum';

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <TouchableOpacity style={styles.backdrop} activeOpacity={1} onPress={onClose}>
        <Animated.View style={[styles.card, cardStyle]}>
          <LinearGradient colors={gradientColors} style={styles.gradient}>
            {/* Shimmer overlay for high tiers */}
            {isHighTier && (
              <Animated.View style={shimmerStyle}>
                <LinearGradient
                  colors={['transparent', tierColors[0], 'transparent']}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={StyleSheet.absoluteFill}
                />
              </Animated.View>
            )}

            {/* Burst lines */}
            <View style={styles.burstContainer}>
              {Array.from({ length: 8 }).map((_, i) => (
                <BurstLine key={i} index={i} color={tierColors[0]} total={8} />
              ))}
            </View>

            {/* Star icon */}
            <Animated.View style={starStyle}>
              <Ionicons name="star" size={64} color={tierColors[0]} />
            </Animated.View>

            <Text style={styles.title}>Achievement Unlocked!</Text>
            <Text style={[styles.name, { color: tierColors[0] }]}>{achievement.name}</Text>
            <Text style={styles.description}>{achievement.description}</Text>

            <View style={[styles.tierBadge, { borderColor: `${tierColors[0]}40` }]}>
              <Text style={[styles.tierText, { color: tierColors[0] }]}>
                {achievement.tier.toUpperCase()}
              </Text>
            </View>

            <View style={styles.xpBadge}>
              <Ionicons name="flash" size={18} color="#FBBF24" />
              <Text style={styles.xpText}>+{achievement.xp_reward} XP</Text>
            </View>

            <TouchableOpacity style={styles.button} onPress={onClose}>
              <LinearGradient
                colors={['#3B82F6', '#2563EB']}
                style={styles.buttonGradient}
              >
                <Text style={styles.buttonText}>Awesome!</Text>
              </LinearGradient>
            </TouchableOpacity>
          </LinearGradient>
        </Animated.View>
      </TouchableOpacity>
    </Modal>
  );
}

const { width } = Dimensions.get('window');

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.75)', justifyContent: 'center', alignItems: 'center' },
  card: { width: width * 0.85, borderRadius: 24, overflow: 'hidden' },
  gradient: { padding: 32, alignItems: 'center', overflow: 'hidden' },
  burstContainer: { position: 'absolute', top: 80, alignSelf: 'center', width: 0, height: 0, alignItems: 'center', justifyContent: 'center' },
  title: { color: '#E5E7EB', fontSize: 13, marginTop: 20, textTransform: 'uppercase', letterSpacing: 2.5, fontWeight: '600' },
  name: { fontSize: 24, fontWeight: 'bold', marginTop: 8, textAlign: 'center' },
  description: { color: '#9CA3AF', fontSize: 14, textAlign: 'center', marginTop: 8, lineHeight: 20 },
  tierBadge: { marginTop: 12, borderWidth: 1, borderRadius: 12, paddingHorizontal: 12, paddingVertical: 3 },
  tierText: { fontSize: 11, fontWeight: '800', letterSpacing: 1.5 },
  xpBadge: { flexDirection: 'row', alignItems: 'center', marginTop: 16, backgroundColor: 'rgba(251,191,36,0.15)', paddingHorizontal: 18, paddingVertical: 8, borderRadius: 20 },
  xpText: { color: '#FBBF24', fontWeight: 'bold', fontSize: 18, marginLeft: 6 },
  button: { marginTop: 24, borderRadius: 14, overflow: 'hidden' },
  buttonGradient: { paddingHorizontal: 36, paddingVertical: 14 },
  buttonText: { color: '#FFF', fontWeight: 'bold', fontSize: 16 },
});
