import React from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { useRoute } from '@react-navigation/native';

export default function StockScoreDetail() {
  const route = useRoute();
  const { stock } = route.params || {};

  if (!stock) {
    return <View style={styles.container}><Text>No stock data found.</Text></View>;
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.header}>{stock.name}</Text>
      <Text style={styles.symbol}>{stock.symbol}</Text>
      <View style={styles.scoreCard}>
        <Text style={styles.scoreLabel}>ShareQuest Score:</Text>
        <Text style={styles.scoreValue}>{typeof stock.aiert_score?.score === 'number' ? stock.aiert_score.score.toFixed(1) : '-'}</Text>
      </View>
      <View style={styles.section}>
        <Text style={styles.sectionHeader}>Score Breakdown</Text>
        <Text>Technical: {typeof stock.aiert_score?.technical === 'number' ? stock.aiert_score.technical.toFixed(1) : '-'}</Text>
        <Text>Fundamental: {typeof stock.aiert_score?.fundamental === 'number' ? stock.aiert_score.fundamental.toFixed(1) : '-'}</Text>
        <Text>Performance: {typeof stock.aiert_score?.performance === 'number' ? stock.aiert_score.performance.toFixed(1) : '-'}</Text>
        <Text>Liquidity: {typeof stock.aiert_score?.liquidity === 'number' ? stock.aiert_score.liquidity.toFixed(1) : '-'}</Text>
      </View>
      <View style={styles.section}>
        <Text style={styles.sectionHeader}>Fundamentals</Text>
        <Text>P/E: {typeof stock.fundamentals?.pe === 'number' ? stock.fundamentals.pe.toFixed(2) : '-'}</Text>
        <Text>P/B: {typeof stock.fundamentals?.pb === 'number' ? stock.fundamentals.pb.toFixed(2) : '-'}</Text>
        <Text>ROE: {typeof stock.fundamentals?.roe === 'number' ? stock.fundamentals.roe.toFixed(2) : '-'}</Text>
        <Text>ROA: {typeof stock.fundamentals?.roa === 'number' ? stock.fundamentals.roa.toFixed(2) : '-'}</Text>
        <Text>Debt/Equity: {typeof stock.fundamentals?.debtEquity === 'number' ? stock.fundamentals.debtEquity.toFixed(2) : '-'}</Text>
        <Text>Profit Margin: {typeof stock.fundamentals?.profitMargin === 'number' ? stock.fundamentals.profitMargin.toFixed(2) : '-'}</Text>
        <Text>Gross Margin: {typeof stock.fundamentals?.grossMargin === 'number' ? stock.fundamentals.grossMargin.toFixed(2) : '-'}</Text>
        <Text>Current Ratio: {typeof stock.fundamentals?.currentRatio === 'number' ? stock.fundamentals.currentRatio.toFixed(2) : '-'}</Text>
        <Text>Dividend Yield: {typeof stock.fundamentals?.dividendYield === 'number' ? stock.fundamentals.dividendYield.toFixed(2) : '-'}</Text>
        <Text>EPS Growth: {typeof stock.fundamentals?.epsGrowth === 'number' ? stock.fundamentals.epsGrowth.toFixed(2) : '-'}</Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 24,
    backgroundColor: '#0f172a',
    flexGrow: 1,
  },
  header: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 8,
    textAlign: 'center',
  },
  symbol: {
    fontSize: 18,
    color: '#a3a3a3',
    marginBottom: 16,
    textAlign: 'center',
  },
  scoreCard: {
    backgroundColor: '#2563eb',
    borderRadius: 16,
    padding: 16,
    marginBottom: 16,
    alignItems: 'center',
  },
  scoreLabel: {
    color: '#fff',
    fontSize: 16,
    marginBottom: 4,
  },
  scoreValue: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 24,
  },
  section: {
    marginBottom: 20,
  },
  sectionHeader: {
    color: '#60a5fa',
    fontWeight: 'bold',
    fontSize: 18,
    marginBottom: 8,
  },
});
