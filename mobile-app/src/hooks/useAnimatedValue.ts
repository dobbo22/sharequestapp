import { useEffect } from 'react';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withSpring,
  withDelay,
  withSequence,
  withRepeat,
  Easing,
  interpolate,
  SharedValue,
  AnimatedStyle,
} from 'react-native-reanimated';

// Fade in on mount
export function useFadeIn(delay = 0, duration = 400) {
  const opacity = useSharedValue(0);

  useEffect(() => {
    opacity.value = withDelay(delay, withTiming(1, { duration }));
  }, []);

  const style = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  return { style, opacity };
}

// Slide up + fade in on mount
export function useSlideUp(delay = 0, distance = 20, duration = 400) {
  const opacity = useSharedValue(0);
  const translateY = useSharedValue(distance);

  useEffect(() => {
    opacity.value = withDelay(delay, withTiming(1, { duration }));
    translateY.value = withDelay(
      delay,
      withSpring(0, { damping: 15, stiffness: 150 })
    );
  }, []);

  const style = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ translateY: translateY.value }],
  }));

  return { style, opacity, translateY };
}

// Scale spring on mount
export function useScaleIn(delay = 0) {
  const scale = useSharedValue(0);

  useEffect(() => {
    scale.value = withDelay(
      delay,
      withSpring(1, { damping: 12, stiffness: 200 })
    );
  }, []);

  const style = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return { style, scale };
}

// Continuous pulse animation
export function usePulse(minScale = 0.95, maxScale = 1.05, duration = 1500) {
  const scale = useSharedValue(1);

  useEffect(() => {
    scale.value = withRepeat(
      withSequence(
        withTiming(maxScale, { duration: duration / 2, easing: Easing.inOut(Easing.ease) }),
        withTiming(minScale, { duration: duration / 2, easing: Easing.inOut(Easing.ease) })
      ),
      -1,
      true
    );
  }, []);

  const style = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return { style, scale };
}

// Animated number counter (counts from prev to next value)
export function useCountUp(targetValue: number, duration = 800) {
  const animatedValue = useSharedValue(0);

  useEffect(() => {
    animatedValue.value = withTiming(targetValue, {
      duration,
      easing: Easing.out(Easing.cubic),
    });
  }, [targetValue]);

  return animatedValue;
}

// Staggered list item animation
export function useStaggeredEntry(index: number, baseDelay = 50) {
  return useSlideUp(index * baseDelay, 15, 350);
}

// Shimmer effect (returns translateX for a gradient overlay)
export function useShimmer(width: number, duration = 2000) {
  const translateX = useSharedValue(-width);

  useEffect(() => {
    translateX.value = withRepeat(
      withTiming(width, { duration, easing: Easing.inOut(Easing.ease) }),
      -1,
      false
    );
  }, []);

  const style = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }],
  }));

  return { style, translateX };
}

// Progress bar animation
export function useProgressBar(progress: number, duration = 600) {
  const width = useSharedValue(0);

  useEffect(() => {
    width.value = withTiming(progress, {
      duration,
      easing: Easing.out(Easing.cubic),
    });
  }, [progress]);

  const style = useAnimatedStyle(() => ({
    width: `${Math.min(width.value, 100)}%` as any,
  }));

  return { style, width };
}
