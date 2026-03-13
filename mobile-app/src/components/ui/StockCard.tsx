// Stock card component for displaying stock information
import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Stock } from '../../types';

interface StockCardProps {
  stock: Stock;
  onPress?: () => void;
  showChange?: boolean;
  compact?: boolean;
}

export default function StockCard({ 
  stock, 
  onPress, 
  showChange = true, 
  compact = false 
}: StockCardProps) {
  // Handle different API response formats
  const currentPrice = (stock as any).currentPrice ?? (stock as any).price ?? 0;
  const change = stock.change || 0;
  const changePercent = (stock as any).changePercent ?? (stock as any).change_percent ?? 0;
  const companyName = (stock as any).companyname ?? (stock as any).company_name ?? (stock as any).name ?? stock.symbol;
  const volume = stock.volume || 0;
  
  const isPositive = change >= 0;
  const changeColor = isPositive ? '#10B981' : '#EF4444';
  const changeIcon = isPositive ? 'trending-up' : 'trending-down';

  return (
    <TouchableOpacity
      style={[
        styles.container,
        compact && styles.compactContainer,
        {
          backgroundColor: change > 0 ? 'rgba(34, 197, 94, 0.15)' : 
                           change < 0 ? 'rgba(239, 68, 68, 0.15)' : 
                           'rgba(107, 114, 128, 0.15)'
        }
      ]}
      onPress={onPress}
      activeOpacity={0.7}
    >
      {/* Company Name */}
      <View style={styles.nameContainer}>
        <Text style={styles.companyName} numberOfLines={2}>
          {companyName}
        </Text>
      </View>
      
      {/* Price */}
      <View style={styles.priceContainer}>
        <Text style={styles.price}>
          {currentPrice.toFixed(2)}p
        </Text>
      </View>
      
      {/* Change Percentage */}
      {showChange && (
        <View style={styles.changeContainer}>
          <View style={[
            styles.changeBadge, 
            { 
              backgroundColor: change > 0 ? 'rgba(34, 197, 94, 0.8)' : 
                               change < 0 ? 'rgba(239, 68, 68, 0.8)' : 
                               'rgba(107, 114, 128, 0.8)'
            }
          ]}>
            <Ionicons 
              name={changeIcon} 
              size={12} 
              color="#FFFFFF" 
            />
            <Text style={styles.changeText}>
              {changePercent.toFixed(2)}%
            </Text>
          </View>
        </View>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    borderRadius: 12,
    padding: 14,
    margin: 6,
    height: 140,
    flex: 1,
    minWidth: 110,
    borderWidth: 2,
    borderColor: 'rgba(255, 255, 255, 0.2)',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 5,
  },
  compactContainer: {
    height: 80,
    padding: 8,
  },
  nameContainer: {
    marginBottom: 10,
    flex: 1,
    minHeight: 40,
    justifyContent: 'flex-start',
  },
  companyName: {
    fontSize: 13,
    fontWeight: 'bold',
    color: '#FFFFFF',
    lineHeight: 16,
  },
  priceContainer: {
    marginBottom: 4,
  },
  price: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
  changeContainer: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  changeBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.3,
    shadowRadius: 2,
    elevation: 3,
  },
  changeText: {
    fontSize: 10,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginLeft: 3,
  },
});