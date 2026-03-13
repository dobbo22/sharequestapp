import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, Image, ActivityIndicator, ScrollView } from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { MaterialCommunityIcons } from '@expo/vector-icons';

const STOCKS = [
  { symbol: 'TSCO.L', name: 'Tesco PLC', logo: require('../assets/tesco.png'), fixedPrice: 275.5 },
  { symbol: 'MKS.L', name: 'Marks & Spencer Group PLC', logo: require('../assets/mks.png'), fixedPrice: 245.2 },
  { symbol: 'SBRY.L', name: 'J Sainsbury PLC', logo: require('../assets/sainsburys.png'), fixedPrice: 267.8 },
];

export default function FirstTrade() {
  const router = useRouter();
  const params = useLocalSearchParams();

  // Parse previous holdings and purchased symbols from params
  let purchasedSymbols: string[] = [];
  let previousHoldings: Array<{ symbol: string; name: string; amount: string; price: string }> = [];
  if (params.purchased) {
    if (Array.isArray(params.purchased)) {
      purchasedSymbols = params.purchased as string[];
    } else {
      purchasedSymbols = [params.purchased as string];
    }
  }
  if (params.holdings) {
    try {
      previousHoldings = JSON.parse(params.holdings as string);
    } catch {
      previousHoldings = [];
    }
  }

  const isSecondTrade = purchasedSymbols.length > 0;
  const availableStocks = STOCKS.filter(stock => !purchasedSymbols.includes(stock.symbol));
  const [selected, setSelected] = useState(availableStocks[0] || STOCKS[0]);
  const [amount, setAmount] = useState('1000');
  const [price, setPrice] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
  const [xp, setXp] = useState(0);

  // Load accumulated XP from storage on mount
  useEffect(() => {
    (async () => {
      try {
        const pending = await AsyncStorage.getItem('pending_xp');
        if (pending) {
          const val = parseInt(pending, 10);
          setXp(val);
        }
      } catch {}
    })();
  }, []);

  // Use a fixed price for onboarding (convert pence to pounds)
  const fetchPrice = async (symbol: string) => {
    setLoading(true);
    setPrice(null);
    const stock = STOCKS.find(s => s.symbol === symbol);
    if (stock && typeof stock.fixedPrice === 'number') {
      setTimeout(() => {
        setPrice(stock.fixedPrice / 100);
        setLoading(false);
      }, 400);
    } else {
      setPrice(null);
      setLoading(false);
    }
  };

  // Fetch price for default stock on mount
  useEffect(() => {
    fetchPrice(selected.symbol);
  }, []);

  const handleSelect = (stock: typeof STOCKS[0]) => {
    setSelected(stock);
    setAmount('1000');
    fetchPrice(stock.symbol);
  };

  const [tradeDisabled, setTradeDisabled] = useState(false);
  const handleTrade = async () => {
    if (tradeDisabled) return;
    setTradeDisabled(true);
    // Add 100 XP for the buy
    const gain = 100;
    const newXp = xp + gain;
    setXp(newXp);
    try {
      await AsyncStorage.setItem('pending_xp', newXp.toString());
      // Persist XP to user profile for future use
      await AsyncStorage.setItem('user_onboarding_xp', newXp.toString());
    } catch {}

    // Build updated holdings array with all previous + this new one
    const newHolding = {
      symbol: selected.symbol,
      name: selected.name,
      amount,
      price: price ? price.toFixed(2) : '0',
    };
    const allHoldings = [...previousHoldings, newHolding];

    // Let the XP animation play, then navigate
    setTimeout(() => {
      router.replace({
        pathname: '/onboarding-portfolio',
        params: { holdings: JSON.stringify(allHoldings) },
      });
    }, 1200);
  };

  return (
    <View style={styles.container}>
      <ScrollView
        style={styles.content}
        contentContainerStyle={styles.contentInner}
        keyboardShouldPersistTaps="handled"
      >
        <Text style={styles.title}>
          {isSecondTrade ? 'Buy Another Stock!' : "Let's Go Shopping!"}
        </Text>
        <Text style={styles.subtitle}>
          {isSecondTrade
            ? 'Great trade! Now pick another supermarket to diversify your portfolio.'
            : 'Did you know you can buy shares in your favorite supermarket? Pick one below and make your first practice trade!'}
        </Text>
        <View style={styles.stockList}>
          {availableStocks.length === 0 ? (
            <Text style={{ color: '#fff', marginVertical: 24 }}>No more stocks to buy!</Text>
          ) : (
            availableStocks.map(stock => (
              <TouchableOpacity
                key={stock.symbol}
                style={[styles.stockItem, selected.symbol === stock.symbol && styles.selectedStock]}
                onPress={() => handleSelect(stock)}
              >
                <Image source={stock.logo} style={styles.stockLogo} alt={stock.name} />
                <Text style={styles.stockName}>{stock.name}</Text>
              </TouchableOpacity>
            ))
          )}
        </View>
        <View style={styles.priceRow}>
          <Text style={styles.priceLabel}>Current Price</Text>
          {loading ? (
            <ActivityIndicator color="#3B82F6" />
          ) : price !== null ? (
            <Text style={styles.priceDisplay}>{(price * 100).toFixed(0)}p</Text>
          ) : (
            <Text style={styles.priceDisplay}>-</Text>
          )}
        </View>
        <View style={styles.amountRow}>
          <Text style={styles.inputLabel}>Amount (shares)</Text>
          <TextInput
            style={styles.input}
            placeholder="1000"
            placeholderTextColor="#6B7280"
            keyboardType="numeric"
            returnKeyType="done"
            value={amount}
            onChangeText={setAmount}
          />
        </View>
        {price !== null && (
          <Text style={{ color: '#b0c4de', marginBottom: 16, marginTop: 8 }}>
            Total: <Text style={{ color: '#fff', fontWeight: 'bold' }}>£{(price * (parseInt(amount) || 0)).toFixed(2)}</Text>
          </Text>
        )}
        <TouchableOpacity
          style={[styles.button, (!amount || loading || price === null || tradeDisabled) && { opacity: 0.5 }]}
          onPress={handleTrade}
          disabled={!amount || loading || price === null || tradeDisabled}
        >
          <Text style={styles.buttonText}>{tradeDisabled ? 'Processing...' : 'Buy'}</Text>
        </TouchableOpacity>
      </ScrollView>
      <View style={styles.xpBottom}>
        <View style={styles.xpBarRow}>
          <MaterialCommunityIcons name="flash" size={22} color="#ffe066" style={{ marginRight: 8 }} />
          <Text style={styles.xpLabelProminent}>XP</Text>
          <Text style={styles.xpValueProminent}>{xp}</Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#101c2c',
  },
  content: {
    flex: 1,
  },
  contentInner: {
    alignItems: 'center',
    paddingTop: 50,
    paddingHorizontal: 16,
    paddingBottom: 10,
  },
  xpBottom: {
    alignItems: 'center',
    paddingBottom: 40,
    paddingTop: 12,
    backgroundColor: '#101c2c',
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
  title: {
    color: '#fff',
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 6,
    textAlign: 'center',
  },
  subtitle: {
    color: '#b0c4de',
    fontSize: 13,
    marginBottom: 12,
    textAlign: 'center',
  },
  stockList: {
    width: '100%',
    maxWidth: 340,
    marginBottom: 10,
  },
  stockItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#22304a',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    marginBottom: 8,
    width: '100%',
    borderWidth: 2,
    borderColor: 'transparent',
  },
  selectedStock: {
    borderColor: '#4f8cff',
    backgroundColor: '#2a3b5c',
  },
  stockLogo: {
    width: 34,
    height: 34,
    minWidth: 34,
    minHeight: 34,
    borderRadius: 7,
    marginRight: 10,
    backgroundColor: '#fff',
    resizeMode: 'contain',
    overflow: 'hidden',
  },
  stockName: {
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold',
    flex: 1,
    flexShrink: 1,
  },
  priceRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    width: '100%',
    maxWidth: 340,
    backgroundColor: '#22304a',
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginBottom: 8,
  },
  priceLabel: {
    color: '#b0c4de',
    fontSize: 14,
  },
  priceDisplay: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  amountRow: {
    width: '100%',
    maxWidth: 340,
    marginBottom: 4,
  },
  input: {
    backgroundColor: '#22304a',
    color: '#fff',
    borderRadius: 8,
    paddingHorizontal: 12,
    height: 38,
    fontSize: 15,
  },
  inputLabel: {
    color: '#b0c4de',
    fontSize: 12,
    marginBottom: 3,
    marginLeft: 2,
  },
  button: {
    backgroundColor: '#4f8cff',
    borderRadius: 8,
    paddingVertical: 12,
    alignItems: 'center',
    marginTop: 10,
    width: '100%',
    maxWidth: 340,
    opacity: 1,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
});