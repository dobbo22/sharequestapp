import React, { useState, useEffect } from 'react';
import { PortfolioType, Holding } from '../../types';
import { validateTradeConcentration, calculateMaxSharesAllowed } from '../../services/portfolio-limits';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { apiService } from '../../services/api';

interface StockData {
  symbol: string;
  companyName: string;
  quote: {
    price: number;
    change: number;
    changePercent: number;
    bid?: number;
    ask?: number;
  };
}

interface Props {
  stockData: StockData;
  symbol: string;
}

type PortfolioOptionType = string; // 'default' | 'weekly' | 'monthly' | 'annual' | 'league-xxx'

interface PortfolioOption {
  id: string;
  label: string;
  icon: string;
}

const ALL_PORTFOLIO_OPTIONS: PortfolioOption[] = [
  { id: 'default', label: 'Practice', icon: 'school-outline' },
  { id: 'weekly', label: 'Weekly', icon: 'calendar-outline' },
  { id: 'monthly', label: 'Monthly', icon: 'calendar-number-outline' },
  { id: 'annual', label: 'Annual', icon: 'trophy-outline' },
];

export default function TradeTab({ stockData, symbol }: Props) {
  const router = useRouter();
  const [quantity, setQuantity] = useState('');
  const [selectedPortfolio, setSelectedPortfolio] = useState<string>('default');
  const [tradeAction, setTradeAction] = useState<'buy' | 'sell'>('buy');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [concentrationWarning, setConcentrationWarning] = useState<string | null>(null);
  const [maxSharesAllowed, setMaxSharesAllowed] = useState<number | null>(null);
  const [holdings, setHoldings] = useState<Holding[]>([]);
  const [cashBalance, setCashBalance] = useState<number>(10000000); // Default £100k in pence
  const [portfolioOptions, setPortfolioOptions] = useState<PortfolioOption[]>(ALL_PORTFOLIO_OPTIONS);
  const [subsLoading, setSubsLoading] = useState(true);

  const price = stockData.quote.price;
  const totalValue = quantity ? (parseInt(quantity, 10) * price) / 100 : 0;

  // Fetch subscriptions and leagues to build available portfolio options
  useEffect(() => {
    async function loadAvailablePortfolios() {
      setSubsLoading(true);
      const options: PortfolioOption[] = [];

      try {
        // Fetch user subscriptions
        const subsRes = await apiService.request('/mobile/subscriptions', { method: 'GET' });
        if (subsRes.success && subsRes.data) {
          const subs = (subsRes.data as any)?.subscriptions || subsRes.data;
          // Always include Practice
          options.push({ id: 'default', label: 'Practice', icon: 'school-outline' });
          if (subs?.weekly) options.push({ id: 'weekly', label: 'Weekly', icon: 'calendar-outline' });
          if (subs?.monthly) options.push({ id: 'monthly', label: 'Monthly', icon: 'calendar-number-outline' });
          if (subs?.annual) options.push({ id: 'annual', label: 'Annual', icon: 'trophy-outline' });
        } else {
          // Fallback: show all standard options
          options.push(...ALL_PORTFOLIO_OPTIONS);
        }
      } catch {
        options.push(...ALL_PORTFOLIO_OPTIONS);
      }

      try {
        // Fetch league portfolios
        const leaguesRes = await apiService.getLeagues();
        if (leaguesRes.success && leaguesRes.data?.myLeagues) {
          const activeLeagues = leaguesRes.data.myLeagues.filter(
            (l: any) => l.status === 'active'
          );
          for (const league of activeLeagues) {
            options.push({
              id: `league-${league.id}`,
              label: league.name,
              icon: 'trophy-outline',
            });
          }
        }
      } catch {
        // Leagues not available, skip
      }

      setPortfolioOptions(options);
      // Set default to first available
      if (options.length > 0 && !options.find(o => o.id === selectedPortfolio)) {
        setSelectedPortfolio(options[0].id);
      }
      setSubsLoading(false);
    }
    loadAvailablePortfolios();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Fetch portfolio holdings and cash on portfolio or symbol change
  useEffect(() => {
    async function fetchPortfolio() {
      setConcentrationWarning(null);
      setError(null);
      setMaxSharesAllowed(null);
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
    }
    fetchPortfolio();
  }, [selectedPortfolio, symbol]);

  // Validate concentration/max allowed on quantity, action, holdings, cash change
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
    if (error) {
      // Prevent trade if concentration error
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await apiService.trade(
        selectedPortfolio,
        symbol,
        parseInt(quantity, 10),
        tradeAction,
        price
      );

      if (response.success) {
        Alert.alert(
          'Trade Successful',
          `Successfully ${tradeAction === 'buy' ? 'bought' : 'sold'} ${quantity} shares of ${symbol}`,
          [
            {
              text: 'View Portfolio',
              onPress: () => router.push('/(tabs)/portfolio'),
            },
            { text: 'OK' },
          ]
        );
        setQuantity('');
      } else {
        setError(response.error || 'Trade failed');
      }
    } catch (err) {
      setError('An error occurred while processing your trade');
    } finally {
      setLoading(false);
    }
  };

  // Quick amounts limited by maxSharesAllowed if present
  const quickAmounts = [10, 50, 100, 500].filter(a => !maxSharesAllowed || a <= maxSharesAllowed);

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={styles.container}
    >
      {/* Action Toggle */}
      <View style={styles.actionToggle}>
        <TouchableOpacity
          style={[styles.actionButton, tradeAction === 'buy' && styles.buyActive]}
          onPress={() => setTradeAction('buy')}
        >
          <Ionicons
            name="add-circle-outline"
            size={20}
            color={tradeAction === 'buy' ? '#FFFFFF' : '#10B981'}
          />
          <Text style={[styles.actionText, tradeAction === 'buy' && styles.actionTextActive]}>
            Buy
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.actionButton, tradeAction === 'sell' && styles.sellActive]}
          onPress={() => setTradeAction('sell')}
        >
          <Ionicons
            name="remove-circle-outline"
            size={20}
            color={tradeAction === 'sell' ? '#FFFFFF' : '#EF4444'}
          />
          <Text style={[styles.actionText, tradeAction === 'sell' && styles.actionTextActive]}>
            Sell
          </Text>
        </TouchableOpacity>
      </View>

      {/* Portfolio Selection */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>Select Portfolio</Text>
        <View style={styles.portfolioGrid}>
          {portfolioOptions.map((option) => (
            <TouchableOpacity
              key={option.id}
              style={[
                styles.portfolioOption,
                selectedPortfolio === option.id && styles.portfolioOptionActive,
                option.id === 'annual' && selectedPortfolio === 'annual' && { backgroundColor: '#FFA726', borderColor: '#FFA726' },
                option.id === 'default' && selectedPortfolio === 'default' && { backgroundColor: '#3B82F6', borderColor: '#3B82F6' },
              ]}
              onPress={() => setSelectedPortfolio(option.id)}
            >
              <Ionicons
                name={option.icon as any}
                size={20}
                color={
                  selectedPortfolio === option.id
                    ? option.id === 'annual'
                      ? '#232946'
                      : option.id === 'default'
                        ? '#FFFFFF'
                        : '#3B82F6'
                    : '#9CA3AF'
                }
              />
              <Text
                style={[
                  styles.portfolioLabel,
                  selectedPortfolio === option.id && styles.portfolioLabelActive,
                  option.id === 'annual' && selectedPortfolio === 'annual' && { color: '#232946', fontWeight: 'bold' },
                  option.id === 'default' && selectedPortfolio === 'default' && { color: '#FFFFFF', fontWeight: 'bold' },
                ]}
              >
                {option.label}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Quantity Input */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>Quantity (Shares)</Text>
        <TextInput
          style={styles.quantityInput}
          placeholder="Enter number of shares"
          placeholderTextColor="#6B7280"
          keyboardType="number-pad"
          value={quantity}
          onChangeText={setQuantity}
        />

      </View>

      {/* Price Summary */}
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
          <Text style={styles.totalValue}>£{totalValue.toFixed(2)}</Text>
        </View>
      </View>


      {/* Concentration Warning */}
      {concentrationWarning && !error && (
        <View style={[styles.errorContainer, { backgroundColor: 'rgba(251, 191, 36, 0.1)' }] }>
          <Ionicons name="alert" size={18} color="#F59E42" />
          <Text style={[styles.errorText, { color: '#F59E42' }]}>{concentrationWarning}</Text>
        </View>
      )}
      {/* Error Message */}
      {error && (
        <View style={styles.errorContainer}>
          <Ionicons name="alert-circle" size={18} color="#EF4444" />
          <Text style={styles.errorText}>{error}</Text>
        </View>
      )}

      {/* Max allowed info */}
      {maxSharesAllowed !== null && tradeAction === 'buy' && !isNaN(maxSharesAllowed) && (
        <Text style={{ color: '#9CA3AF', fontSize: 13, marginBottom: 8, textAlign: 'center' }}>
          Max allowed: <Text style={{ color: '#3B82F6', fontWeight: 'bold' }}>{maxSharesAllowed}</Text> shares
        </Text>
      )}

      {/* Execute Button */}
      <TouchableOpacity
        style={[styles.executeButton, loading && styles.executeButtonDisabled]}
        onPress={handleTrade}
        disabled={loading || !quantity || !!error}
      >
        <LinearGradient
          colors={tradeAction === 'buy' ? ['#10B981', '#059669'] : ['#EF4444', '#DC2626']}
          style={styles.executeGradient}
        >
          {loading ? (
            <ActivityIndicator color="#FFFFFF" />
          ) : (
            <>
              <Ionicons
                name={tradeAction === 'buy' ? 'add-circle' : 'remove-circle'}
                size={24}
                color="#FFFFFF"
              />
              <Text style={styles.executeText}>
                {tradeAction === 'buy' ? 'Buy' : 'Sell'} {symbol}
              </Text>
            </>
          )}
        </LinearGradient>
      </TouchableOpacity>

      {/* Disclaimer */}
      <Text style={styles.disclaimer}>
        This is a simulated trading platform for educational purposes only.
        No real money is involved.
      </Text>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  actionToggle: {
    flexDirection: 'row',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 4,
    marginBottom: 20,
  },
  actionButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    borderRadius: 10,
  },
  buyActive: { backgroundColor: '#10B981' },
  sellActive: { backgroundColor: '#EF4444' },
  actionText: {
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 6,
    color: '#9CA3AF',
  },
  actionTextActive: { color: '#FFFFFF' },
  section: { marginBottom: 20 },
  sectionLabel: {
    color: '#9CA3AF',
    fontSize: 13,
    fontWeight: '600',
    marginBottom: 10,
  },
  portfolioGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  portfolioOption: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  portfolioOptionActive: {
    backgroundColor: 'rgba(59, 130, 246, 0.2)',
    borderColor: '#3B82F6',
  },
  portfolioLabel: {
    color: '#9CA3AF',
    fontSize: 14,
    marginLeft: 6,
  },
  portfolioLabelActive: { color: '#3B82F6', fontWeight: '600' },
  quantityInput: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 16,
    fontSize: 18,
    color: '#FFFFFF',
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  quickAmounts: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 10,
  },
  quickButton: {
    flex: 1,
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    paddingVertical: 10,
    borderRadius: 8,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  quickButtonText: {
    color: '#9CA3AF',
    fontSize: 14,
    fontWeight: '500',
  },
  summaryCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 16,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
  },
  summaryLabel: { color: '#9CA3AF', fontSize: 14 },
  summaryValue: { color: '#FFFFFF', fontSize: 14, fontWeight: '500' },
  summaryTotal: {
    borderTopWidth: 1,
    borderTopColor: 'rgba(75, 85, 99, 0.3)',
    marginTop: 8,
    paddingTop: 12,
  },
  totalLabel: { color: '#FFFFFF', fontSize: 16, fontWeight: '600' },
  totalValue: { color: '#3B82F6', fontSize: 20, fontWeight: 'bold' },
  errorContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(239, 68, 68, 0.1)',
    padding: 12,
    borderRadius: 10,
    marginBottom: 16,
  },
  errorText: {
    color: '#EF4444',
    fontSize: 14,
    marginLeft: 8,
    flex: 1,
  },
  executeButton: {
    borderRadius: 14,
    overflow: 'hidden',
    marginBottom: 16,
  },
  executeButtonDisabled: { opacity: 0.6 },
  executeGradient: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
  },
  executeText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: 'bold',
    marginLeft: 8,
  },
  disclaimer: {
    color: '#6B7280',
    fontSize: 12,
    textAlign: 'center',
    lineHeight: 18,
  },
});
