// Utility functions for the mobile app

/**
 * Format pence values for display
 * @param pence - Value in pence
 * @returns Formatted string
 */
export function formatPence(pence: number): string {
  if (typeof pence !== 'number' || isNaN(pence)) {
    return '0p';
  }
  return `${pence.toFixed(2)}p`;
}

/**
 * Format percentage for display
 * @param value - Percentage value
 * @returns Formatted string with % sign
 */
export function formatPercent(value: number): string {
  if (typeof value !== 'number' || isNaN(value)) {
    return '0.00%';
  }

  return `${value > 0 ? '+' : ''}${value.toFixed(2)}%`;
}

/**
 * Format large numbers with K/M suffixes
 * @param num - Number to format
 * @returns Formatted string
 */
export function formatNumber(num: number): string {
  if (typeof num !== 'number' || isNaN(num)) {
    return '0';
  }

  if (num >= 1000000) {
    return `${(num / 1000000).toFixed(1)}M`;
  }
  if (num >= 1000) {
    return `${(num / 1000).toFixed(1)}K`;
  }
  return num.toString();
}
