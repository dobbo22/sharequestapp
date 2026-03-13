
import React, { useState, useEffect } from 'react';
import { Modal, View, Text, TouchableOpacity, TextInput, StyleSheet, ActivityIndicator, KeyboardAvoidingView, Platform, Keyboard, InputAccessoryView } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { MaterialCommunityIcons, MaterialIcons } from '@expo/vector-icons';

import { PortfolioType, Holding } from '../../types/index';
import { TradeCelebration, XPGainToast, AchievementUnlockedModal } from '../gamification';

interface TradeModalProps {
  visible: boolean;
  onClose: () => void;
  holding: {
    symbol: string;
    companyName: string;
    quantity: number;
    averagePrice: number;
    currentPrice: number;
  } | null;
  action: 'buy' | 'sell';
  onExecute: (trade: { symbol: string; quantity: number; action: 'buy' | 'sell'; price: number }) => Promise<{ success: boolean; error?: string; gamification?: { xp?: number; newAchievements?: { name: string; description: string; icon: string; tier: string; xp_reward: number }[]; challengesCompleted?: { name: string; xp_reward: number }[] } }>;
  balance?: number;
  holdings?: Holding[];
  portfolioType?: PortfolioType;
  marketOpen?: boolean;
  concentrationLimit?: number;
  validateTradeConcentration?: (
    portfolioType: PortfolioType,
    symbol: string,
    action: 'buy' | 'sell',
    quantity: number,
    price: number,
    currentCash: number,
    holdings: Holding[]
  ) => { isValid: boolean; errorMessage?: string; warningMessage?: string; maxSharesAllowed: number };
}

