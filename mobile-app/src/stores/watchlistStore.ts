import { create } from 'zustand';
import AsyncStorage from '@react-native-async-storage/async-storage';

interface WatchlistItem {
  symbol: string;
  addedAt: string;
}

interface WatchlistStore {
  watchlist: WatchlistItem[];
  isLoading: boolean;
  loadWatchlist: () => Promise<void>;
  addToWatchlist: (symbol: string) => Promise<void>;
  removeFromWatchlist: (symbol: string) => Promise<void>;
  isInWatchlist: (symbol: string) => boolean;
  toggleWatchlist: (symbol: string) => Promise<void>;
}

const WATCHLIST_KEY = 'stock_watchlist';

export const useWatchlistStore = create<WatchlistStore>((set, get) => ({
  watchlist: [],
  isLoading: false,

  loadWatchlist: async () => {
    set({ isLoading: true });
    try {
      const stored = await AsyncStorage.getItem(WATCHLIST_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        set({ watchlist: Array.isArray(parsed) ? parsed : [] });
      }
    } catch (error) {
      console.error('Failed to load watchlist:', error);
    } finally {
      set({ isLoading: false });
    }
  },

  addToWatchlist: async (symbol: string) => {
    const { watchlist } = get();
    if (watchlist.some(item => item.symbol === symbol)) return;

    const newItem: WatchlistItem = {
      symbol,
      addedAt: new Date().toISOString(),
    };
    const newWatchlist = [...watchlist, newItem];

    set({ watchlist: newWatchlist });
    try {
      await AsyncStorage.setItem(WATCHLIST_KEY, JSON.stringify(newWatchlist));
    } catch (error) {
      console.error('Failed to save watchlist:', error);
    }
  },

  removeFromWatchlist: async (symbol: string) => {
    const { watchlist } = get();
    const newWatchlist = watchlist.filter(item => item.symbol !== symbol);

    set({ watchlist: newWatchlist });
    try {
      await AsyncStorage.setItem(WATCHLIST_KEY, JSON.stringify(newWatchlist));
    } catch (error) {
      console.error('Failed to save watchlist:', error);
    }
  },

  isInWatchlist: (symbol: string) => {
    return get().watchlist.some(item => item.symbol === symbol);
  },

  toggleWatchlist: async (symbol: string) => {
    const { isInWatchlist, addToWatchlist, removeFromWatchlist } = get();
    if (isInWatchlist(symbol)) {
      await removeFromWatchlist(symbol);
    } else {
      await addToWatchlist(symbol);
    }
  },
}));
