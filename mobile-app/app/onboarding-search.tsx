import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, FlatList, ActivityIndicator } from 'react-native';
import { useRouter } from 'expo-router';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import apiService from '../src/services/api';

export default function OnboardingSearch() {
  const router = useRouter();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Array<{ symbol: string; name: string; companyname?: string; company_name?: string; currentPrice?: number; current_price?: number }>>([]);
  const [loading, setLoading] = useState(false);
  const [hasSearched, setHasSearched] = useState(false);
  const [selectedStock, setSelectedStock] = useState<{ symbol: string; name: string; companyname?: string; company_name?: string; currentPrice?: number; current_price?: number } | null>(null);
  const [foundNatWest, setFoundNatWest] = useState(false);
  const [xp, setXp] = useState(0);

  // Load carried forward XP from storage on mount
  useEffect(() => {
    (async () => {
      let xp = 0;
      try {
        let cachedXp = await AsyncStorage.getItem('user_xp');
        if (cachedXp) {
          xp = parseInt(cachedXp, 10);
        } else {
          // Fallback: fetch from backend
          const xpRes = await apiService.getGamificationProfile();
          if (xpRes.success && xpRes.data) {
            xp = xpRes.data.totalXP ?? xpRes.data.total_xp ?? 0;
            await AsyncStorage.setItem('user_xp', xp.toString());
            await AsyncStorage.setItem('pending_xp', xp.toString());
          }
        }
      } catch {}
      setXp(xp);
    })();
  }, []);

  // Debounced search
  useEffect(() => {
    if (query.length < 2) {
      setResults([]);
      setHasSearched(false);
      return;
    }
    const timer = setTimeout(async () => {
      setLoading(true);
      try {
        const res = await apiService.searchStocks(query.trim());
        if (res.success && res.data) {
          setResults(res.data.slice(0, 10));
        } else {
          setResults([]);
        }
      } catch {
        setResults([]);
      }
      setLoading(false);
      setHasSearched(true);
    }, 300);
    return () => clearTimeout(timer);
  }, [query]);

  const handleSelect = (stock: { symbol: string; name: string; companyname?: string; company_name?: string }) => {
    setSelectedStock(stock);
    setQuery('');
    setResults([]);
    // Check if the selected stock is NatWest
    const name = (stock.companyname || stock.company_name || stock.name || '').toLowerCase();
    const symbol = (stock.symbol || '').toUpperCase();
    if (name.includes('natwest') || symbol === 'NWG.L') {
      setFoundNatWest(true);
    }
  };

  const [continueDisabled, setContinueDisabled] = useState(false);
  // On XP gain or onboarding completion, POST to backend and update AsyncStorage
  const postXPToBackend = async (xp: number) => {
    try {
      await apiService.privateRequest('/mobile/gamification/xp', {
        method: 'POST',
        body: JSON.stringify({ xp }),
      });
      await AsyncStorage.setItem('pending_xp', xp.toString());
      await AsyncStorage.setItem('user_onboarding_xp', xp.toString());
      await AsyncStorage.setItem('user_xp', xp.toString());
    } catch {}
  };

  const handleContinue = async () => {
    if (continueDisabled) return;
    setContinueDisabled(true);
    let newXp = xp;
    if (foundNatWest) {
      newXp += 100;
      setXp(newXp);
      await postXPToBackend(newXp);
    }
    router.replace('/onboarding-sectors');
  };

  return (
    <View style={styles.outerContainer}>
      <View style={styles.content}>
        <Text style={styles.title}>Find NatWest Bank</Text>
        <Text style={styles.subtitle}>
          There are 100&apos;s of stocks to trade. Try searching for &quot;NatWest&quot; to find it.
        </Text>

        <View style={styles.searchContainer}>
          <MaterialCommunityIcons name="magnify" size={20} color="#9CA3AF" style={{ marginRight: 10 }} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search stocks..."
            placeholderTextColor="#6B7280"
            value={query}
            onChangeText={setQuery}
            autoCapitalize="none"
            autoCorrect={false}
            returnKeyType="done"
            autoFocus
          />
          {query.length > 0 && (
            <TouchableOpacity onPress={() => { setQuery(''); setResults([]); setSelectedStock(null); }}>
              <MaterialCommunityIcons name="close-circle" size={20} color="#6B7280" />
            </TouchableOpacity>
          )}
        </View>

        {loading && (
          <ActivityIndicator color="#3B82F6" style={{ marginTop: 16 }} />
        )}
        {!loading && results.length > 0 && (
          <FlatList
            data={results}
            keyExtractor={(item) => item.symbol}
            style={styles.resultsList}
            keyboardShouldPersistTaps="handled"
            renderItem={({ item }) => (
              <TouchableOpacity style={styles.resultItem} onPress={() => handleSelect(item)}>
                <View style={styles.resultIcon}>
                  <MaterialCommunityIcons name="trending-up" size={18} color="#3B82F6" />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.resultName}>{item.companyname || item.company_name || item.name}</Text>
                  <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                    <Text style={styles.resultSymbol}>{item.symbol}</Text>
                    {((item.currentPrice ?? item.current_price ?? 0) > 0) && (
                      <>
                        <Text style={styles.resultDot}> · </Text>
                        <Text style={styles.resultPrice}>{((item.currentPrice ?? item.current_price ?? 0) / 1).toFixed(1)}p</Text>
                      </>
                    )}
                  </View>
                </View>
              </TouchableOpacity>
            )}
          />
        )}
        {!loading && hasSearched && results.length === 0 && query.length >= 2 && (
          <Text style={styles.noResults}>No stocks found — try a different name</Text>
        )}

        {selectedStock && (
          <View style={[styles.selectedCard, foundNatWest && styles.selectedCardSuccess]}>
            <Text style={styles.selectedName}>{selectedStock.companyname || selectedStock.company_name || selectedStock.name}</Text>
            <Text style={styles.selectedSymbol}>{selectedStock.symbol}</Text>
            {((selectedStock?.currentPrice ?? selectedStock?.current_price ?? 0) > 0) && (
              <Text style={styles.selectedPrice}>
                {((selectedStock?.currentPrice ?? selectedStock?.current_price ?? 0) / 1).toFixed(1)}p
              </Text>
            )}
            {foundNatWest ? (
              <Text style={styles.xpAwardText}>+100 XP</Text>
            ) : (
              <Text style={styles.selectedHint}>
                That&apos;s not NatWest — keep searching!
              </Text>
            )}
          </View>
        )}

        {foundNatWest && (
          <TouchableOpacity style={styles.button} onPress={handleContinue} disabled={continueDisabled}>
            <Text style={styles.buttonText}>Continue</Text>
          </TouchableOpacity>
        )}
      </View>
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
  outerContainer: {
    flex: 1,
    backgroundColor: '#101c2c',
  },
  content: {
    flex: 1,
    paddingTop: 60,
    paddingHorizontal: 16,
    alignItems: 'center',
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
  title: {
    color: '#fff',
    fontSize: 22,
    fontWeight: 'bold',
    marginBottom: 8,
    textAlign: 'center',
  },
  subtitle: {
    color: '#b0c4de',
    fontSize: 15,
    marginBottom: 20,
    textAlign: 'center',
    lineHeight: 22,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#22304a',
    borderRadius: 12,
    paddingHorizontal: 14,
    paddingVertical: 12,
    width: '100%',
    maxWidth: 340,
  },
  searchInput: {
    flex: 1,
    fontSize: 16,
    color: '#fff',
  },
  resultsList: {
    width: '100%',
    maxWidth: 340,
    maxHeight: 280,
    marginTop: 8,
    backgroundColor: '#1a2a40',
    borderRadius: 12,
  },
  resultItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 14,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
  },
  resultIcon: {
    width: 36,
    height: 36,
    backgroundColor: 'rgba(59, 130, 246, 0.15)',
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  resultName: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
    marginBottom: 2,
  },
  resultSymbol: {
    color: '#9CA3AF',
    fontSize: 13,
  },
  resultDot: {
    color: '#6B7280',
    fontSize: 13,
  },
  resultPrice: {
    color: '#9CA3AF',
    fontSize: 13,
  },
  noResults: {
    color: '#9CA3AF',
    fontSize: 14,
    marginTop: 20,
    textAlign: 'center',
  },
  selectedCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.7)',
    borderRadius: 12,
    padding: 20,
    marginTop: 20,
    width: '100%',
    maxWidth: 340,
    borderWidth: 1,
    borderColor: '#3B82F6',
    alignItems: 'center',
  },
  selectedCardSuccess: {
    borderColor: '#10B981',
  },
  selectedName: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 4,
    textAlign: 'center',
  },
  selectedSymbol: {
    color: '#9CA3AF',
    fontSize: 14,
    marginBottom: 4,
  },
  selectedPrice: {
    color: '#10B981',
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 8,
  },
  selectedHint: {
    color: '#b0c4de',
    fontSize: 13,
    textAlign: 'center',
    marginTop: 4,
  },
  xpAwardText: {
    color: '#ffe066',
    fontSize: 22,
    fontWeight: 'bold',
    marginTop: 8,
  },
  penaltyText: {
    color: '#EF4444',
    fontSize: 18,
    fontWeight: 'bold',
    marginTop: 12,
    textAlign: 'center',
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
  button: {
    backgroundColor: '#4f8cff',
    borderRadius: 8,
    paddingVertical: 12,
    paddingHorizontal: 32,
    alignItems: 'center',
    marginTop: 18,
    width: '100%',
    maxWidth: 340,
  },
  buttonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
});
