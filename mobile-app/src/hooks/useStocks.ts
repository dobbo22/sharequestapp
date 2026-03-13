// Stock data management hook
import { useState, useEffect, useCallback } from 'react';
import { apiService } from '../services/api';
import { Stock, UseApiReturn } from '../types';

interface UseStockSearchReturn {
  searchTerm: string;
  setSearchTerm: (term: string) => void;
  searchResults: Stock[];
  loading: boolean;
  error: string | null;
  searchStocks: (query: string) => Promise<void>;
}

export function useStockSearch(): UseStockSearchReturn {
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState<Stock[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const searchStocks = useCallback(async (query: string) => {
    if (!query.trim() || query.length < 2) {
      setSearchResults([]);
      setError(null);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await apiService.searchStocks(query.trim(), 15);
      
      if (response.success && response.data) {
        setSearchResults(response.data);
      } else {
        setError(response.error || 'Search failed');
        setSearchResults([]);
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Search failed';
      setError(errorMessage);
      setSearchResults([]);
    } finally {
      setLoading(false);
    }
  }, []);

  // Debounced search when searchTerm changes
  useEffect(() => {
    const debounceTimer = setTimeout(() => {
      if (searchTerm && searchTerm.length >= 2) {
        searchStocks(searchTerm);
      }
    }, 300);

    return () => clearTimeout(debounceTimer);
  }, [searchTerm, searchStocks]);

  return {
    searchTerm,
    setSearchTerm,
    searchResults,
    loading,
    error,
    searchStocks,
  };
}

export function useStock(symbol: string): UseApiReturn<Stock> {
  const [data, setData] = useState<Stock | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchStock = useCallback(async () => {
    if (!symbol) return;

    setLoading(true);
    setError(null);

    try {
      const response = await apiService.getStock(symbol);
      
      if (response.success && response.data) {
        setData(response.data);
      } else {
        setError(response.error || 'Failed to load stock data');
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load stock data';
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }, [symbol]);

  useEffect(() => {
    fetchStock();
  }, [fetchStock]);

  return {
    data,
    loading,
    error,
    refetch: fetchStock,
  };
}

export function useTop100(): UseApiReturn<Stock[]> {
  const [data, setData] = useState<Stock[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchTop100 = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await apiService.getTop100();
      
      if (response.success && response.data) {
        setData(response.data);
      } else {
        setError(response.error || 'Failed to load Top 100 data');
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load Top 100 data';
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchTop100();
  }, [fetchTop100]);

  return {
    data,
    loading,
    error,
    refetch: fetchTop100,
  };
}

export function useFTSE100(): UseApiReturn<Stock[]> {
  const [data, setData] = useState<Stock[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchFTSE100 = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await apiService.getFTSE100();
      
      if (response.success && response.data) {
        setData(response.data);
      } else {
        setError(response.error || 'Failed to load FTSE 100 data');
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load FTSE 100 data';
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchFTSE100();
  }, [fetchFTSE100]);

  return {
    data,
    loading,
    error,
    refetch: fetchFTSE100,
  };
}

export function useFTSE250(): UseApiReturn<Stock[]> {
  const [data, setData] = useState<Stock[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchFTSE250 = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await apiService.getFTSE250();
      
      if (response.success && response.data) {
        setData(response.data);
      } else {
        setError(response.error || 'Failed to load FTSE 250 data');
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load FTSE 250 data';
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchFTSE250();
  }, [fetchFTSE250]);

  return {
    data,
    loading,
    error,
    refetch: fetchFTSE250,
  };
}