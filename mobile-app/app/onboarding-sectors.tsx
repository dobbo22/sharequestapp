import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  ActivityIndicator,
  Dimensions,
  Animated,
} from 'react-native';
import { useRouter } from 'expo-router';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { PieChart } from 'react-native-chart-kit';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { apiService } from '../src/services/api';

const screenWidth = Dimensions.get('window').width;

const SECTOR_COLORS = [
  '#3B82F6', '#8B5CF6', '#EC4899', '#10B981', '#F59E0B',
  '#EF4444', '#06B6D4', '#6366F1', '#14B8A6', '#F97316',
  '#84CC16', '#A855F7', '#22D3EE', '#FB923C', '#4ADE80',
];

interface SectorData {
  sector: string;
  count: number;
}

interface SubsectorData {
  subsector: string;
  count: number;
  stocks: Array<{ symbol: string; companyname: string; listing_id: string | null }>;
}

export default function OnboardingSectors() {
  const router = useRouter();
  const [sectors, setSectors] = useState<SectorData[]>([]);
  const [subsectors, setSubsectors] = useState<SubsectorData[]>([]);
  const [selectedSector, setSelectedSector] = useState<string | null>(null);
  const [selectedSubsector, setSelectedSubsector] = useState<SubsectorData | null>(null);
  const [loading, setLoading] = useState(true);
  const [foundRR, setFoundRR] = useState(false);
  const [xp, setXp] = useState(0);
  const [showPenalty, setShowPenalty] = useState(false);
  const penaltyOpacity = useRef(new Animated.Value(0)).current;
  const penaltyTranslateY = useRef(new Animated.Value(0)).current;

  // Load accumulated XP
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

  // Fetch sectors on mount
  useEffect(() => {
    (async () => {
      try {
        const response = await apiService.request<any>('/stocks/sectors');
        if (response.success && response.data) {
          const sectorList = response.data.sectors || [];
          // Deduplicate by sector name (case-insensitive, trimmed)
          const seen = new Set();
          const list = sectorList
            .map((s: any) => ({
              sector: (s.sector || '').trim(),
              count: Number(s.stock_count ?? s.count ?? 0),
            }))
            .filter((s: any) => {
              const key = s.sector.toLowerCase();
              if (seen.has(key)) return false;
              seen.add(key);
              return true;
            });
          // Sort alphabetically for easier navigation
          list.sort((a: any, b: any) => a.sector.localeCompare(b.sector));
          setSectors(list);
        }
      } catch {}
      setLoading(false);
    })();
  }, []);

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

  // Deduct 1 XP for wrong selection with animation
  const penalizeWrong = async () => {
    const newXp = Math.max(0, xp - 1);
    setXp(newXp);
    await postXPToBackend(newXp);
    // Animate "-1 XP Oops!" floating up and fading out
    setShowPenalty(true);
    penaltyOpacity.setValue(1);
    penaltyTranslateY.setValue(0);
    Animated.parallel([
      Animated.timing(penaltyOpacity, {
        toValue: 0,
        duration: 1500,
        useNativeDriver: true,
      }),
      Animated.timing(penaltyTranslateY, {
        toValue: -40,
        duration: 1500,
        useNativeDriver: true,
      }),
    ]).start(() => setShowPenalty(false));
  };

  // Fetch subsectors for a sector
  const handleSectorSelect = async (sectorName: string) => {
    // Penalize wrong sector choice (Rolls-Royce is in Industrials)
    if (sectorName.toLowerCase() !== 'industrials') {
      await penalizeWrong();
    }
    setSelectedSector(sectorName);
    setSelectedSubsector(null);
    setLoading(true);
    try {
      const response = await apiService.request<any>(
        `/stocks/sectors?sector=${encodeURIComponent(sectorName)}`
      );
      if (response.success && response.data) {
        const subList = response.data.subsectors || [];
        const list = subList.map((s: any) => ({
          subsector: s.subsector,
          count: Number(s.stock_count ?? s.count ?? 0),
          stocks: s.stocks || [],
        }));
        // Sort alphabetically for easier navigation
        list.sort((a: any, b: any) => a.subsector.localeCompare(b.subsector));
        setSubsectors(list);
      }
    } catch {}
    setLoading(false);
  };

  // Handle subsector select - show stocks
  const handleSubsectorSelect = async (sub: SubsectorData) => {
    setSelectedSubsector(sub);
    // Re-fetch to get full stock list
    setLoading(true);
    try {
      const response = await apiService.request<any>(
        `/stocks/sectors?sector=${encodeURIComponent(selectedSector || '')}`
      );
      if (response.success && response.data && Array.isArray(response.data.subsectors)) {
        const match = (response.data.subsectors as any[]).find((s: any) => s.subsector === sub.subsector);
        if (match && Array.isArray(match.stocks)) {
          setSelectedSubsector({ ...sub, stocks: match.stocks });
        }
      }
    } catch {}
    setLoading(false);
  };

  // Handle stock tap - check if Rolls Royce
  const handleStockTap = async (stock: { symbol: string; companyname: string }) => {
    if (stock.symbol === 'RR.L' || stock.companyname.toLowerCase().includes('rolls')) {
      setFoundRR(true);
      const newXp = xp + 100;
      setXp(newXp);
      await postXPToBackend(newXp);
    } else {
      await penalizeWrong();
    }
  };

  const handleBack = () => {
    if (selectedSubsector) {
      setSelectedSubsector(null);
    } else if (selectedSector) {
      setSelectedSector(null);
      setSubsectors([]);
    }
  };

  const handleContinue = () => {
    router.replace('/welcome');
  };

  // Pie chart data
  const pieData = selectedSector && subsectors.length > 0
    ? subsectors.slice(0, 10).map((sub, i) => ({
        name: (sub.subsector.length > 15 ? sub.subsector.substring(0, 15) + '...' : sub.subsector),
        population: Number(sub.count || 0),
        color: SECTOR_COLORS[i % SECTOR_COLORS.length],
        legendFontColor: '#fff',
        legendFontSize: 13,
        legendFontWeight: 'bold',
      })).filter(s => Number.isFinite(s.population) && s.population > 0)
    : sectors.slice(0, 10).map((sector, i) => ({
        name: (sector.sector.length > 15 ? sector.sector.substring(0, 15) + '...' : sector.sector),
        population: Number(sector.count || 0),
        color: SECTOR_COLORS[i % SECTOR_COLORS.length],
        legendFontColor: '#fff',
        legendFontSize: 13,
        legendFontWeight: 'bold',
      })).filter(s => Number.isFinite(s.population) && s.population > 0);

  // Remove count from legend labels (PieChart uses 'name' for legend)
  // The legend will only show the sector/subsector name, not the count.

  // Success screen
  if (foundRR) {
    return (
      <View style={styles.centeredContainer}>
        <Text style={styles.successTitle}>You found Rolls-Royce!</Text>
        <Text style={styles.successSubtext}>RR.L - Industrials / Aerospace & Defense</Text>
        <Text style={styles.xpAwardText}>+100 XP</Text>
        <Text style={styles.completedText}>
          You now know how to browse stocks by sector.{'\n'}Time to create your account!
        </Text>
        <TouchableOpacity style={styles.continueButton} onPress={handleContinue}>
          <Text style={styles.continueButtonText}>Continue</Text>
        </TouchableOpacity>
        <View style={styles.xpBottomArea}>
          <View style={styles.xpBarContainer}>
            <View style={styles.xpBarRow}>
              <MaterialCommunityIcons name="flash" size={22} color="#ffe066" style={{ marginRight: 8 }} />
              <Text style={styles.xpLabelProminent}>XP</Text>
              <Text style={styles.xpValueProminent}>{xp}</Text>
            </View>
          </View>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Find Rolls-Royce</Text>
      <Text style={styles.hint}>
        {!selectedSector
          ? 'Hint: Look in the Industrials sector'
          : !selectedSubsector
          ? 'Hint: They make jet engines...'
          : 'Tap on Rolls-Royce when you see it!'}
      </Text>

      {/* Pie chart */}
      {pieData.length > 0 && !selectedSubsector && (
        <View style={styles.pieContainer}>
          <PieChart
            data={pieData}
            width={screenWidth - 40}
            height={160}
            chartConfig={{
              color: (opacity = 1) => `rgba(139, 92, 246, ${opacity})`,
            }}
            accessor="population"
            backgroundColor="transparent"
            paddingLeft="0"
            absolute
            hasLegend={true}
            // Remove count from legend by customizing legend labels if needed
            // The PieChart component will use 'name' only
          />
        </View>
      )}

      {/* Back button */}
      {(selectedSector || selectedSubsector) && (
        <TouchableOpacity style={styles.backButton} onPress={handleBack}>
          <MaterialCommunityIcons name="chevron-left" size={20} color="#8B5CF6" />
          <Text style={styles.backText}>
            {selectedSubsector ? selectedSector : 'All Sectors'}
          </Text>
        </TouchableOpacity>
      )}

      {loading ? (
        <ActivityIndicator color="#8B5CF6" size="large" style={{ marginTop: 32 }} />
      ) : selectedSubsector ? (
        /* Stock list */
        <ScrollView style={styles.listContainer} contentContainerStyle={styles.listContent}>
          {selectedSubsector.stocks.map(stock => {
            const isRR = stock.symbol === 'RR.L' || stock.companyname.toLowerCase().includes('rolls');
            return (
              <TouchableOpacity
                key={stock.symbol}
                style={[styles.stockCard, isRR && styles.stockCardHighlight]}
                onPress={() => handleStockTap(stock)}
              >
                <View>
                  <Text style={styles.stockName}>{stock.companyname}</Text>
                  <Text style={styles.stockSymbol}>{stock.symbol}</Text>
                </View>
                <MaterialCommunityIcons name="chevron-right" size={20} color="#6B7280" />
              </TouchableOpacity>
            );
          })}
        </ScrollView>
      ) : selectedSector ? (
        /* Subsector list */
        <ScrollView style={styles.listContainer} contentContainerStyle={styles.listContent}>
          {subsectors.map((sub, i) => (
            <TouchableOpacity
              key={sub.subsector}
              style={styles.sectorCard}
              onPress={() => handleSubsectorSelect(sub)}
            >
              <View style={styles.sectorCardLeft}>
                <View style={[styles.colorDot, { backgroundColor: SECTOR_COLORS[i % SECTOR_COLORS.length] }]} />
                <View>
                  <Text style={styles.sectorCardTitle}>{sub.subsector}</Text>
                </View>
              </View>
              <MaterialCommunityIcons name="chevron-right" size={20} color="#6B7280" />
            </TouchableOpacity>
          ))}
        </ScrollView>
      ) : (
        /* Sector list */
        <ScrollView style={styles.listContainer} contentContainerStyle={styles.listContent}>
          {sectors.map((sector, i) => (
            <TouchableOpacity
              key={sector.sector}
              style={styles.sectorCard}
              onPress={() => handleSectorSelect(sector.sector)}
            >
              <View style={styles.sectorCardLeft}>
                <View style={[styles.colorDot, { backgroundColor: SECTOR_COLORS[i % SECTOR_COLORS.length] }]} />
                <View>
                  <Text style={styles.sectorCardTitle}>{sector.sector}</Text>
                </View>
              </View>
              <MaterialCommunityIcons name="chevron-right" size={20} color="#6B7280" />
            </TouchableOpacity>
          ))}
        </ScrollView>
      )}

      {/* Penalty animation */}
      {showPenalty && (
        <Animated.Text
          style={[
            styles.penaltyText,
            { opacity: penaltyOpacity, transform: [{ translateY: penaltyTranslateY }] },
          ]}
        >
          -1 XP Oops!
        </Animated.Text>
      )}

      {/* XP bar fixed at bottom */}
      <View style={styles.xpBottomArea} pointerEvents="box-none">
        <View style={styles.xpBarContainer}>
          <View style={styles.xpBarRow}>
            <MaterialCommunityIcons name="flash" size={22} color="#ffe066" style={{ marginRight: 8 }} />
            <Text style={styles.xpLabelProminent}>XP</Text>
            <Text style={styles.xpValueProminent}>{xp}</Text>
          </View>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#101c2c',
    paddingTop: 60,
  },
  centeredContainer: {
    flex: 1,
    backgroundColor: '#101c2c',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  title: {
    color: '#fff',
    fontSize: 22,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 8,
  },
  hint: {
    color: '#ffe066',
    fontSize: 15,
    textAlign: 'center',
    marginBottom: 16,
    paddingHorizontal: 24,
  },
  pieContainer: {
    alignItems: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.3)',
    borderRadius: 16,
    marginHorizontal: 16,
    paddingVertical: 10,
    marginBottom: 12,
  },
  backButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 10,
    backgroundColor: 'rgba(139, 92, 246, 0.1)',
  },
  backText: {
    color: '#8B5CF6',
    fontSize: 14,
    fontWeight: '600',
    marginLeft: 4,
  },
  listContainer: {
    flex: 1,
  },
  listContent: {
    paddingHorizontal: 16,
    paddingBottom: 100,
  },
  sectorCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    paddingVertical: 10,
    paddingHorizontal: 12,
    marginBottom: 6,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    minHeight: 38,
  },
  sectorCardLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  colorDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 12,
  },
  sectorCardTitle: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
  },
  sectorCardCount: {
    color: '#6B7280',
    fontSize: 12,
    marginTop: 2,
  },
  stockCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    paddingVertical: 10,
    paddingHorizontal: 12,
    marginBottom: 6,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    minHeight: 38,
  },
  stockCardHighlight: {
    borderColor: '#ffe066',
    backgroundColor: 'rgba(255, 224, 102, 0.08)',
  },
  stockName: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
  },
  stockSymbol: {
    color: '#9CA3AF',
    fontSize: 13,
    marginTop: 2,
  },
  successTitle: {
    color: '#fff',
    fontSize: 26,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  successSubtext: {
    color: '#9CA3AF',
    fontSize: 16,
    marginBottom: 16,
  },
  xpAwardText: {
    color: '#ffe066',
    fontSize: 22,
    fontWeight: 'bold',
    marginTop: 12,
  },
  xpBar: {
    marginTop: 16,
    alignItems: 'center',
  },
  xpLabel: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  xpValue: {
    color: '#ffe066',
    fontSize: 22,
    fontWeight: 'bold',
  },
  completedText: {
    color: '#b0c4de',
    fontSize: 15,
    textAlign: 'center',
    marginTop: 24,
    marginBottom: 24,
    lineHeight: 22,
  },
  continueButton: {
    backgroundColor: '#4f8cff',
    borderRadius: 8,
    paddingVertical: 12,
    paddingHorizontal: 32,
    alignItems: 'center',
  },
  continueButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  penaltyText: {
    color: '#EF4444',
    fontSize: 18,
    fontWeight: 'bold',
    textAlign: 'center',
    position: 'absolute',
    bottom: 60,
    left: 0,
    right: 0,
  },
  xpBottomArea: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    alignItems: 'center',
    zIndex: 30,
    backgroundColor: '#101c2c',
    paddingTop: 12,
    paddingBottom: 24,
  },
  xpBarContainer: {
    alignItems: 'center',
    justifyContent: 'center',
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
    alignSelf: 'center',
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
});
