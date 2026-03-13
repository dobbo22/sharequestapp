export interface LocalBackend {
  login(username: string, password: string): Promise<{ token: string; user: { id: string; username: string } }>;
  getPortfolio(type: string): Promise<any>;
  leaderboard(type: string): Promise<any[]>;
  listPortfolio(userId: string, type: string): Promise<any>;
}
export const localBackend: LocalBackend;