export default function TradeModal({ visible, onClose, holding, action, onExecute, balance = 0, holdings = [], portfolioType = 'default', marketOpen = true, concentrationLimit = 25, validateTradeConcentration }: TradeModalProps) {
  const [step, setStep] = useState<'trade' | 'success'>('trade');
  const [quantity, setQuantity] = useState('');
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState('');
  const [concentrationWarning, setConcentrationWarning] = useState('');
  const [successInfo, setSuccessInfo] = useState<{ action: string; symbol: string; quantity: number; price: number } | null>(null);
  const [showConfetti, setShowConfetti] = useState(false);
  const [xpGain, setXpGain] = useState(0);
  const [showXPToast, setShowXPToast] = useState(false);
  const [unlockedAchievement, setUnlockedAchievement] = useState<{ name: string; description: string; icon: string; tier: string; xp_reward: number } | null>(null);

  useEffect(() => {
    if (!visible) {
      setStep('trade');
      setQuantity('');
      setError('');
      setConcentrationWarning('');
      setSuccessInfo(null);
      setShowConfetti(false);
      setXpGain(0);
      setShowXPToast(false);
      setUnlockedAchievement(null);
    }
  }, [visible]);

  if (!holding) return null;

  const tradePrice = holding.currentPrice;
  const maxAffordable = action === 'buy' && tradePrice > 0 ? Math.floor(balance / tradePrice) : holding.quantity;

  // Simulate concentration check (replace with real logic if available)
  useEffect(() => {
    if (action === 'buy' && quantity && validateTradeConcentration && holding && portfolioType) {
      const qty = parseInt(quantity);
      if (qty > 0 && tradePrice > 0 && balance > 0) {
        const check = validateTradeConcentration(
          portfolioType,
          holding.symbol,
          'buy',
          qty,
          tradePrice,
          balance,
          holdings || []
        );
        if (!check.isValid) {
          setError(check.errorMessage || 'Trade exceeds concentration limit');
        } else {
          setError('');
        }
        if (check.warningMessage) {
          setConcentrationWarning(check.warningMessage);
        } else {
          setConcentrationWarning('');
        }
      } else {
        setError('');
        setConcentrationWarning('');
      }
    } else {
      setError('');
      setConcentrationWarning('');
    }
  }, [quantity, action, tradePrice, balance, concentrationLimit, maxAffordable, validateTradeConcentration, holding, portfolioType, holdings]);

  const handleTrade = async () => {
    const qty = parseInt(quantity);
    if (!qty || qty <= 0) {
      setError('Please enter a valid quantity');
      return;
    }
    if (action === 'sell' && qty > holding.quantity) {
      setError(`You can only sell up to ${holding.quantity} shares`);
      return;
    }
    if (action === 'buy' && qty > maxAffordable) {
      setError(`Insufficient funds. Max: ${maxAffordable} shares`);
      return;
    }
    setProcessing(true);
    setError('');
    const result = await onExecute({
      symbol: holding.symbol,
      quantity: qty,
      action,
      price: tradePrice,
    });
    setProcessing(false);
    if (result.success) {
      setSuccessInfo({ action, symbol: holding.symbol, quantity: qty, price: tradePrice });
      setShowConfetti(true);
      setStep('success');
      // Show gamification rewards
      if (result.gamification) {
        if (result.gamification.xp) {
          setXpGain(result.gamification.xp);
          setShowXPToast(true);
        }
        if (result.gamification.newAchievements?.length) {
          // Show first achievement after a short delay
          setTimeout(() => setUnlockedAchievement(result.gamification!.newAchievements![0]), 1500);
        }
      }
    } else {
      setError(result.error || 'Trade failed. Please try again.');
    }
  };

  // --- UI ---
  return (
    <Modal visible={visible} animationType="slide" transparent>
      <View style={styles.overlay}>
        <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ width: '100%' }}>
          <LinearGradient colors={["#1e3a5f", "#581c87"]} style={styles.modalContainer}>
            {/* Header */}
            <View style={styles.headerRow}>
              <Text style={styles.title}>{action === 'buy' ? 'Buy' : 'Sell'} {holding.symbol}</Text>
              <TouchableOpacity onPress={onClose} disabled={processing} style={styles.closeButton}>
                <MaterialCommunityIcons name="close" size={24} color="#fff" />
              </TouchableOpacity>
            </View>
            <Text style={styles.company}>{holding.companyName}</Text>

            {step === 'trade' && (
              <>
                {/* Price and Market Status */}
                <View style={styles.priceRow}>
                  <Text style={styles.priceLabel}>Current Price</Text>
                  <Text style={styles.price}>{tradePrice.toFixed(2)}p</Text>
                  <View style={styles.marketStatusRow}>
                    <MaterialIcons name={marketOpen ? 'check-circle' : 'error'} size={16} color={marketOpen ? '#22c55e' : '#f59e42'} />
                    <Text style={{ color: marketOpen ? '#22c55e' : '#f59e42', marginLeft: 4, fontSize: 13 }}>
                      {marketOpen ? 'Market Open' : 'Market Closed'}
                    </Text>
                  </View>
                </View>

                {/* Balance/Owned/Max Allowed */}
                <View style={styles.infoRow}>
                  <Text style={styles.infoLabel}>{action === 'buy' ? 'Available Balance' : 'Shares Owned'}</Text>
                  <Text style={styles.infoValue}>{action === 'buy' ? `£${(balance / 100).toFixed(2)}` : holding.quantity.toLocaleString()}</Text>
                </View>
                {action === 'buy' && (
                  <View style={styles.infoRow}>
                    <Text style={styles.infoLabel}>Max Affordable</Text>
                    <Text style={styles.infoValue}>{maxAffordable.toLocaleString()} shares</Text>
                  </View>
                )}

                {/* Quantity Input */}
                <TextInput
                  style={styles.input}
                  placeholder="Quantity"
                  keyboardType="numeric"
                  value={quantity}
                  onChangeText={setQuantity}
                  editable={!processing}
                  autoFocus
                  inputAccessoryViewID="tradeModalKeyboardDone"
                />
                {concentrationWarning ? (
                  <Text style={styles.warning}>{concentrationWarning}</Text>
                ) : null}
                {error ? (
                  <Text style={styles.error}>{error}</Text>
                ) : null}

                {/* Action Buttons */}
                <View style={styles.buttonRow}>
                  <TouchableOpacity style={styles.cancelButton} onPress={onClose} disabled={processing}>
                    <MaterialCommunityIcons name="close" size={20} color="#fff" />
                    <Text style={styles.buttonText}>Cancel</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[styles.executeButton, (!quantity || processing || !!error || !marketOpen) && { opacity: 0.5 }]}
                    onPress={handleTrade}
                    disabled={processing || !quantity || !!error || !marketOpen}
                  >
                    {processing ? (
                      <ActivityIndicator color="#fff" />
                    ) : (
                      <>
                        <MaterialCommunityIcons name={action === 'buy' ? 'cart' : 'cash'} size={20} color="#fff" />
                        <Text style={styles.buttonText}>{action === 'buy' ? 'Buy' : 'Sell'}</Text>
                      </>
                    )}
                  </TouchableOpacity>
                </View>
              </>
            )}

            {step === 'success' && successInfo && (
              <View style={styles.successContainer}>
                <MaterialCommunityIcons name="check-circle" size={64} color="#22c55e" style={{ marginBottom: 16 }} />
                <Text style={styles.successTitle}>Trade Successful!</Text>
                <Text style={styles.successText}>
                  {successInfo.action === 'buy' ? 'Bought' : 'Sold'} {successInfo.quantity} shares of {successInfo.symbol} at {successInfo.price.toFixed(2)}p
                </Text>
                <TouchableOpacity style={styles.successButton} onPress={onClose}>
                  <Text style={styles.successButtonText}>Close</Text>
                </TouchableOpacity>
              </View>
            )}
          </LinearGradient>
        </KeyboardAvoidingView>

        {/* Gamification overlays */}
        <TradeCelebration visible={showConfetti} onFinish={() => setShowConfetti(false)} />
        <XPGainToast amount={xpGain} visible={showXPToast} onFinish={() => setShowXPToast(false)} />
        <AchievementUnlockedModal
          visible={!!unlockedAchievement}
          achievement={unlockedAchievement}
          onClose={() => setUnlockedAchievement(null)}
        />
      </View>
      {Platform.OS === 'ios' && (
        <InputAccessoryView nativeID="tradeModalKeyboardDone">
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
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.7)',
    justifyContent: 'center',
    alignItems: 'center',
    width: '100%',
  },
  modalContainer: {
    width: '92%',
    borderRadius: 24,
    padding: 24,
    alignItems: 'center',
    alignSelf: 'center',
    marginTop: 40,
    marginBottom: 40,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    width: '100%',
    marginBottom: 4,
  },
  closeButton: {
    padding: 4,
    marginLeft: 8,
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#fff',
  },
  company: {
    fontSize: 16,
    color: '#cbd5e1',
    marginBottom: 10,
    alignSelf: 'flex-start',
  },
  priceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    width: '100%',
    marginBottom: 8,
  },
  priceLabel: {
    fontSize: 14,
    color: '#a3e635',
    marginRight: 8,
  },
  price: {
    fontSize: 18,
    color: '#fff',
    fontWeight: 'bold',
    marginRight: 8,
  },
  marketStatusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginLeft: 8,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '100%',
    marginBottom: 4,
  },
  infoLabel: {
    color: '#a1a1aa',
    fontSize: 14,
  },
  infoValue: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 15,
  },
  input: {
    width: '100%',
    backgroundColor: '#fff',
    borderRadius: 10,
    padding: 12,
    fontSize: 16,
    marginTop: 12,
    marginBottom: 10,
    textAlign: 'center',
    color: '#222',
  },
  warning: {
    color: '#facc15',
    fontSize: 13,
    marginBottom: 4,
    alignSelf: 'flex-start',
  },
  error: {
    color: '#f87171',
    fontSize: 14,
    marginBottom: 4,
    alignSelf: 'flex-start',
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '100%',
    marginTop: 10,
  },
  cancelButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#64748b',
    padding: 12,
    borderRadius: 10,
    marginRight: 8,
    flex: 1,
    justifyContent: 'center',
  },
  executeButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#3B82F6',
    padding: 12,
    borderRadius: 10,
    flex: 1,
    justifyContent: 'center',
  },
  buttonText: {
    color: '#fff',
    fontWeight: 'bold',
    marginLeft: 6,
    fontSize: 16,
  },
  successContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 24,
    width: '100%',
  },
  successTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#22c55e',
    marginBottom: 8,
  },
  successText: {
    fontSize: 16,
    color: '#fff',
    marginBottom: 20,
    textAlign: 'center',
  },
  successButton: {
    backgroundColor: '#3B82F6',
    paddingVertical: 12,
    paddingHorizontal: 32,
    borderRadius: 10,
  },
  successButtonText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 16,
  },
  keyboardDoneBar: { backgroundColor: '#2D3748', flexDirection: 'row', justifyContent: 'flex-end', paddingHorizontal: 16, paddingVertical: 8, borderTopWidth: 1, borderTopColor: 'rgba(75, 85, 99, 0.5)' },
  keyboardDoneButton: { paddingHorizontal: 16, paddingVertical: 6, borderRadius: 8, backgroundColor: '#3B82F6' },
  keyboardDoneText: { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
});
