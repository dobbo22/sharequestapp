// Minimal local backend mock to satisfy api.ts import after revert
// Provides only the methods referenced when localMode is enabled.

export const localBackend = {
  async login(username: string, password: string) {
    return { token: `dev-token-${username}`, user: { id: 'local-user', username } };
  },
  async me(userId: string) {
    return { id: userId, username: 'local', email: 'local@example.com' };
  },
  async getPortfolio(type: string) {
    return {
      totalValue: 10000,
      cashBalance: 6000,
      holdingsValue: 4000,
      profitLoss: 0,
      profitLossPercent: 0,
      holdings: [],
      transactions: []
    };
  },
  async leaderboard(type: string) {
    return [
      { userId: 'local-user', username: 'local', portfolioValue: 10000, profit: 0, profitPercent: 0, rank: 1, cashBalance: 6000, totalInvested: 4000 }
    ];
  },
  async listPortfolio(userId: string, type: string) {
    return { holdings: [], cash_balance: 6000 };
  },
  async trade(userId: string, type: string, symbol: string, quantity: number, action: 'BUY'|'SELL') {
    return { success: true, trade: { userId, type, symbol, quantity, action, price: 100, timestamp: Date.now() } };
  }
};
