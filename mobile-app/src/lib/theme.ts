// Centralized design tokens for ShareQuest mobile app

export const colors = {
  // Backgrounds
  background: '#0f172a',
  surface: 'rgba(31, 41, 55, 0.5)',
  surfaceSolid: '#1f2937',
  surfaceElevated: 'rgba(31, 41, 55, 0.8)',

  // Borders
  border: 'rgba(75, 85, 99, 0.3)',
  borderLight: 'rgba(75, 85, 99, 0.15)',
  borderFocused: 'rgba(59, 130, 246, 0.5)',

  // Primary palette
  primary: '#3B82F6',
  primaryDark: '#2563EB',
  secondary: '#8B5CF6',
  secondaryDark: '#7C3AED',

  // Status
  success: '#10B981',
  successDark: '#059669',
  danger: '#EF4444',
  dangerDark: '#DC2626',
  warning: '#F59E0B',
  warningDark: '#D97706',
  info: '#06B6D4',

  // XP & Gamification
  xp: '#FBBF24',
  xpGlow: 'rgba(251, 191, 36, 0.3)',
  streak: '#FB923C',
  streakHot: '#EF4444',

  // Achievement tiers
  bronze: '#CD7F32',
  silver: '#C0C0C0',
  gold: '#FFD700',
  platinum: '#E5E4E2',

  // Text
  textPrimary: '#FFFFFF',
  textSecondary: '#9CA3AF',
  textMuted: '#6B7280',
  textDim: '#4B5563',

  // Portfolio card gradients
  practice: ['#3B82F6', '#2563EB'] as const,
  weekly: ['#6366F1', '#4338CA'] as const,
  monthly: ['#8B5CF6', '#7C3AED'] as const,
  annual: ['#F59E0B', '#D97706'] as const,

  // Screen gradients
  backgroundGradient: ['#0f172a', '#1e3a5f', '#0f172a'] as const,
  authGradient: ['#0f172a', '#1e3a8a', '#581c87'] as const,
} as const;

export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 20,
  xl: 24,
  xxl: 32,
} as const;

export const radii = {
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  pill: 9999,
} as const;

export const typography = {
  xs: 11,
  sm: 12,
  body: 14,
  md: 16,
  lg: 18,
  xl: 24,
  xxl: 28,
  hero: 36,
} as const;

export const shadows = {
  sm: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 2,
  },
  md: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 8,
    elevation: 4,
  },
  lg: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.25,
    shadowRadius: 16,
    elevation: 8,
  },
  glow: (color: string, radius = 12) => ({
    shadowColor: color,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.4,
    shadowRadius: radius,
    elevation: 6,
  }),
} as const;

// Glassmorphism card style helper
export const glassStyle = (opacity = 0.5) => ({
  backgroundColor: `rgba(31, 41, 55, ${opacity})`,
  borderWidth: 1,
  borderColor: colors.border,
  borderRadius: radii.lg,
});

// Level color mapping
export const levelColors: Record<number, string> = {
  1: '#3B82F6', // Rookie - Blue
  2: '#06B6D4', // Market Watcher - Cyan
  3: '#10B981', // Day Trader - Green
  4: '#8B5CF6', // Swing Trader - Purple
  5: '#F59E0B', // Portfolio Pro - Amber
  6: '#EC4899', // Fund Manager - Pink
  7: '#EF4444', // Market Maker - Red
  8: '#6366F1', // Trading Elite - Indigo
  9: '#14B8A6', // Hedge Fund Boss - Teal
  10: '#FFD700', // Wall Street Wolf - Gold
};
