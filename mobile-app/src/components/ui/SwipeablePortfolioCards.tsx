import React, { useState, useRef, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Dimensions,
  NativeSyntheticEvent,
  NativeScrollEvent,
  TouchableOpacity,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { MaterialCommunityIcons, Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import Animated, { FadeInDown, FadeIn } from 'react-native-reanimated';
import { colors, spacing, radii, typography } from '../../lib/theme';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const CARD_PADDING = 40; // 20px padding on each side
const CARD_WIDTH = SCREEN_WIDTH - CARD_PADDING;

interface PortfolioCardData {
  type: 'default' | 'weekly' | 'monthly' | 'annual';
  label: string;
  emoji: string;
  gradientColors: [string, string];
  icon: keyof typeof MaterialCommunityIcons.glyphMap;
  cashBalance: number;
  totalValue: number;
  initialBalance: number;
  holdingsCount: number;
  darkText?: boolean;
}

interface Props {
  portfolios: PortfolioCardData[];
}

const formatCurrency = (pence: number, decimals = 0) => {
  const pounds = pence / 100;
  return new Intl.NumberFormat('en-GB', {
    style: 'currency',
    currency: 'GBP',
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(pounds);
};

export default function SwipeablePortfolioCards({ portfolios }: Props) {
  const [activeIndex, setActiveIndex] = useState(0);
  const scrollRef = useRef<ScrollView>(null);
  const router = useRouter();

  const onScroll = useCallback((e: NativeSyntheticEvent<NativeScrollEvent>) => {
    const offsetX = e.nativeEvent.contentOffset.x;
    const index = Math.round(offsetX / CARD_WIDTH);
    if (index !== activeIndex && index >= 0 && index < portfolios.length) {
      setActiveIndex(index);
    }
  }, [activeIndex, portfolios.length]);

  const goToCard = (index: number) => {
    scrollRef.current?.scrollTo({ x: index * CARD_WIDTH, animated: true });
    setActiveIndex(index);
  };

  if (portfolios.length === 0) return null;

  return (
    <Animated.View entering={FadeInDown.delay(150).duration(400)} style={styles.container}>
      <View style={styles.headerRow}>
        <Text style={styles.sectionTitle}>Your ShareQuests</Text>
        {portfolios.length > 1 && (
          <Text style={styles.swipeHint}>Swipe to switch</Text>
        )}
      </View>

      {/* Dot indicators */}
      {portfolios.length > 1 && (
        <View style={styles.dots}>
          {portfolios.map((_, i) => (
            <TouchableOpacity
              key={i}
              onPress={() => goToCard(i)}
              style={[styles.dot, i === activeIndex && styles.dotActive]}
            />
          ))}
        </View>
      )}

      {/* Swipeable cards */}
      <ScrollView
        ref={scrollRef}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onScroll={onScroll}
        scrollEventThrottle={16}
        decelerationRate="fast"
        snapToInterval={CARD_WIDTH}
        snapToAlignment="start"
        contentContainerStyle={{ paddingRight: 0 }}
      >
        {portfolios.map((portfolio, index) => {
          const totalValue = (portfolio.cashBalance || 0) + (portfolio.totalValue || 0);
          const initial = portfolio.initialBalance || 10000000; // 100k in pence default
          const returnPct = initial === 0 ? 0 : ((totalValue - initial) / initial) * 100;
          const isPositive = returnPct >= 0;

          const isDark = portfolio.darkText;
          const textColor = isDark ? '#1a1a1a' : '#FFFFFF';
          const subtextColor = isDark ? 'rgba(0,0,0,0.5)' : 'rgba(255,255,255,0.6)';
          const labelColor = isDark ? 'rgba(0,0,0,0.6)' : 'rgba(255,255,255,0.7)';

          return (
            <TouchableOpacity
              key={portfolio.type}
              activeOpacity={0.9}
              onPress={() => router.push('/(tabs)/portfolio')}
              style={[styles.cardWrapper, { width: CARD_WIDTH }]}
            >
              <LinearGradient
                colors={portfolio.gradientColors}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.card}
              >
                {/* Decorative circle */}
                <View style={[styles.decorCircle, { opacity: isDark ? 0.08 : 0.1 }]} />

                {/* Card header */}
                <View style={styles.cardHeader}>
                  <View style={styles.cardTitleRow}>
                    <View style={[styles.iconBadge, { backgroundColor: isDark ? 'rgba(0,0,0,0.1)' : 'rgba(255,255,255,0.2)' }]}>
                      <MaterialCommunityIcons name={portfolio.icon} size={20} color={textColor} />
                    </View>
                    <View>
                      <Text style={[styles.cardTitle, { color: textColor }]}>{portfolio.label} ShareQuest</Text>
                      <Text style={[styles.cardSubtitle, { color: subtextColor }]}>
                        {portfolio.holdingsCount} holding{portfolio.holdingsCount !== 1 ? 's' : ''}
                      </Text>
                    </View>
                  </View>
                  {portfolios.length > 1 && (
                    <View style={[styles.cardIndexBadge, { backgroundColor: isDark ? 'rgba(0,0,0,0.1)' : 'rgba(255,255,255,0.15)' }]}>
                      <Text style={[styles.cardIndex, { color: subtextColor }]}>{index + 1}/{portfolios.length}</Text>
                    </View>
                  )}
                </View>

                {/* Card stats */}
                <View style={styles.cardStats}>
                  <View>
                    <Text style={[styles.valueLabelText, { color: labelColor }]}>Total Value</Text>
                    <Text style={[styles.valueAmount, { color: textColor }]}>
                      {formatCurrency(totalValue, 2)}
                    </Text>
                    <View style={[styles.returnBadge, { backgroundColor: isPositive ? (isDark ? 'rgba(22,101,52,0.2)' : 'rgba(16,185,129,0.2)') : (isDark ? 'rgba(153,27,27,0.2)' : 'rgba(239,68,68,0.2)') }]}>
                      <Ionicons
                        name={isPositive ? 'trending-up' : 'trending-down'}
                        size={12}
                        color={isDark ? (isPositive ? '#166534' : '#991B1B') : (isPositive ? '#86EFAC' : '#FCA5A5')}
                      />
                      <Text style={[styles.returnPct, { color: isDark ? (isPositive ? '#166534' : '#991B1B') : (isPositive ? '#86EFAC' : '#FCA5A5') }]}>
                        {isPositive ? '+' : ''}{returnPct.toFixed(2)}%
                      </Text>
                    </View>
                  </View>
                  <View style={styles.cashSection}>
                    <Text style={[styles.cashLabel, { color: subtextColor }]}>Cash Available</Text>
                    <Text style={[styles.cashValue, { color: textColor }]}>{formatCurrency(portfolio.cashBalance, 0)}</Text>
                  </View>
                </View>
              </LinearGradient>
            </TouchableOpacity>
          );
        })}
      </ScrollView>
    </Animated.View>
  );
}

export type { PortfolioCardData };

const styles = StyleSheet.create({
  container: { marginTop: spacing.xl },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.md },
  sectionTitle: { color: colors.textPrimary, fontSize: typography.lg, fontWeight: 'bold' },
  swipeHint: { color: colors.textSecondary, fontSize: typography.sm },
  dots: { flexDirection: 'row', justifyContent: 'center', gap: 6, marginBottom: spacing.md },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: 'rgba(255,255,255,0.2)',
  },
  dotActive: {
    width: 24,
    backgroundColor: colors.textPrimary,
  },
  cardWrapper: { paddingRight: 0 },
  card: {
    borderRadius: radii.xl,
    padding: spacing.lg,
    minHeight: 170,
    overflow: 'hidden',
  },
  decorCircle: {
    position: 'absolute',
    right: -30,
    top: -30,
    width: 140,
    height: 140,
    borderRadius: 70,
    backgroundColor: '#FFFFFF',
  },
  cardHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: spacing.md },
  cardTitleRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  iconBadge: {
    width: 36,
    height: 36,
    borderRadius: radii.sm,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cardTitle: { color: '#FFFFFF', fontSize: 17, fontWeight: 'bold' },
  cardSubtitle: { color: 'rgba(255,255,255,0.6)', fontSize: typography.sm, marginTop: 2 },
  cardIndexBadge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: radii.sm,
  },
  cardIndex: { fontSize: typography.xs, fontWeight: '600' },
  cardStats: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end' },
  valueLabelText: { fontSize: typography.sm, marginBottom: 4 },
  valueAmount: { color: '#FFFFFF', fontSize: 26, fontWeight: 'bold' },
  returnBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    gap: 4,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: radii.sm,
    marginTop: 6,
  },
  returnPct: { fontSize: 13, fontWeight: '700' },
  cashSection: { alignItems: 'flex-end' },
  cashLabel: { color: 'rgba(255,255,255,0.6)', fontSize: typography.xs, marginBottom: 4 },
  cashValue: { color: '#FFFFFF', fontSize: typography.md, fontWeight: '600' },
});
