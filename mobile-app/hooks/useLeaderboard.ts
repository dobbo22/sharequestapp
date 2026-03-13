// hooks/useLeaderboard.ts
import { useState, useEffect, useCallback } from 'react';
import { fetchLeaderboard, LeaderboardEntry } from '../services/leaderboard-service';

export type PortfolioType = 'weekly' | 'monthly' | 'annual';

export function useLeaderboard(portfolioType: PortfolioType, limit?: number) {
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  
  const loadLeaderboard = useCallback(async () => {
    setLoading(true);
    setError('');
    
    try {
      const response = await fetchLeaderboard(portfolioType, limit);
      
      if (response.success && response.leaderboard) {
        setLeaderboard(response.leaderboard);
        setLastUpdated(new Date());
      } else if (response.error) {
        setError(response.error);
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load leaderboard';
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  }, [portfolioType, limit]);
  
  useEffect(() => {
    loadLeaderboard();
  }, [loadLeaderboard]);
  
  return {
    leaderboard,
    loading,
    error,
    lastUpdated,
    refresh: loadLeaderboard
  };
}
