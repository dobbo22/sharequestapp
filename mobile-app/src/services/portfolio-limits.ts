// Mobile version of portfolio concentration logic, ported from services/portfolio-limits-service.ts
// Used in TradeTab for concentration/max allowed checks

import { PortfolioType, Holding } from '../types';

export const PORTFOLIO_CONCENTRATION_LIMITS: Record<PortfolioType, number> = {
  weekly: 20,
  monthly: 10,
  annual: 10,
  default: 100,
};

export function calculateTotalPortfolioValue(cashBalance: number, holdings: Holding[] = []): number {
  // Ensure cashBalance is a valid number
  const safeCash = typeof cashBalance === 'number' && !isNaN(cashBalance) ? cashBalance : 0;
  // Ensure all holdings are valid numbers
  const holdingsValue = (holdings || []).reduce((total, h) => {
    const qty = typeof h.quantity === 'number' && !isNaN(h.quantity) ? h.quantity : 0;
    const price = typeof h.currentPrice === 'number' && !isNaN(h.currentPrice) ? h.currentPrice : 0;
    return total + (qty * price);
  }, 0);
  return safeCash + holdingsValue;

}

export function calculateMaxSharesAllowed(
  portfolioType: PortfolioType,
  symbol: string,
  currentPrice: number,
  currentCash: number,
  holdings: Holding[] = []
): number {
  const totalPortfolioValue = calculateTotalPortfolioValue(currentCash, holdings);
  const maxPercentage = PORTFOLIO_CONCENTRATION_LIMITS[portfolioType];
  const maxAllowedValue = (totalPortfolioValue * maxPercentage) / 100;
  const existingPosition = holdings.find(h => h.symbol === symbol);
  const existingPositionValue = existingPosition ? existingPosition.quantity * existingPosition.currentPrice : 0;
  const remainingAllowedValue = maxAllowedValue - existingPositionValue;
  if (remainingAllowedValue <= 0) return 0;
  const maxSharesByLimit = Math.floor(remainingAllowedValue / currentPrice);
  const maxSharesByCash = Math.floor(currentCash / currentPrice);
  return Math.min(maxSharesByLimit, maxSharesByCash);
}

export function validateTradeConcentration(
  portfolioType: PortfolioType,
  symbol: string,
  action: 'buy' | 'sell',
  quantity: number,
  price: number,
  currentCash: number,
  holdings: Holding[] = []
) {
  if (action === 'sell') {
    return { isValid: true, errorMessage: undefined, warningMessage: undefined, maxSharesAllowed: Infinity };
  }
  // Robust guards for all values
  const safePrice = typeof price === 'number' && !isNaN(price) && price > 0 ? price : 0;
  const safeQuantity = typeof quantity === 'number' && !isNaN(quantity) && quantity > 0 ? quantity : 0;
  const totalPortfolioValue = calculateTotalPortfolioValue(currentCash, holdings);
  const maxPercentage = PORTFOLIO_CONCENTRATION_LIMITS[portfolioType];
  const maxAllowedValue = (totalPortfolioValue * maxPercentage) / 100;
  const existingPosition = holdings.find(h => h.symbol === symbol);
  const existingQuantity = existingPosition && typeof existingPosition.quantity === 'number' && !isNaN(existingPosition.quantity) ? existingPosition.quantity : 0;
  const combinedQuantity = existingQuantity + safeQuantity;
  const combinedValue = combinedQuantity * safePrice;
  const existingPositionValue = existingQuantity * safePrice;
  const newPositionValue = safeQuantity * safePrice;
  const remainingAllowed = maxAllowedValue - existingPositionValue;
  const isValid = newPositionValue <= remainingAllowed && safePrice > 0 && totalPortfolioValue > 0;
  const combinedPercentage = totalPortfolioValue > 0 ? (combinedValue / totalPortfolioValue) * 100 : 0;
  let errorMessage, warningMessage;
  if (!isValid) {
    const maxAllowedDisplay = isNaN(maxAllowedValue) || maxAllowedValue <= 0 ? '0.00' : (maxAllowedValue/100).toFixed(2);
    errorMessage = `This trade would exceed the ${maxPercentage}% concentration limit. Max allowed: £${maxAllowedDisplay}`;
  } else if (combinedPercentage > maxPercentage * 0.9) {
    warningMessage = `Warning: This trade brings your holding to ${combinedPercentage.toFixed(1)}% of portfolio.`;
  }
  const maxSharesAllowed = calculateMaxSharesAllowed(portfolioType, symbol, safePrice, currentCash, holdings);
  return { isValid, errorMessage, warningMessage, maxSharesAllowed };
}
