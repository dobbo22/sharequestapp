import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  Modal,
  KeyboardAvoidingView,
  Platform,
  Keyboard,
  InputAccessoryView,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { apiService } from '../../services/api';
import { PortfolioType, Holding } from '../../types';
import { validateTradeConcentration, calculateMaxSharesAllowed } from '../../services/portfolio-limits';

interface TradingWindow {
  type: 'market_open' | 'after_hours' | 'pre_market' | 'weekend_holiday';
  canTradeImmediately: boolean;
  canCreatePendingOrder: boolean;
  executionPrice: 'live' | 'close' | 'open';
  message: string;
}

interface QuickTradeModalProps {
  visible: boolean;
  onClose: () => void;
  symbol: string;
  companyName: string;
  price: number;
  defaultPortfolio?: PortfolioType;
}

export default function QuickTradeModal({ visible, onClose, symbol, companyName, price, defaultPortfolio = 'default' }: QuickTradeModalProps) {
  const [quantity, setQuantity] = useState('');
  const [tradeAction, setTradeAction] = useState<'buy' | 'sell'>('buy');
  const [selectedPortfolio, setSelectedPortfolio] = useState<PortfolioType>(defaultPortfolio);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [concentrationWarning, setConcentrationWarning] = useState<string | null>(null);
  const [maxSharesAllowed, setMaxSharesAllowed] = useState<number | null>(null);
  const [holdings, setHoldings] = useState<Holding[]>([]);
  const [cashBalance, setCashBalance] = useState<number>(10000000); // £100k default
  const [tradingWindow, setTradingWindow] = useState<TradingWindow | null>(null);
  const [tradeSuccess, setTradeSuccess] = useState<{ message: string; isPendingOrder?: boolean } | null>(null);

  useEffect(() => {
    if (!visible) return;
    setQuantity('');
    setError(null);
    setConcentrationWarning(null);
    setMaxSharesAllowed(null);
    setTradeAction('buy');
    setSelectedPortfolio(defaultPortfolio);
    setTradeSuccess(null);

    async function fetchData() {
      // Fetch portfolio
      try {
        const resp = await apiService.getPortfolio(selectedPortfolio);
        if (resp.success && resp.data) {
          setHoldings(resp.data.holdings || []);
          setCashBalance(resp.data.portfolio?.cashBalance || 10000000);
        }
      } catch (e) {
        setHoldings([]);
        setCashBalance(10000000);
      }

      // Fetch trading window status
      try {
        const windowResp = await apiService.getTradingWindow();
        if (windowResp.success && windowResp.data) {
          setTradingWindow(windowResp.data.tradingWindow);
        }
      } catch (e) {
        // Default to market open if we can't fetch
        setTradingWindow({
          type: 'market_open',
          canTradeImmediately: true,
          canCreatePendingOrder: false,
          executionPrice: 'live',
          message: 'Market is open.'
        });
      }
    }
    fetchData();
  }, [visible, selectedPortfolio, symbol]);

  useEffect(() => {
    if (!quantity || isNaN(Number(quantity)) || Number(quantity) <= 0) {
      setConcentrationWarning(null);
      setMaxSharesAllowed(null);
      return;
    }
    const qty = parseInt(quantity, 10);
    const result = validateTradeConcentration(
      selectedPortfolio,
      symbol,
      tradeAction,
      qty,
      price,
      cashBalance,
      holdings
    );
    setConcentrationWarning(result.warningMessage || null);
    setError(result.errorMessage || null);
    setMaxSharesAllowed(result.maxSharesAllowed !== Infinity ? result.maxSharesAllowed : null);
  }, [quantity, tradeAction, selectedPortfolio, holdings, cashBalance, price, symbol]);

  const handleTrade = async () => {
    if (!quantity || parseInt(quantity, 10) <= 0) {
      setError('Please enter a valid quantity');
      return;
    }
    if (error) return;
    setLoading(true);
    setError(null);
    setTradeSuccess(null);
    try {
      const response = await apiService.trade(
        selectedPortfolio,
        symbol,
        parseInt(quantity, 10),
        tradeAction,
        price
      );
      if (response.success) {
        const data = response.data;
        // Check if this was a pending order (pre-market/weekend)
        if (data?.isPendingOrder) {
          setTradeSuccess({
            message: data.message || 'Order scheduled for market open',
            isPendingOrder: true
          });
          setQuantity('');
          // Auto-close after showing success
          setTimeout(() => onClose(), 2500);
        } else {
          // Immediate trade success
          const msg = data?.isAfterHours
            ? `${tradeAction === 'buy' ? 'Bought' : 'Sold'} at closing price`
            : `${tradeAction === 'buy' ? 'Bought' : 'Sold'} successfully`;
          setTradeSuccess({ message: msg });
          setQuantity('');
          setTimeout(() => onClose(), 1500);
        }
      } else {
        setError(response.error || 'Trade failed');
      }
    } catch (err) {
      setError('An error occurred while processing your trade');
    } finally {
      setLoading(false);
    }
  };

  const quickAmounts = [10, 50, 100, 500].filter(a => !maxSharesAllowed || a <= maxSharesAllowed);
  const portfolioOptions: { id: PortfolioType; label: string; icon: string }[] = [
    { id: 'default', label: 'Practice', icon: 'school-outline' },
    { id: 'weekly', label: 'Weekly', icon: 'calendar-outline' },
    { id: 'monthly', label: 'Monthly', icon: 'calendar-number-outline' },
    { id: 'annual', label: 'Annual', icon: 'trophy-outline' },
  ];

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} style={styles.modalContainer}>
        <View style={styles.modalContent}>
          <TouchableOpacity style={styles.closeButton} onPress={onClose}>
            <Ionicons name="close" size={28} color="#9CA3AF" />
          </TouchableOpacity>
          <Text style={styles.title}>{companyName} ({symbol})</Text>

          {/* Trading Window Status Banner */}
          {tradingWindow && tradingWindow.type !== 'market_open' && (
            <View style={[
              styles.tradingWindowBanner,
              tradingWindow.type === 'after_hours' && styles.afterHoursBanner,
              (tradingWindow.type === 'pre_market' || tradingWindow.type === 'weekend_holiday') && styles.preMarketBanner
            ]}>
              <Ionicons
                name={tradingWindow.type === 'after_hours' ? 'moon-outline' : 'time-outline'}
                size={18}
                color={tradingWindow.type === 'after_hours' ? '#F59E0B' : '#3B82F6'}
              />
              <Text style={[
                styles.tradingWindowText,
                tradingWindow.type === 'after_hours' && styles.afterHoursText,
                (tradingWindow.type === 'pre_market' || tradingWindow.type === 'weekend_holiday') && styles.preMarketText
              ]}>
                {tradingWindow.message}
              </Text>
            </View>
          )}

          {/* Success Message */}
          {tradeSuccess && (
            <View style={[styles.successContainer, tradeSuccess.isPendingOrder && styles.pendingSuccessContainer]}>
              <Ionicons
                name={tradeSuccess.isPendingOrder ? 'time' : 'checkmark-circle'}
                size={20}
                color={tradeSuccess.isPendingOrder ? '#3B82F6' : '#10B981'}
              />
              <Text style={[styles.successText, tradeSuccess.isPendingOrder && styles.pendingSuccessText]}>
                {tradeSuccess.message}
              </Text>
            </View>
          )}

          <View style={styles.actionToggle}>
            <TouchableOpacity style={[styles.actionButton, tradeAction === 'buy' && styles.buyActive]} onPress={() => setTradeAction('buy')}>
              <Ionicons name="add-circle-outline" size={20} color={tradeAction === 'buy' ? '#FFFFFF' : '#10B981'} />
              <Text style={[styles.actionText, tradeAction === 'buy' && styles.actionTextActive]}>Buy</Text>
            </TouchableOpacity>
            <TouchableOpacity style={[styles.actionButton, tradeAction === 'sell' && styles.sellActive]} onPress={() => setTradeAction('sell')}>
              <Ionicons name="remove-circle-outline" size={20} color={tradeAction === 'sell' ? '#FFFFFF' : '#EF4444'} />
              <Text style={[styles.actionText, tradeAction === 'sell' && styles.actionTextActive]}>Sell</Text>
            </TouchableOpacity>
          </View>
          <View style={styles.section}>
            <Text style={styles.sectionLabel}>Select Portfolio</Text>
            <View style={styles.portfolioGrid}>
              {portfolioOptions.map((option) => (
                <TouchableOpacity
                  key={option.id}
                  style={[
                    styles.portfolioOption,
                    selectedPortfolio === option.id && styles.portfolioOptionActive,
                  ]}
                  onPress={() => setSelectedPortfolio(option.id)}
                >
                  <Ionicons name={option.icon as any} size={20} color={selectedPortfolio === option.id ? '#3B82F6' : '#9CA3AF'} />
                  <Text style={[styles.portfolioLabel, selectedPortfolio === option.id && styles.portfolioLabelActive]}>{option.label}</Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>
          <View style={styles.section}>
            <Text style={styles.sectionLabel}>Quantity (Shares)</Text>
            <TextInput
              style={styles.quantityInput}
              placeholder="Enter number of shares"
              placeholderTextColor="#6B7280"
              keyboardType="number-pad"
              value={quantity}
              onChangeText={setQuantity}
              inputAccessoryViewID="quickTradeKeyboardDone"
            />
            <View style={styles.quickAmounts}>
              {quickAmounts.map((amount) => (
                <TouchableOpacity key={amount} style={styles.quickButton} onPress={() => setQuantity(amount.toString())}>
                  <Text style={styles.quickButtonText}>{amount}</Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>
          <View style={styles.summaryCard}>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Price per Share</Text>
              <Text style={styles.summaryValue}>{price.toFixed(2)}p</Text>
            </View>
            <View style={styles.summaryRow}>
              <Text style={styles.summaryLabel}>Quantity</Text>
              <Text style={styles.summaryValue}>{quantity || '0'} shares</Text>
            </View>
            <View style={[styles.summaryRow, styles.summaryTotal]}>
              <Text style={styles.totalLabel}>Estimated Total</Text>
              <Text style={styles.totalValue}>£{quantity ? ((parseInt(quantity, 10) * price) / 100).toFixed(2) : '0.00'}</Text>
            </View>
          </View>
          {concentrationWarning && !error && (
            <View style={[styles.errorContainer, { backgroundColor: 'rgba(251, 191, 36, 0.1)' }] }>
              <Ionicons name="alert" size={18} color="#F59E42" />
              <Text style={[styles.errorText, { color: '#F59E42' }]}>{concentrationWarning}</Text>
            </View>
          )}
          {error && (
            <View style={styles.errorContainer}>
              <Ionicons name="alert-circle" size={18} color="#EF4444" />
              <Text style={styles.errorText}>{error}</Text>
            </View>
          )}
          {maxSharesAllowed !== null && tradeAction === 'buy' && (
            <Text style={{ color: '#9CA3AF', fontSize: 13, marginBottom: 8, textAlign: 'center' }}>
              Max allowed: <Text style={{ color: '#3B82F6', fontWeight: 'bold' }}>{maxSharesAllowed}</Text> shares
            </Text>
          )}
          <TouchableOpacity style={[styles.executeButton, loading && styles.executeButtonDisabled]} onPress={handleTrade} disabled={loading || !quantity || !!error || !!tradeSuccess}>
            <LinearGradient
              colors={
                tradingWindow?.type === 'after_hours'
                  ? ['#F59E0B', '#D97706'] // Orange for after-hours
                  : tradingWindow?.type === 'pre_market' || tradingWindow?.type === 'weekend_holiday'
                  ? ['#3B82F6', '#2563EB'] // Blue for pending orders
                  : tradeAction === 'buy'
                  ? ['#10B981', '#059669'] // Green for buy
                  : ['#EF4444', '#DC2626'] // Red for sell
              }
              style={styles.executeGradient}
            >
              {loading ? (
                <ActivityIndicator color="#FFFFFF" />
              ) : (
                <>
                  <Ionicons
                    name={
                      tradingWindow?.type === 'pre_market' || tradingWindow?.type === 'weekend_holiday'
                        ? 'time'
                        : tradeAction === 'buy'
                        ? 'add-circle'
                        : 'remove-circle'
                    }
                    size={24}
                    color="#FFFFFF"
                  />
                  <Text style={styles.executeText}>
                    {tradingWindow?.type === 'pre_market' || tradingWindow?.type === 'weekend_holiday'
                      ? `Schedule ${tradeAction === 'buy' ? 'Buy' : 'Sell'}`
                      : tradingWindow?.type === 'after_hours'
                      ? `${tradeAction === 'buy' ? 'Buy' : 'Sell'} at Close`
                      : `${tradeAction === 'buy' ? 'Buy' : 'Sell'} ${symbol}`}
                  </Text>
                </>
              )}
            </LinearGradient>
          </TouchableOpacity>
          <Text style={styles.disclaimer}>This is a simulated trading platform for educational purposes only. No real money is involved.</Text>
        </View>
      </KeyboardAvoidingView>
      {Platform.OS === 'ios' && (
        <InputAccessoryView nativeID="quickTradeKeyboardDone">
          <View style={styles.keyboardDoneBar}>
            <TouchableOpacity onPress={() => Keyboard.dismiss()} style={styles.keyboardDoneButton}>
              <Text style={styles.keyboardDoneText}>Done</Text>
            </TouchableOpacity>
          </View>
        </InputAccessoryView>
      )}
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalContainer: { flex: 1, justifyContent: 'center', backgroundColor: 'rgba(0,0,0,0.4)' },
  modalContent: { backgroundColor: '#18181B', margin: 20, borderRadius: 20, padding: 20, shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.25, shadowRadius: 4, elevation: 5 },
  closeButton: { position: 'absolute', top: 10, right: 10, zIndex: 10 },
  title: { color: '#FFFFFF', fontSize: 20, fontWeight: 'bold', textAlign: 'center', marginBottom: 20 },
  actionToggle: { flexDirection: 'row', backgroundColor: 'rgba(31, 41, 55, 0.5)', borderRadius: 12, padding: 4, marginBottom: 20 },
  actionButton: { flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', paddingVertical: 12, borderRadius: 10 },
  buyActive: { backgroundColor: '#10B981' },
  sellActive: { backgroundColor: '#EF4444' },
  actionText: { fontSize: 16, fontWeight: '600', marginLeft: 6, color: '#9CA3AF' },
  actionTextActive: { color: '#FFFFFF' },
  section: { marginBottom: 20 },
  sectionLabel: { color: '#9CA3AF', fontSize: 13, fontWeight: '600', marginBottom: 10 },
  portfolioGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  portfolioOption: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(31, 41, 55, 0.5)', paddingHorizontal: 14, paddingVertical: 10, borderRadius: 10, borderWidth: 1, borderColor: 'rgba(75, 85, 99, 0.3)' },
  portfolioOptionActive: { backgroundColor: 'rgba(59, 130, 246, 0.2)', borderColor: '#3B82F6' },
  portfolioLabel: { color: '#9CA3AF', fontSize: 14, marginLeft: 6 },
  portfolioLabelActive: { color: '#3B82F6', fontWeight: '600' },
  quantityInput: { backgroundColor: 'rgba(31, 41, 55, 0.5)', borderRadius: 12, padding: 16, fontSize: 18, color: '#FFFFFF', borderWidth: 1, borderColor: 'rgba(75, 85, 99, 0.3)' },
  quickAmounts: { flexDirection: 'row', gap: 8, marginTop: 10 },
  quickButton: { flex: 1, backgroundColor: 'rgba(31, 41, 55, 0.5)', paddingVertical: 10, borderRadius: 8, alignItems: 'center', borderWidth: 1, borderColor: 'rgba(75, 85, 99, 0.3)' },
  quickButtonText: { color: '#9CA3AF', fontSize: 14, fontWeight: '500' },
  summaryCard: { backgroundColor: 'rgba(31, 41, 55, 0.5)', borderRadius: 16, padding: 16, marginBottom: 16, borderWidth: 1, borderColor: 'rgba(75, 85, 99, 0.3)' },
  summaryRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 8 },
  summaryLabel: { color: '#9CA3AF', fontSize: 14 },
  summaryValue: { color: '#FFFFFF', fontSize: 14, fontWeight: '500' },
  summaryTotal: { borderTopWidth: 1, borderTopColor: 'rgba(75, 85, 99, 0.3)', marginTop: 8, paddingTop: 12 },
  totalLabel: { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
  totalValue: { color: '#3B82F6', fontSize: 20, fontWeight: 'bold' },
  errorContainer: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(239, 68, 68, 0.1)', padding: 12, borderRadius: 10, marginBottom: 16 },
  errorText: { color: '#EF4444', fontSize: 14, marginLeft: 8, flex: 1 },
  tradingWindowBanner: { flexDirection: 'row', alignItems: 'center', padding: 12, borderRadius: 10, marginBottom: 16 },
  afterHoursBanner: { backgroundColor: 'rgba(245, 158, 11, 0.15)', borderWidth: 1, borderColor: 'rgba(245, 158, 11, 0.3)' },
  preMarketBanner: { backgroundColor: 'rgba(59, 130, 246, 0.15)', borderWidth: 1, borderColor: 'rgba(59, 130, 246, 0.3)' },
  tradingWindowText: { fontSize: 13, marginLeft: 8, flex: 1 },
  afterHoursText: { color: '#F59E0B' },
  preMarketText: { color: '#3B82F6' },
  successContainer: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(16, 185, 129, 0.15)', padding: 12, borderRadius: 10, marginBottom: 16, borderWidth: 1, borderColor: 'rgba(16, 185, 129, 0.3)' },
  pendingSuccessContainer: { backgroundColor: 'rgba(59, 130, 246, 0.15)', borderColor: 'rgba(59, 130, 246, 0.3)' },
  successText: { color: '#10B981', fontSize: 14, marginLeft: 8, flex: 1, fontWeight: '500' },
  pendingSuccessText: { color: '#3B82F6' },
  executeButton: { borderRadius: 14, overflow: 'hidden', marginBottom: 16 },
  executeButtonDisabled: { opacity: 0.6 },
  executeGradient: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', paddingVertical: 16 },
  executeText: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold', marginLeft: 8 },
  disclaimer: { color: '#6B7280', fontSize: 12, textAlign: 'center', lineHeight: 18 },
  keyboardDoneBar: { backgroundColor: '#2D3748', flexDirection: 'row', justifyContent: 'flex-end', paddingHorizontal: 16, paddingVertical: 8, borderTopWidth: 1, borderTopColor: 'rgba(75, 85, 99, 0.5)' },
  keyboardDoneButton: { paddingHorizontal: 16, paddingVertical: 6, borderRadius: 8, backgroundColor: '#3B82F6' },
  keyboardDoneText: { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
});
