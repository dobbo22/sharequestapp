// utils/formatting.ts
export const formatCurrency = (value: number): string => {
  return new Intl.NumberFormat('en-GB', {
    style: 'currency',
    currency: 'GBP',
  }).format(value / 100);
};

export const formatPercentage = (value: number): string => {
  const formatted = new Intl.NumberFormat('en-GB', {
    style: 'percent',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value / 100);
  
  return value >= 0 ? `+${formatted}` : formatted;
};
