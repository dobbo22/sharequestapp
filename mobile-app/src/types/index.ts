// Core types for the trading app mobile version

export interface User {
  id: string;
  email: string;
  username: string;
  first_name?: string;
  last_name?: string;
  subscriptions?: UserSubscription[];
  isAdmin?: boolean;
}

export interface UserSubscription {
  portfolioType: PortfolioType;
  status: 'active' | 'inactive' | 'trial';
  expiresAt?: Date;
}

export type PortfolioType = 'weekly' | 'monthly' | 'annual' | 'default';

export interface Portfolio {
  id: string;
  userId: string;
  portfolioType: PortfolioType;
  cashBalance: number;
  totalValue: number;
  totalReturn: number;
  totalReturnPercent: number;
  createdAt: Date;
  updatedAt: Date;
  isActive: boolean;
  holdings: Holding[];
}

export interface Holding {
  id: string;
  portfolioId: string;
  symbol: string;
  companyName: string;
  quantity: number;
  averagePrice: number;
  currentPrice: number;
  totalValue: number;
  totalReturn: number;
  totalReturnPercent: number;
  lastUpdated: Date;
}

export interface Stock {
  id?: string;
  symbol: string;
  companyname?: string;
  company_name?: string;
  name?: string;
  currentPrice?: number;
  price?: number;
  change?: number;
  changePercent?: number;
  change_percent?: number;
  volume?: number;
  marketCap?: number;
  market_cap?: number;
  sector?: string;
  currency?: string;
  lastUpdated?: Date;
}

export interface Trade {
  id: string;
  portfolioId: string;
  symbol: string;
  companyName: string;
  type: 'buy' | 'sell';
  quantity: number;
  price: number;
  total: number;
  fees: number;
  executedAt: Date;
  status: 'pending' | 'executed' | 'failed';
}

export interface PriceAlert {
  id: string;
  symbol: string;
  companyName: string;
  alertType: 'above' | 'below' | 'change_percent';
  targetValue: number;
  currentPrice: number;
  isActive: boolean;
  createdAt: Date;
  triggeredAt?: Date;
  lastNotified?: Date;
}

export interface Competition {
  id: string;
  portfolioType: PortfolioType;
  startDate: Date;
  endDate: Date;
  status: 'upcoming' | 'active' | 'completed';
  prizePot: number;
  participantCount: number;
}

export interface LeaderboardEntry {
  rank: number;
  userId: string;
  username: string;
  portfolioId: string;
  totalReturn: number;
  totalReturnPercent: number;
  portfolioValue: number;
}

export interface CommunityPost {
  id: string;
  userId: string;
  username: string;
  stockSymbol?: string;
  title: string;
  content: string;
  sentiment: 'bullish' | 'bearish' | 'neutral';
  likesCount: number;
  commentsCount: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface StockComment {
  id: string;
  stockSymbol: string;
  userId: string;
  username: string;
  content: string;
  sentiment: 'bullish' | 'bearish' | 'neutral';
  likesCount: number;
  createdAt: Date;
}

// Navigation types
export type RootStackParamList = {
  Auth: undefined;
  Main: undefined;
  Stock: { symbol: string };
  Trade: { symbol: string; type: 'buy' | 'sell' };
  PortfolioDetails: { portfolioType: string };
  Subscription: { portfolioType: string };
  Terms: undefined;
  Privacy: undefined;
  UserPortfolio: { portfolioType: string; userId: string; username?: string };
};

export type MainTabParamList = {
  Dashboard: undefined;
  Portfolio: undefined;
  Stocks: undefined;
  Leaderboards: undefined;
  Community: undefined;
  Profile: undefined;
};

// API Response types
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

// Hook return types
export interface UseApiReturn<T> {
  data: T | null;
  loading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

// Component prop types
export interface StockCardProps {
  stock: Stock;
  onPress?: () => void;
  showChange?: boolean;
}

export interface PortfolioCardProps {
  portfolio: Portfolio;
  onPress?: () => void;
  compact?: boolean;
}

export interface TradeButtonProps {
  symbol: string;
  companyName: string;
  currentPrice: number;
  type: 'buy' | 'sell';
  onPress: () => void;
}