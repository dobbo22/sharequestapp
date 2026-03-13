import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

interface StockData {
  symbol: string;
  companyName: string;
  quote: {
    price: number;
    change: number;
    changePercent: number;
    dayHigh: number;
    dayLow: number;
    volume: number;
    previousClose: number;
    bid?: number;
    ask?: number;
  };
  profile: {
    sector: string;
    industry?: string;
    country: string;
    marketCap?: number;
    description?: string;
  };
}

interface FundamentalsData {
  peRatio?: number;
  eps?: number;
  dividendYield?: number;
  marketCap?: number;
  beta?: number;
  fiftyTwoWeekHigh?: number;
  fiftyTwoWeekLow?: number;
}

interface Props {
  stockData: StockData;
  fundamentals: FundamentalsData | null;
}

function formatPrice(pence?: number) {
  if (!pence && pence !== 0) return '--';
  return `${pence.toFixed(2)}p`;
}

export default function OverviewTab({ stockData, fundamentals }: Props) {
  const quote = stockData.quote;

  return (
    <View style={styles.container}>
      {/* 52-Week Range */}
      {(fundamentals?.fiftyTwoWeekHigh || fundamentals?.fiftyTwoWeekLow) && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>52-Week Range</Text>
          <View style={styles.rangeCard}>
            <View style={styles.rangeLabels}>
              <View>
                <Text style={styles.rangeSubLabel}>Low</Text>
                <Text style={styles.rangeLow}>{formatPrice(fundamentals!.fiftyTwoWeekLow)}</Text>
              </View>
              <View style={{ alignItems: 'center' }}>
                <Text style={styles.rangeSubLabel}>Current</Text>
                <Text style={styles.rangeCurrent}>{formatPrice(quote.price)}</Text>
              </View>
              <View style={{ alignItems: 'flex-end' }}>
                <Text style={styles.rangeSubLabel}>High</Text>
                <Text style={styles.rangeHigh}>{formatPrice(fundamentals!.fiftyTwoWeekHigh)}</Text>
              </View>
            </View>
            <View style={styles.rangeBar}>
              <View style={styles.rangeTrack} />
              {fundamentals!.fiftyTwoWeekLow != null && fundamentals!.fiftyTwoWeekHigh != null && (
                <View
                  style={[
                    styles.rangeIndicator,
                    {
                      left: `${Math.min(100, Math.max(0,
                        ((quote.price - fundamentals!.fiftyTwoWeekLow!) /
                        (fundamentals!.fiftyTwoWeekHigh! - fundamentals!.fiftyTwoWeekLow!)) * 100
                      ))}%`,
                    },
                  ]}
                />
              )}
            </View>
          </View>
        </View>
      )}

      {/* About */}
      {stockData.profile.description && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>About</Text>
          <View style={styles.aboutCard}>
            <Text style={styles.description}>{stockData.profile.description}</Text>
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  section: { marginBottom: 20 },
  sectionTitle: {
    color: '#9CA3AF',
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 8,
  },
  rangeCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  rangeLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  rangeSubLabel: { color: '#6B7280', fontSize: 10, fontWeight: '600', textTransform: 'uppercase', marginBottom: 2 },
  rangeLow: { color: '#F87171', fontSize: 14, fontWeight: 'bold' },
  rangeCurrent: { color: '#60A5FA', fontSize: 14, fontWeight: 'bold' },
  rangeHigh: { color: '#34D399', fontSize: 14, fontWeight: 'bold' },
  rangeBar: {
    height: 6,
    backgroundColor: 'rgba(75, 85, 99, 0.4)',
    borderRadius: 3,
    position: 'relative',
  },
  rangeTrack: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    borderRadius: 3,
  },
  rangeIndicator: {
    position: 'absolute',
    top: -5,
    width: 16,
    height: 16,
    backgroundColor: '#3B82F6',
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#FFFFFF',
    marginLeft: -8,
  },
  aboutCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 14,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  description: {
    color: '#D1D5DB',
    fontSize: 14,
    lineHeight: 20,
  },
});
