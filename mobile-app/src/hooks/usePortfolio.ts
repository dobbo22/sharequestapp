// Portfolio hook for mobile app
import { useState, useEffect } from 'react';
import { apiService } from '../services/api';

export interface PortfolioData {
  totalValue: number;
  cashBalance: number;
  holdingsValue: number;
  profitLoss: number;
  profitLossPercent: number;
  hasData: boolean;
}

export interface Holding {
  symbol: string;
  companyname: string;
  quantity: number;
  averagePrice: number;
  currentPrice: number;
  totalValue: number;
  profitLoss: number;
  profitLossPercent: number;
}

export interface Transaction {
  id: string;
  symbol: string;
  companyname: string;
  transaction_type: 'BUY' | 'SELL';
  quantity: number;
  price: number;
  total_cost: number;
  created_at: string;
}

export function usePortfolio(portfolioType: string) {
  const [portfolio, setPortfolio] = useState<PortfolioData>({
    totalValue: 0,
    cashBalance: 0,
    holdingsValue: 0,
    profitLoss: 0,
    profitLossPercent: 0,
    hasData: false
  });
  
  const [holdings, setHoldings] = useState<Holding[]>([]);
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchPortfolio = async () => {
    try {
      setError(null);
      const response = await apiService.getPortfolio(portfolioType);
      
      if (response.success && response.data) {
        const data = response.data.portfolio || response.data;
        
        // FIXED: API returns values in pence, convert to pounds for display
        const cashBalance = parseFloat(data.cash_balance || data.cashBalance || '0') / 100;
        const holdingsValue = parseFloat(data.holdingsValue || '0') / 100 || 0;
        const totalValue = parseFloat(data.total_value || '0') / 100 || (cashBalance + holdingsValue);
        
        // FIXED: Use initial_balance from API if available, otherwise default to 100,000
        const initialValue = parseFloat(data.initial_balance || '10000000') / 100; // Convert from pence
        const profitLoss = totalValue - initialValue;
        const profitLossPercent = initialValue > 0 ? (profitLoss / initialValue) * 100 : 0;
        
        setPortfolio({
          totalValue: totalValue,
          cashBalance: cashBalance,
          holdingsValue: holdingsValue,
          profitLoss: profitLoss,
          profitLossPercent: profitLossPercent,
          hasData: totalValue > 0 || cashBalance > 0 || holdingsValue > 0
        });
      } else {
        throw new Error(response.error || 'Failed to fetch portfolio');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load portfolio');
    }
  };

  const fetchHoldings = async () => {
    // FIXED: Use mobile portfolio endpoint which includes holdings data
    try {
      const response = await apiService.getPortfolio(portfolioType);
      
      if (response.success && response.data && response.data.holdings) {
        const holdingsArray = Array.isArray(response.data.holdings) ? response.data.holdings : [];
        
        const mappedHoldings = holdingsArray.map(holding => {
          const quantity = holding.quantity || holding.total_quantity || 0;
          // Prices are always in pence (e.g., 2068.00p, 1.25p)
          const averagePrice = (holding.average_price || holding.averagePrice || holding.weighted_average_price || 0); // pence
          const currentPrice = (holding.current_price || holding.currentPrice || 0); // pence
          // Calculate values in pounds
          const totalValue = (quantity * currentPrice) / 100;
          const costBasis = (quantity * averagePrice) / 100;
          const profitLoss = totalValue - costBasis;
          const profitLossPercent = costBasis > 0 ? (profitLoss / costBasis) * 100 : 0;
          return {
            symbol: holding.symbol,
            companyname: holding.companyname || holding.company_name,
            quantity: quantity,
            averagePrice: averagePrice, // pence
            currentPrice: currentPrice, // pence
            totalValue: totalValue, // pounds
            profitLoss: profitLoss, // pounds
            profitLossPercent: profitLossPercent
          };
        });
        
        setHoldings(mappedHoldings);
        console.log(`📊 [usePortfolio] Loaded ${mappedHoldings.length} holdings for ${portfolioType} from mobile API`);
      } else {
        setHoldings([]);
        console.log(`⚠️ [usePortfolio] No holdings found for ${portfolioType} from mobile API`);
      }
    } catch (err) {
      console.error('Error fetching holdings:', err);
      setHoldings([]);
    }
  };

  const fetchTransactions = async () => {
    try {
      const response = await apiService.getPortfolioTransactions(portfolioType);
      
      if (response.success && response.data) {
        // FIXED: Handle the response format from portfolio transactions API
        const rawData = response.data.transactions || response.data;
        const transactionsArray = Array.isArray(rawData) ? rawData : [];
        
        const mappedTransactions = transactionsArray.map(transaction => ({
          id: transaction.id,
          symbol: transaction.symbol,
          companyname: transaction.companyname || transaction.company_name,
          transaction_type: transaction.action?.toUpperCase() || transaction.transaction_type,
          quantity: transaction.quantity,
          price: (transaction.price || 0) / 100, // FIXED: Convert to pounds (match holdings)
          total_cost: (transaction.total_amount || transaction.total_cost || transaction.total_value || 0) / 100, // FIXED: Convert to pounds
          created_at: transaction.transaction_date || transaction.created_at
        }));
        
        setTransactions(mappedTransactions);
        console.log(`📊 [usePortfolio] Loaded ${mappedTransactions.length} transactions for ${portfolioType}`);
      } else {
        setTransactions([]);
        console.log(`⚠️ [usePortfolio] No transactions found for ${portfolioType}`);
      }
    } catch (err) {
      console.error('Error fetching transactions:', err);
      setTransactions([]);
    }
  };

  const loadAll = async () => {
    setLoading(true);
    try {
      // FIXED: Use single mobile portfolio endpoint that includes holdings
      const portfolioResponse = await apiService.getPortfolio(portfolioType);

      // Process portfolio data
      let cashBalance = 0;
      let calculatedHoldings: Holding[] = [];
      let holdingsValue = 0;
      
      if (portfolioResponse.success && portfolioResponse.data) {
        const data = portfolioResponse.data.portfolio || portfolioResponse.data;
        cashBalance = parseFloat(data.cash_balance || data.cashBalance || '0') / 100;

        // Process holdings data from the same response
        const holdingsData = portfolioResponse.data.holdings || [];
        const holdingsArray = Array.isArray(holdingsData) ? holdingsData : [];
        
        calculatedHoldings = holdingsArray.map(holding => {
          const quantity = holding.quantity || holding.total_quantity || 0;
          // Prices are always in pence (e.g., 2068.00p, 1.25p)
          const averagePrice = (holding.average_price || holding.averagePrice || holding.weighted_average_price || 0); // pence
          const currentPrice = (holding.current_price || holding.currentPrice || 0); // pence
          const totalValue = (quantity * currentPrice) / 100;
          const costBasis = (quantity * averagePrice) / 100;
          const profitLoss = totalValue - costBasis;
          const profitLossPercent = costBasis > 0 ? (profitLoss / costBasis) * 100 : 0;
          holdingsValue += totalValue;
          return {
            symbol: holding.symbol,
            companyname: holding.companyname || holding.company_name,
            quantity: quantity,
            averagePrice: averagePrice, // pence
            currentPrice: currentPrice, // pence
            totalValue: totalValue, // pounds
            profitLoss: profitLoss, // pounds
            profitLossPercent: profitLossPercent
          };
        });
      }

      // Calculate final portfolio values
      const totalValue = cashBalance + holdingsValue;
      const initialValue = 100000; // £100,000
      const profitLoss = totalValue - initialValue;
      const profitLossPercent = initialValue > 0 ? (profitLoss / initialValue) * 100 : 0;

      // Set all state at once
      setPortfolio({
        totalValue: totalValue,
        cashBalance: cashBalance,
        holdingsValue: holdingsValue,
        profitLoss: profitLoss,
        profitLossPercent: profitLossPercent,
        hasData: totalValue > 0 || cashBalance > 0 || holdingsValue > 0
      });

      setHoldings(calculatedHoldings);
      
      console.log(`📊 [usePortfolio] Calculated values - Cash: £${cashBalance.toFixed(2)}, Holdings: £${holdingsValue.toFixed(2)}, Total: £${totalValue.toFixed(2)}`);
      
      // Load transactions separately
      await fetchTransactions();
      
    } catch (err) {
      console.error('Error loading portfolio data:', err);
      setError(err instanceof Error ? err.message : 'Failed to load portfolio data');
    } finally {
      setLoading(false);
    }
  };

  const refetch = async () => {
    await loadAll();
  };

  useEffect(() => {
    loadAll();
  }, [portfolioType]);

  return {
    portfolio,
    holdings,
    transactions,
    loading,
    error,
    refetch,
    fetchPortfolio,
    fetchHoldings,
    fetchTransactions
  };
}