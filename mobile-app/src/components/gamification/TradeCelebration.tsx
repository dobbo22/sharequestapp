import React, { useEffect, useMemo } from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withDelay,
  withSequence,
  Easing,
  interpolate,
} from 'react-native-reanimated';
import * as Haptics from 'expo-haptics';
import * as Device from 'expo-device';

const { width, height } = Dimensions.get('window');
const CONFETTI_COUNT = 40;
const COLORS = ['#FBBF24', '#3B82F6', '#10B981', '#EF4444', '#8B5CF6', '#EC4899', '#F97316', '#06B6D4'];

interface Props {
  visible: boolean;
  onFinish: () => void;
}

interface PieceConfig {
  startX: number;
  color: string;
  size: number;
  drift: number;
  rotEnd: number;
  delay: number;
  isCircle: boolean;
}

function ConfettiPiece({ config }: { config: PieceConfig }) {
  const progress = useSharedValue(0);

  useEffect(() => {
    progress.value = withDelay(
      config.delay,
      withTiming(1, { duration: 2200, easing: Easing.out(Easing.quad) })
    );
  }, []);

  const style = useAnimatedStyle(() => {
    const p = progress.value;
    return {
      position: 'absolute' as const,
      left: config.startX,
      top: 0,
      width: config.size,
      height: config.isCircle ? config.size : config.size * 0.5,
      backgroundColor: config.color,
      borderRadius: config.isCircle ? config.size / 2 : 2,
      opacity: interpolate(p, [0, 0.7, 1], [1, 0.8, 0]),
      transform: [
        { translateY: interpolate(p, [0, 1], [-30, height * 0.9]) },
        { translateX: interpolate(p, [0, 0.3, 0.7, 1], [0, config.drift * 0.5, config.drift, config.drift * 0.8]) },
        { rotate: `${config.rotEnd * p}deg` },
        { scale: interpolate(p, [0, 0.1, 0.5, 1], [0, 1.2, 1, 0.6]) },
      ],
    };
  });

  return <Animated.View style={style} />;
}

export default function TradeCelebration({ visible, onFinish }: Props) {
  // Flash overlay
  const flashOpacity = useSharedValue(0);

  const pieces = useMemo<PieceConfig[]>(() =>
    Array.from({ length: CONFETTI_COUNT }).map((_, i) => ({
      startX: Math.random() * width,
      color: COLORS[Math.floor(Math.random() * COLORS.length)],
      size: 5 + Math.random() * 9,
      drift: (Math.random() - 0.5) * 180,
      rotEnd: 360 + Math.random() * 540,
      delay: i * 40,
      isCircle: Math.random() > 0.6,
    })),
    [visible]
  );

  useEffect(() => {
    if (visible) {
      if (Device.isDevice) {
        try { Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success); } catch {}
      }

      // Screen flash
      flashOpacity.value = withSequence(
        withTiming(0.25, { duration: 100 }),
        withTiming(0, { duration: 300 })
      );

      const timer = setTimeout(onFinish, 2500);
      return () => clearTimeout(timer);
    }
  }, [visible]);

  const flashStyle = useAnimatedStyle(() => ({
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#FFFFFF',
    opacity: flashOpacity.value,
    zIndex: 10000,
    pointerEvents: 'none' as const,
  }));

  if (!visible) return null;

  return (
    <View style={styles.overlay} pointerEvents="none">
      <Animated.View style={flashStyle} />
      {pieces.map((config, i) => (
        <ConfettiPiece key={i} config={config} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  overlay: { ...StyleSheet.absoluteFillObject, zIndex: 9999 },
});
