import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { MaterialCommunityIcons } from '@expo/vector-icons';

export default function OnboardingPortfolio() {
  const router = useRouter();
  const params = useLocalSearchParams();

  // Parse holdings from params
  let holdings: Array<{ symbol: string; name: string; amount: string; price: string }> = [];
  if (params.holdings) {
    try {
      holdings = JSON.parse(params.holdings as string);
    } catch {
      holdings = [];
    }
  } else if (params.symbol && params.name && params.amount && params.price) {
    holdings = [{ symbol: params.symbol as string, name: params.name as string, amount: params.amount as string, price: params.price as string }];
  }

  const hasMultipleStocks = holdings.length >= 2;

  // Animated holdings with rising prices
  const [animatedHoldings, setAnimatedHoldings] = useState(
    holdings.map(h => ({
      ...h,
      currentPrice: Number(h.price),
      value: Number(h.amount) * Number(h.price),
    }))
  );
  const [baseXp, setBaseXp] = useState(0); // XP from buys (loaded from storage)
  const [riseXp, setRiseXp] = useState(0); // XP earned from price rises this round
  const [animating, setAnimating] = useState(true);
  const [canContinue, setCanContinue] = useState(false);
  // XP toast state removed

  // Sell flow state
  const [phase, setPhase] = useState<'rising' | 'action' | 'selling' | 'sold'>('rising');
  const [sellProfit, setSellProfit] = useState(0);

  // Load accumulated XP from storage (includes all buy XP so far)
  useEffect(() => {
    (async () => {
      try {
        const pending = await AsyncStorage.getItem('pending_xp');
        if (pending) {
          setBaseXp(parseInt(pending, 10));
        }
      } catch {}
    })();
  }, []);

  const totalXp = baseXp + riseXp;

  // Animate all holdings' prices rising ~5%
  useEffect(() => {
    let frame = 0;
    const maxFrames = 60;
    let xpFromRise = 0;
    function animate() {
      frame++;
      const t = Math.min(frame / maxFrames, 1);
      let frameXp = 0;
      const newAnimated = holdings.map(h => {
        const priceStart = Number(h.price);
        const priceEnd = priceStart * 1.05;
        const newPrice = priceStart + (priceEnd - priceStart) * t;
        const newValue = Number(h.amount) * newPrice;
        frameXp += Math.round((newPrice - priceStart) * 100);
        return {
          ...h,
          currentPrice: newPrice,
          value: newValue,
        };
      });
      setAnimatedHoldings(newAnimated);
      setRiseXp(frameXp);
      xpFromRise = frameXp;
      if (frame < maxFrames) {
        requestAnimationFrame(animate);
      } else {
        setAnimating(false);
        // Save accumulated XP (base + rise)
        const newTotal = baseXp + xpFromRise;
        AsyncStorage.setItem('pending_xp', newTotal.toString()).catch(() => {});
        // XP toast removed
        setTimeout(() => {
          setCanContinue(true);
          setPhase('action');
        }, 1000);
      }
    }
    if (baseXp > 0 || holdings.length === 1) {
      // Start animation once baseXp is loaded (or on first trade where it might be 0 briefly)
      animate();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [baseXp]);

  const [buyDisabled, setBuyDisabled] = useState(false);
  const handleBuyAnother = () => {
    if (buyDisabled) return;
    setBuyDisabled(true);
    router.replace({
      pathname: '/first-trade',
      params: {
        purchased: holdings.map(h => h.symbol),
        holdings: JSON.stringify(holdings),
      },
    });
  };

  const [sellDisabled, setSellDisabled] = useState(false);
  const handleSell = (h: typeof animatedHoldings[0]) => {
    if (sellDisabled) return;
    setSellDisabled(true);
    const profit = (h.currentPrice - Number(h.price)) * Number(h.amount);
    setSellProfit(profit);
    setPhase('selling');

    // Award 50 XP for first sell
    const sellXp = 50;
    const newTotal = totalXp + sellXp;
    setRiseXp(riseXp + sellXp);
    AsyncStorage.setItem('pending_xp', newTotal.toString()).catch(() => {});

    setTimeout(() => {
      setPhase('sold');
    }, 1500);
  };

  const [continueDisabled, setContinueDisabled] = useState(false);
  const handleContinueToApp = async () => {
    if (continueDisabled) return;
    setContinueDisabled(true);
    // Save XP before navigating
    let xpToSave = baseXp + riseXp;
    if (phase === 'sold') {
      // Add sell XP if on sell complete screen
      xpToSave += 50;
    }
    try {
      await AsyncStorage.setItem('pending_xp', xpToSave.toString());
      // Persist XP to user profile for future use
      await AsyncStorage.setItem('user_onboarding_xp', xpToSave.toString());
    } catch {}
    router.replace('/onboarding-search');
  };

  // Sell in-progress screen
  if (phase === 'selling') {
    return (
      <View style={styles.centeredContainer}>
        <Text style={styles.sellSuccessTitle}>Selling your shares...</Text>
        <Text style={styles.sellSubtext}>Finding a buyer at the best price</Text>
      </View>
    );
  }

  // Sell complete screen
  if (phase === 'sold') {
    return (
      <View style={styles.centeredContainer}>
        <Text style={styles.sellSuccessTitle}>Sold!</Text>
        <Text style={styles.sellProfitText}>
          You made £{sellProfit.toFixed(2)} profit
        </Text>
        <Text style={styles.sellExplainer}>
          You bought low and sold high — that&apos;s how traders make money.
        </Text>
        <Text style={styles.xpAwardText}>+50 XP</Text>
        <View style={styles.xpBarContainer}>
          {/* XP bar text removed; now handled in xpBottomArea */}
        </View>
        <Text style={styles.completedText}>
          Now let&apos;s see how to search for stocks.
        </Text>
        <TouchableOpacity style={styles.button} onPress={handleContinueToApp} disabled={continueDisabled}>
          <Text style={styles.buttonText}>Continue</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.outerContainer}>
      <ScrollView
        style={styles.scrollArea}
        contentContainerStyle={styles.container}
      >
        <View style={styles.summaryCard}>
          <Text style={styles.summaryTitle}>Practice Portfolio</Text>
          <View style={styles.summaryRow}>
            <Text style={styles.summaryLabel}>Total Value</Text>
            <Text style={styles.summaryValue}>
              £{animatedHoldings.reduce((sum, h) => sum + h.value, 0).toFixed(2)}
            </Text>
          </View>
          <View style={styles.summaryRow}>
            <Text style={styles.summaryLabel}>Return</Text>
            <Text style={[styles.summaryValue, { color: '#10B981' }]}>
              +£{animatedHoldings.reduce((sum, h) => sum + (h.value - Number(h.amount) * Number(h.price)), 0).toFixed(2)}
            </Text>
          </View>
        </View>

        {animatedHoldings.map(h => (
          <View style={styles.holdingCard} key={h.symbol}>
            <View style={styles.holdingHeader}>
              <View style={{ flex: 1 }}>
                <Text style={styles.holdingName}>{h.name}</Text>
                <Text style={styles.holdingSymbol}>{h.symbol}</Text>
              </View>
              <Text style={styles.holdingPrice}>£{h.currentPrice.toFixed(2)}</Text>
            </View>
            <View style={styles.holdingStats}>
              <View style={styles.statItem}>
                <Text style={styles.statLabel}>Shares</Text>
                <Text style={styles.statValue}>{h.amount}</Text>
              </View>
              <View style={styles.statItem}>
                <Text style={styles.statLabel}>Avg Cost</Text>
                <Text style={styles.statValue}>£{Number(h.price).toFixed(2)}</Text>
              </View>
              <View style={styles.statItem}>
                <Text style={styles.statLabel}>Value</Text>
                <Text style={styles.statValue}>£{h.value.toFixed(2)}</Text>
              </View>
              <View style={styles.statItem}>
                <Text style={styles.statLabel}>P&L</Text>
                <Text style={[styles.statValue, { color: '#10B981' }]}>
                  +£{(h.value - Number(h.amount) * Number(h.price)).toFixed(2)}
                </Text>
              </View>
            </View>
            {hasMultipleStocks && phase === 'action' && (
              <TouchableOpacity style={styles.sellButton} onPress={() => handleSell(h)}>
                <Text style={styles.sellButtonText}>Sell</Text>
              </TouchableOpacity>
            )}
          </View>
        ))}

        <Text style={styles.rising}>{animating ? 'Price rising...' : ' '}</Text>

        {canContinue && !hasMultipleStocks && (
          <TouchableOpacity style={styles.button} onPress={handleBuyAnother} disabled={buyDisabled}>
            <Text style={styles.buttonText}>Buy Another Stock</Text>
          </TouchableOpacity>
        )}
        {canContinue && hasMultipleStocks && phase === 'action' && (
          <View style={styles.sellPromptButton}>
            <Text style={styles.sellPromptText}>
              Tap a <Text style={{ fontWeight: 'bold' }}>Sell</Text> button above to bank your profit
            </Text>
          </View>
        )}
      </ScrollView>
      <View style={styles.xpBottom}>
        <View style={styles.xpBarRow}>
          <MaterialCommunityIcons name="flash" size={22} color="#ffe066" style={{ marginRight: 8 }} />
          <Text style={styles.xpLabelProminent}>XP</Text>
          <Text style={styles.xpValueProminent}>{totalXp}</Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  outerContainer: {
    flex: 1,
    backgroundColor: '#101c2c',
  },
  scrollArea: {
    flex: 1,
  },
  container: {
    flexGrow: 1,
    alignItems: 'center',
    justifyContent: 'flex-start',
    paddingHorizontal: 16,
    paddingTop: 50,
    paddingBottom: 6,
  },
  xpBottom: {
    alignItems: 'center',
    paddingBottom: 34,
    paddingTop: 8,
    backgroundColor: '#101c2c',
  },
  centeredContainer: {
    flex: 1,
    backgroundColor: '#101c2c',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  summaryCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 10,
    padding: 12,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.5)',
    marginBottom: 10,
    width: '100%',
    maxWidth: 340,
    alignSelf: 'center',
  },
  summaryTitle: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 4,
  },
  summaryLabel: {
    color: '#9CA3AF',
    fontSize: 12,
  },
  summaryValue: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '500',
    minWidth: 80,
    textAlign: 'right',
    fontVariant: ['tabular-nums'],
  },
  holdingCard: {
    backgroundColor: 'rgba(15, 23, 42, 0.8)',
    borderRadius: 10,
    padding: 10,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.5)',
    width: '100%',
    maxWidth: 340,
    alignSelf: 'center',
  },
  holdingHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  holdingName: {
    color: '#ffe066',
    fontSize: 14,
    fontWeight: 'bold',
  },
  holdingSymbol: {
    color: '#b0c4de',
    fontSize: 12,
    marginTop: 1,
  },
  holdingPrice: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
    minWidth: 70,
    textAlign: 'right',
    fontVariant: ['tabular-nums'],
  },
  holdingStats: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 4,
  },
  statItem: { alignItems: 'center', flex: 1 },
  statLabel: { color: '#9CA3AF', fontSize: 11 },
  statValue: { color: '#fff', fontSize: 12, fontWeight: '500', fontVariant: ['tabular-nums'] },
  sellButton: {
    backgroundColor: '#EF4444',
    borderRadius: 8,
    paddingVertical: 8,
    alignItems: 'center',
    marginTop: 8,
  },
  sellButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold',
  },
  sellPrompt: {
    color: '#b0c4de',
    fontSize: 15,
    textAlign: 'center',
    marginTop: 8,
    marginBottom: 16,
  },
  sellPromptButton: {
    backgroundColor: '#3B82F6',
    borderRadius: 8,
    paddingHorizontal: 16,
    paddingVertical: 10,
    alignItems: 'center',
    marginTop: 8,
    width: '100%',
    maxWidth: 340,
  },
    xpToastAbsolute: {
      position: 'absolute',
      bottom: 56,
      left: 0,
      right: 0,
      alignItems: 'center',
      zIndex: 20,
    },
  sellPromptText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
    textAlign: 'center',
  },
  sellSuccessTitle: {
    color: '#fff',
    fontSize: 26,
    fontWeight: 'bold',
    marginBottom: 12,
  },
  sellSubtext: {
    color: '#9CA3AF',
    fontSize: 15,
    marginTop: 4,
  },
  sellProfitText: {
    color: '#10B981',
    fontSize: 20,
    fontWeight: '600',
    marginBottom: 8,
  },
  sellExplainer: {
    color: '#9CA3AF',
    fontSize: 14,
    textAlign: 'center',
    marginTop: 4,
    marginBottom: 8,
  },
  xpAwardText: {
    color: '#ffe066',
    fontSize: 22,
    fontWeight: 'bold',
    marginTop: 12,
  },
  completedText: {
    color: '#b0c4de',
    fontSize: 15,
    textAlign: 'center',
    marginTop: 24,
    marginBottom: 24,
    lineHeight: 22,
  },
  xpBarContainer: {
    alignItems: 'center',
  },
  xpBarRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(251,191,36,0.10)',
    borderWidth: 1.5,
    borderColor: '#ffe066',
    borderRadius: 18,
    paddingHorizontal: 18,
    paddingVertical: 8,
  },
  xpLabelProminent: {
    color: '#ffe066',
    fontSize: 18,
    fontWeight: 'bold',
    marginRight: 6,
  },
  xpValueProminent: {
    color: '#ffe066',
    fontSize: 26,
    fontWeight: 'bold',
    marginLeft: 2,
  },
  rising: {
    color: '#4f8cff',
    fontSize: 14,
    marginBottom: 6,
    height: 20,
  },
  button: {
    backgroundColor: '#4f8cff',
    borderRadius: 8,
    paddingVertical: 10,
    paddingHorizontal: 28,
    alignItems: 'center',
    marginTop: 8,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
});
