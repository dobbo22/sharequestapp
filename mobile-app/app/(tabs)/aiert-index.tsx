import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, Modal, Pressable } from 'react-native';
import ApiService from '../../src/services/api';
import { useEffect, useState } from 'react';
import { useNavigation } from '@react-navigation/native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';

export default function ShareQuestIndexScreen() {
  const [rankings, setRankings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [modalVisible, setModalVisible] = useState(false);
  const [selectedStock, setSelectedStock] = useState(null);

  useEffect(() => {
    ApiService.request('/mobile/aiert-index')
      .then(res => {
        if (res.success && Array.isArray(res.data.stocks)) {
          setRankings(res.data.stocks);
        } else {
          setError(res.error || 'Failed to load rankings');
        }
        setLoading(false);
      })
      .catch(err => {
        setError('Failed to load rankings');
        setLoading(false);
      });
  }, []);

  return (
    <SafeAreaView style={styles.safeArea}>
      <LinearGradient colors={["#0f172a", "#1e3a5f", "#581c87"]} style={StyleSheet.absoluteFillObject} />
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.header}>ShareQuest Index Rankings</Text>
        {loading && <ActivityIndicator size="large" color="#60a5fa" style={{marginTop: 32}} />}
        {error && <Text style={{color: '#EF4444', marginTop: 16}}>{error}</Text>}
        {!loading && !error && (
          <View>
            <View style={styles.listHeaderRow}>
              <Text style={styles.rankCol}>Rank</Text>
              <Text style={styles.nameCol}>Name</Text>
              <Text style={styles.scoreCol}>SQ Score</Text>
            </View>
            {rankings.map((stock, idx) => (
              <TouchableOpacity
                key={stock.symbol}
                style={styles.listRow}
                onPress={() => {
                  setSelectedStock(stock);
                  setModalVisible(true);
                }}
              >
                <View style={styles.rankCol}>
                  {idx === 0 ? <View style={styles.medalGold}><Text style={styles.medalText}>1</Text></View>
                    : idx === 1 ? <View style={styles.medalSilver}><Text style={styles.medalText}>2</Text></View>
                    : idx === 2 ? <View style={styles.medalBronze}><Text style={styles.medalText}>3</Text></View>
                    : <Text style={styles.rankText}>{idx + 1}</Text>}
                </View>
                <View style={styles.nameCol}>
                  <Text style={styles.stockName}>{stock.name}</Text>
                  <Text style={styles.stockSymbol}>{stock.symbol}</Text>
                </View>
                <View style={styles.scoreCol}>
                  <View style={styles.scorePill}>
                    <Text style={styles.scorePillText}>
                      {typeof stock.aiert_score?.score === 'number' ? stock.aiert_score.score.toFixed(1) : '-'}
                    </Text>
                  </View>
                </View>
              </TouchableOpacity>
            ))}
          </View>
        )}
      </ScrollView>
      {/* Stock detail modal */}
      <Modal
        visible={modalVisible}
        animationType="slide"
        transparent={true}
        onRequestClose={() => setModalVisible(false)}
      >
        <View style={styles.modalOverlay}>
          <SafeAreaView style={styles.modalContent}>
            {selectedStock ? (
              <ScrollView contentContainerStyle={styles.modalScroll}>
                <View style={styles.card}>
                  <Text style={styles.modalHeader}>{selectedStock.name}</Text>
                  <Text style={styles.modalSymbol}>{selectedStock.symbol}</Text>
                  <View style={styles.scoreCard}>
                    <Text style={styles.scoreLabel}>ShareQuest Score</Text>
                    <Text style={styles.scoreValue}>{typeof selectedStock.aiert_score?.score === 'number' ? selectedStock.aiert_score.score.toFixed(1) : '-'}</Text>
                  </View>
                  <View style={styles.tableSection}>
                    <Text style={styles.sectionHeader}>Score Breakdown</Text>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>Technical</Text><Text style={styles.tableCell}>{typeof selectedStock.aiert_score?.technical === 'number' ? selectedStock.aiert_score.technical.toFixed(1) : '-'}</Text></View>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>Fundamental</Text><Text style={styles.tableCell}>{typeof selectedStock.aiert_score?.fundamental === 'number' ? selectedStock.aiert_score.fundamental.toFixed(1) : '-'}</Text></View>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>Performance</Text><Text style={styles.tableCell}>{typeof selectedStock.aiert_score?.performance === 'number' ? selectedStock.aiert_score.performance.toFixed(1) : '-'}</Text></View>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>Liquidity</Text><Text style={styles.tableCell}>{typeof selectedStock.aiert_score?.liquidity === 'number' ? selectedStock.aiert_score.liquidity.toFixed(1) : '-'}</Text></View>
                  </View>
                  <View style={styles.tableSection}>
                    <Text style={styles.sectionHeader}>Fundamentals</Text>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>P/E</Text><Text style={styles.tableCell}>{typeof selectedStock.fundamentals?.pe === 'number' ? selectedStock.fundamentals.pe.toFixed(2) : '-'}</Text></View>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>P/B</Text><Text style={styles.tableCell}>{typeof selectedStock.fundamentals?.pb === 'number' ? selectedStock.fundamentals.pb.toFixed(2) : '-'}</Text></View>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>ROE</Text><Text style={styles.tableCell}>{typeof selectedStock.fundamentals?.roe === 'number' ? selectedStock.fundamentals.roe.toFixed(2) : '-'}</Text></View>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>ROA</Text><Text style={styles.tableCell}>{typeof selectedStock.fundamentals?.roa === 'number' ? selectedStock.fundamentals.roa.toFixed(2) : '-'}</Text></View>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>Debt/Equity</Text><Text style={styles.tableCell}>{typeof selectedStock.fundamentals?.debtEquity === 'number' ? selectedStock.fundamentals.debtEquity.toFixed(2) : '-'}</Text></View>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>Profit Margin</Text><Text style={styles.tableCell}>{typeof selectedStock.fundamentals?.profitMargin === 'number' ? selectedStock.fundamentals.profitMargin.toFixed(2) : '-'}</Text></View>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>Gross Margin</Text><Text style={styles.tableCell}>{typeof selectedStock.fundamentals?.grossMargin === 'number' ? selectedStock.fundamentals.grossMargin.toFixed(2) : '-'}</Text></View>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>Current Ratio</Text><Text style={styles.tableCell}>{typeof selectedStock.fundamentals?.currentRatio === 'number' ? selectedStock.fundamentals.currentRatio.toFixed(2) : '-'}</Text></View>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>Dividend Yield</Text><Text style={styles.tableCell}>{typeof selectedStock.fundamentals?.dividendYield === 'number' ? selectedStock.fundamentals.dividendYield.toFixed(2) : '-'}</Text></View>
                    <View style={styles.tableRow}><Text style={styles.tableCell}>EPS Growth</Text><Text style={styles.tableCell}>{typeof selectedStock.fundamentals?.epsGrowth === 'number' ? selectedStock.fundamentals.epsGrowth.toFixed(2) : '-'}</Text></View>
                  </View>
                  <Pressable style={styles.closeButton} onPress={() => setModalVisible(false)}>
                    <Text style={styles.closeButtonText}>Close</Text>
                  </Pressable>
                </View>
              </ScrollView>
            ) : (
              <Text>No stock data found.</Text>
            )}
          </SafeAreaView>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  listHeaderRow: {
    flexDirection: 'row',
    marginBottom: 8,
    paddingHorizontal: 4,
  },
  listRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#334155',
  },
  rankCol: {
    width: 50,
    alignItems: 'center',
    justifyContent: 'center',
  },
  rankText: {
    color: '#a3a3a3',
    fontWeight: 'bold',
    fontSize: 16,
    textAlign: 'center',
  },
  medalGold: {
    backgroundColor: '#FFD700',
    borderRadius: 20,
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
    marginVertical: 2,
  },
  medalSilver: {
    backgroundColor: '#C0C0C0',
    borderRadius: 20,
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
    marginVertical: 2,
  },
  medalBronze: {
    backgroundColor: '#CD7F32',
    borderRadius: 20,
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
    marginVertical: 2,
  },
  medalText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 16,
    textAlign: 'center',
  },
  nameCol: {
    flex: 1,
    paddingLeft: 8,
    color: '#fff',
    fontSize: 15,
  },
  scoreCol: {
    width: 80,
    alignItems: 'flex-end',
    justifyContent: 'center',
  },
  scorePill: {
    backgroundColor: '#2563eb',
    borderRadius: 16,
    paddingHorizontal: 14,
    paddingVertical: 6,
    alignItems: 'center',
    justifyContent: 'center',
  },
  scorePillText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 18,
  },
  safeArea: {
    flex: 1,
    backgroundColor: '#0f172a',
  },
  container: {
    padding: 24,
    alignItems: 'stretch',
  },
  header: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 24,
    textAlign: 'center',
  },
  tableHeader: {
    flexDirection: 'row',
    backgroundColor: '#334155',
    borderRadius: 8,
    paddingVertical: 8,
    marginBottom: 8,
  },
  tableHeaderCell: {
    flex: 1,
    color: '#a3a3a3',
    fontWeight: 'bold',
    fontSize: 16,
    textAlign: 'center',
  },
  tableRow: {
    flexDirection: 'row',
    backgroundColor: '#1e293b',
    borderRadius: 8,
    marginBottom: 8,
    paddingVertical: 12,
    paddingHorizontal: 8,
    alignItems: 'center',
  },
  stockName: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 16,
  },
  stockSymbol: {
    color: '#a3a3a3',
    fontSize: 13,
    marginTop: 2,
  },
  scoreCell: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  techScore: {
    color: '#60a5fa',
    fontWeight: 'bold',
    fontSize: 18,
  },
  fundScore: {
    color: '#34d399',
    fontWeight: 'bold',
    fontSize: 18,
  },
  scoreTooltip: {
    marginTop: 2,
    backgroundColor: '#334155',
    borderRadius: 6,
    padding: 4,
  },
  scoreTooltipText: {
    color: '#a3a3a3',
    fontSize: 11,
  },
  ytd: {
    fontWeight: 'bold',
    fontSize: 16,
  },
  ytdLabel: {
    color: '#a3a3a3',
    fontSize: 10,
    marginTop: 2,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: 'transparent',
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalScroll: {
    alignItems: 'center',
    paddingBottom: 24,
    minWidth: '100%',
  },
  card: {
    backgroundColor: '#1e293b',
    borderRadius: 24,
    padding: 24,
    width: '95%',
    maxWidth: 420,
    alignSelf: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 12,
    elevation: 8,
  },
  modalHeader: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 4,
    textAlign: 'center',
  },
  modalSymbol: {
    fontSize: 18,
    color: '#a3a3a3',
    marginBottom: 16,
    textAlign: 'center',
  },
  scoreCard: {
    backgroundColor: '#2563eb',
    borderRadius: 16,
    paddingVertical: 12,
    paddingHorizontal: 24,
    marginBottom: 24,
    alignItems: 'center',
  },
  scoreLabel: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 16,
    marginBottom: 4,
  },
  scoreValue: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 32,
  },
  tableSection: {
    marginBottom: 24,
  },
  sectionHeader: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 18,
    marginBottom: 8,
    marginTop: 8,
  },
  tableRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 6,
    borderBottomWidth: 1,
    borderBottomColor: '#334155',
  },
  tableCell: {
    color: '#fff',
    fontSize: 15,
    flex: 1,
    textAlign: 'left',
  },
  closeButton: {
    backgroundColor: '#2563eb',
    borderRadius: 12,
    paddingVertical: 10,
    paddingHorizontal: 32,
    marginTop: 16,
    alignSelf: 'center',
  },
  closeButtonText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 16,
  },
});
