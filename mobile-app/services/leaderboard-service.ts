// services/leaderboard-service.ts
// Refactored to use apiService to avoid missing modules and unify response shapes
import { apiService } from '../src/services/api';

export interface LeaderboardEntry {
  rank: number;
  user_id: string;
  username: string;
  portfolio_value: number;
  profit_loss: number;
  profit_loss_percentage: number;
  holdings_count: number;
  is_current_user?: boolean;
}

export interface LeaderboardResponse {
  success: boolean;
  error?: string;
  leaderboard?: LeaderboardEntry[];
  totalParticipants?: number;
  currentUserEntry?: LeaderboardEntry;
}

export const fetchLeaderboard = async (
  portfolioType: string,
  limit: number = 10,
  page: number = 1
): Promise<LeaderboardResponse> => {
  try {
    const params = new URLSearchParams({ limit: String(limit), page: String(page) });
    const resp = await apiService.request<any>(`/leaderboards/${portfolioType}?${params.toString()}`, { method: 'GET' });
    if (!resp.success) {
      return { success: false, error: resp.error || 'Failed to fetch leaderboard', leaderboard: [] };
    }
    const data = (resp.data as any) || {};
    return {
      success: true,
      leaderboard: data.leaderboard || data.entries || [],
      totalParticipants: data.totalParticipants || data.total || (data.leaderboard ? data.leaderboard.length : 0),
      currentUserEntry: data.currentUserEntry,
    };
  } catch (error) {
    console.error('Error fetching leaderboard:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch leaderboard',
      leaderboard: []
    };
  }
};
