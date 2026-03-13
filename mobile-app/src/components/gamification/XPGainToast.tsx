import React, { useEffect } from 'react';
import { Text, StyleSheet, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withDelay,
  withSequence,
  withSpring,
  Easing,
} from 'react-native-reanimated';
import * as Haptics from 'expo-haptics';
import * as Device from 'expo-device';

interface Props {
  amount: number;
  visible: boolean;
  onFinish: () => void;
}

// Sparkle particle
function Sparkle({ delay, index }: { delay: number; index: number }) {
  const scale = useSharedValue(0);
  const opacity = useSharedValue(0);
  const angle = (index / 6) * Math.PI * 2;
  const translateX = useSharedValue(0);
  const translateY = useSharedValue(0);

  useEffect(() => {
    const distance = 20 + Math.random() * 15;
    scale.value = withDelay(delay, withSequence(
      withSpring(1, { damping: 8, stiffness: 300 }),
      withDelay(400, withTiming(0, { duration: 300 }))
    ));
    opacity.value = withDelay(delay, withSequence(
      withTiming(1, { duration: 150 }),
      withDelay(400, withTiming(0, { duration: 300 }))
    ));
    translateX.value = withDelay(delay, withTiming(Math.cos(angle) * distance, { duration: 600 }));
    translateY.value = withDelay(delay, withTiming(Math.sin(angle) * distance, { duration: 600 }));
  }, []);

  const style = useAnimatedStyle(() => ({
    position: 'absolute' as const,
    transform: [
      { translateX: translateX.value },
      { translateY: translateY.value },
      { scale: scale.value },
    ],
    opacity: opacity.value,
  }));

  return (
    <Animated.View style={style}>
      <Ionicons name="sparkles" size={10} color="#FBBF24" />
    </Animated.View>
  );
}

export default function XPGainToast({ amount, visible, onFinish }: Props) {
  const translateY = useSharedValue(20);
  const opacity = useSharedValue(0);
  const toastScale = useSharedValue(0.8);

  useEffect(() => {
    if (visible && amount !== 0) {
      // Haptic feedback
      if (Device.isDevice) {
        try { Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success); } catch {}
      }

      translateY.value = 20;
      opacity.value = 0;
      toastScale.value = 0.8;

      // Slide in + scale
      translateY.value = withTiming(0, { duration: 300, easing: Easing.out(Easing.back(1.5)) });
      opacity.value = withTiming(1, { duration: 250 });
      toastScale.value = withSpring(1, { damping: 10, stiffness: 200 });

      // Slide out after delay
      translateY.value = withDelay(2000, withTiming(-40, { duration: 400 }));
      opacity.value = withDelay(2000, withTiming(0, { duration: 400 }));

      const timer = setTimeout(onFinish, 2500);
      return () => clearTimeout(timer);
    }
  }, [visible, amount]);

  const toastStyle = useAnimatedStyle(() => ({
    transform: [
      { translateY: translateY.value },
      { scale: toastScale.value },
    ],
    opacity: opacity.value,
  }));

  if (!visible || amount === 0) return null;

  const isGain = amount > 0;
  const iconColor = isGain ? '#FBBF24' : '#EF4444';
  const sign = isGain ? '+' : '';
  const bgColor = isGain ? 'rgba(251,191,36,0.2)' : 'rgba(239,68,68,0.15)';
  const borderColor = isGain ? 'rgba(251,191,36,0.4)' : 'rgba(239,68,68,0.4)';

  return (
    <Animated.View style={[styles.toast, { backgroundColor: bgColor, borderColor }, toastStyle]}>
      {/* Sparkle particles for XP gains */}
      {isGain && (
        <View style={styles.sparkleContainer}>
          {Array.from({ length: 6 }).map((_, i) => (
            <Sparkle key={i} delay={100 + i * 60} index={i} />
          ))}
        </View>
      )}
      <Ionicons name={isGain ? 'flash' : 'alert-circle'} size={20} color={iconColor} />
      <Text style={[styles.text, { color: iconColor }]}>
        {sign}{amount} XP
      </Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  toast: {
    position: 'absolute',
    top: 100,
    alignSelf: 'center',
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    paddingHorizontal: 22,
    paddingVertical: 12,
    borderRadius: 24,
    zIndex: 10000,
  },
  sparkleContainer: {
    position: 'absolute',
    left: '50%',
    top: '50%',
    width: 0,
    height: 0,
    alignItems: 'center',
    justifyContent: 'center',
  },
  text: { fontWeight: 'bold', fontSize: 20, marginLeft: 8, letterSpacing: 0.5 },
});
