import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

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
  };
}

interface Props {
  stockData: StockData;
  onRefresh: () => void;
  refreshing: boolean;
}

function TableRow({ label, value, valueColor, isLast }: { label: string; value: string; valueColor?: string; isLast?: boolean }) {
  return (
    <View style={[tableStyles.row, isLast && tableStyles.rowLast]}>
      <Text style={tableStyles.label}>{label}</Text>
      <Text style={[tableStyles.value, valueColor ? { color: valueColor } : undefined]}>{value}</Text>
    </View>
  );
}

export default function LivePriceTab({ stockData, onRefresh, refreshing }: Props) {
  const formatPrice = (pence?: number) => {
    if (!pence && pence !== 0) return '--';
    return `${pence.toFixed(2)}p`;
  };

  const quote = stockData.quote;
  const spread = quote.bid != null && quote.ask != null ? quote.ask - quote.bid : null;
  const spreadPercent = spread != null && quote.price ? (spread / quote.price) * 100 : null;
  const isUp = quote.change >= 0;

  return (
    <View style={styles.container}>
      {/* Refresh Button */}
      <TouchableOpacity style={styles.refreshButton} onPress={onRefresh} disabled={refreshing}>
        {refreshing ? (
          <ActivityIndicator size="small" color="#3B82F6" />
        ) : (
          <Ionicons name="refresh" size={18} color="#3B82F6" />
        )}
        <Text style={styles.refreshText}>
          {refreshing ? 'Refreshing...' : 'Refresh Prices'}
        </Text>
      </TouchableOpacity>

      {/* Bid/Ask/Spread - Bold yellow strip */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Bid / Ask / Spread</Text>
        <View style={styles.bidAskCard}>
          <View style={styles.bidAskRow}>
            <View style={styles.bidAskItem}>
              <Text style={styles.bidAskLabel}>BID</Text>
              <Text style={styles.bidAskValue}>
                {quote.bid != null ? `${quote.bid.toFixed(2)}p` : '--'}
              </Text>
            </View>
            <View style={styles.bidAskItem}>
              <Text style={styles.bidAskLabel}>SPREAD</Text>
              <Text style={styles.bidAskValue}>
                {spread != null ? `${spread.toFixed(2)}p` : '--'}
              </Text>
              {spreadPercent != null && (
                <Text style={styles.bidAskSub}>({spreadPercent.toFixed(2)}%)</Text>
              )}
            </View>
            <View style={styles.bidAskItem}>
              <Text style={styles.bidAskLabel}>ASK</Text>
              <Text style={styles.bidAskValue}>
                {quote.ask != null ? `${quote.ask.toFixed(2)}p` : '--'}
              </Text>
            </View>
          </View>
        </View>
      </View>

      {/* Today's Range */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Today's Range</Text>
        <View style={styles.rangeCard}>
          <View style={styles.rangeLabels}>
            <View>
              <Text style={styles.rangeSubLabel}>Low</Text>
              <Text style={styles.rangeLowValue}>{formatPrice(quote.dayLow)}</Text>
            </View>
            <View style={{ alignItems: 'flex-end' }}>
              <Text style={styles.rangeSubLabel}>High</Text>
              <Text style={styles.rangeHighValue}>{formatPrice(quote.dayHigh)}</Text>
            </View>
          </View>
          <View style={styles.rangeBar}>
            <View style={styles.rangeTrack}>
              {quote.dayLow && quote.dayHigh && quote.price && (
                <View
                  style={[
                    styles.rangeIndicator,
                    {
                      left: `${Math.min(100, Math.max(0,
                        ((quote.price - quote.dayLow) / (quote.dayHigh - quote.dayLow)) * 100
                      ))}%`,
                    },
                  ]}
                />
              )}
            </View>
          </View>
        </View>
      </View>

      {/* Price Details Table */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Price Details</Text>
        <View style={tableStyles.table}>
          <TableRow label="Current Price" value={formatPrice(quote.price)} />
          <TableRow label="Previous Close" value={formatPrice(quote.previousClose)} />
          <TableRow
            label="Change"
            value={`${isUp ? '+' : ''}${quote.change.toFixed(2)}p (${isUp ? '+' : ''}${quote.changePercent.toFixed(2)}%)`}
            valueColor={isUp ? '#60A5FA' : '#F87171'}
          />
          <TableRow label="Day High" value={formatPrice(quote.dayHigh)} />
          <TableRow label="Day Low" value={formatPrice(quote.dayLow)} />
          <TableRow
            label="Volume"
            value={quote.volume ? quote.volume.toLocaleString() : '--'}
            isLast
          />
        </View>
      </View>

      {/* Market Status */}
      <View style={styles.marketStatus}>
        <Ionicons name="time-outline" size={16} color="#6B7280" />
        <Text style={styles.marketStatusText}>
          Prices update during market hours (8:00 - 16:30 UK)
        </Text>
      </View>
    </View>
  );
}

const tableStyles = StyleSheet.create({
  table: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 14,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.2)',
  },
  rowLast: {
    borderBottomWidth: 0,
  },
  label: {
    color: '#9CA3AF',
    fontSize: 13,
    fontWeight: '500',
  },
  value: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
});

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
  refreshButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(59, 130, 246, 0.1)',
    borderRadius: 10,
    padding: 10,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: 'rgba(59, 130, 246, 0.2)',
  },
  refreshText: {
    color: '#3B82F6',
    fontSize: 13,
    fontWeight: '600',
    marginLeft: 6,
  },
  // Bid/Ask card
  bidAskCard: {
    backgroundColor: '#FFD600',
    borderRadius: 12,
    padding: 14,
  },
  bidAskRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  bidAskItem: {
    flex: 1,
    alignItems: 'center',
  },
  bidAskLabel: {
    color: '#111',
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: 2,
  },
  bidAskValue: {
    color: '#111',
    fontSize: 16,
    fontWeight: '900',
  },
  bidAskSub: {
    color: '#333',
    fontSize: 11,
    fontWeight: '700',
    marginTop: 1,
  },
  // Range
  rangeCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 14,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  rangeLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  rangeSubLabel: { color: '#6B7280', fontSize: 10, fontWeight: '600', textTransform: 'uppercase', marginBottom: 2 },
  rangeLowValue: { color: '#F87171', fontSize: 16, fontWeight: 'bold' },
  rangeHighValue: { color: '#34D399', fontSize: 16, fontWeight: 'bold' },
  rangeBar: {
    height: 6,
    backgroundColor: 'rgba(75, 85, 99, 0.4)',
    borderRadius: 3,
    overflow: 'hidden',
  },
  rangeTrack: {
    height: '100%',
    borderRadius: 3,
    backgroundColor: 'rgba(59, 130, 246, 0.3)',
    position: 'relative',
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
  marketStatus: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.3)',
    borderRadius: 10,
    padding: 10,
    marginTop: 4,
  },
  marketStatusText: {
    color: '#6B7280',
    fontSize: 11,
    marginLeft: 6,
  },
});
