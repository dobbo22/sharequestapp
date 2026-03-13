// Search bar component with stock autocomplete
import React, { useState } from 'react';
import {
  View,
  TextInput,
  FlatList,
  Text,
  TouchableOpacity,
  StyleSheet,
} from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useStockSearch } from '@/hooks/useStocks';
import { Stock } from '@/types';
import LoadingSpinner from './LoadingSpinner';

interface SearchBarProps {
  placeholder?: string;
  onStockSelect: (stock: Stock) => void;
  autoFocus?: boolean;
}

export default function SearchBar({ 
  placeholder = 'Search stocks...', 
  onStockSelect,
  autoFocus = false 
}: SearchBarProps) {
  const [showResults, setShowResults] = useState(false);
  const { searchTerm, setSearchTerm, searchResults, loading } = useStockSearch();

  const handleTextChange = (text: string) => {
    setSearchTerm(text);
    setShowResults(text.length >= 2);
  };

  const handleStockSelect = (stock: Stock) => {
    setSearchTerm('');
    setShowResults(false);
    onStockSelect(stock);
  };

  const renderStockItem = ({ item }: { item: Stock }) => (
    <TouchableOpacity
      style={styles.resultItem}
      onPress={() => handleStockSelect(item)}
    >
      <View style={styles.stockIcon}>
        <MaterialCommunityIcons name="trending-up" size={20} color="#3B82F6" />
      </View>
      <View style={styles.stockInfo}>
        <Text style={styles.companyName}>{item.companyname}</Text>
        <View style={styles.stockDetails}>
          <Text style={styles.symbol}>{item.symbol}</Text>
          {item.currentPrice > 0 && (
            <>
              <Text style={styles.separator}>•</Text>
              <Text style={styles.price}>{item.currentPrice.toFixed(2)}p</Text>
            </>
          )}
        </View>
      </View>
    </TouchableOpacity>
  );

  return (
    <View style={styles.container}>
      <View style={styles.searchContainer}>
        <MaterialCommunityIcons name="magnify" size={20} color="#6B7280" style={styles.searchIcon} />
        <TextInput
          style={styles.input}
          placeholder={placeholder}
          value={searchTerm}
          onChangeText={handleTextChange}
          autoFocus={autoFocus}
          placeholderTextColor="#9CA3AF"
          autoCapitalize="none"
          autoCorrect={false}
        />
        {searchTerm.length > 0 && (
          <TouchableOpacity
            onPress={() => {
              setSearchTerm('');
              setShowResults(false);
            }}
            style={styles.clearButton}
          >
            <MaterialCommunityIcons name="close-circle" size={20} color="#6B7280" />
          </TouchableOpacity>
        )}
      </View>

      {showResults && (
        <View style={styles.resultsContainer}>
          {loading ? (
            <View style={styles.loadingContainer}>
              <LoadingSpinner size="small" text="Searching..." />
            </View>
          ) : searchResults.length > 0 ? (
            <FlatList
              data={searchResults}
              renderItem={renderStockItem}
              keyExtractor={(item) => item.id}
              style={styles.resultsList}
              keyboardShouldPersistTaps="handled"
            />
          ) : searchTerm.length >= 2 ? (
            <View style={styles.noResultsContainer}>
              <MaterialCommunityIcons name="magnify" size={32} color="#9CA3AF" />
              <Text style={styles.noResultsText}>No stocks found</Text>
              <Text style={styles.noResultsSubtext}>
                Try searching with a different term
              </Text>
            </View>
          ) : null}
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'relative',
    zIndex: 1000,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F9FAFB',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
    marginHorizontal: 16,
    marginVertical: 8,
    borderWidth: 1,
    borderColor: '#E5E7EB',
  },
  searchIcon: {
    marginRight: 12,
  },
  input: {
    flex: 1,
    fontSize: 16,
    color: '#1F2937',
  },
  clearButton: {
    marginLeft: 8,
  },
  resultsContainer: {
    position: 'absolute',
    top: 60,
    left: 16,
    right: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.15,
    shadowRadius: 8,
    elevation: 10,
    maxHeight: 300,
    zIndex: 1000,
  },
  loadingContainer: {
    height: 120,
  },
  resultsList: {
    maxHeight: 300,
  },
  resultItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#F3F4F6',
  },
  stockIcon: {
    width: 40,
    height: 40,
    backgroundColor: '#EFF6FF',
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  stockInfo: {
    flex: 1,
  },
  companyName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1F2937',
    marginBottom: 4,
  },
  stockDetails: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  symbol: {
    fontSize: 14,
    color: '#6B7280',
  },
  separator: {
    fontSize: 14,
    color: '#9CA3AF',
    marginHorizontal: 8,
  },
  price: {
    fontSize: 14,
    color: '#6B7280',
    fontWeight: '500',
  },
  noResultsContainer: {
    alignItems: 'center',
    padding: 32,
  },
  noResultsText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#6B7280',
    marginTop: 12,
  },
  noResultsSubtext: {
    fontSize: 14,
    color: '#9CA3AF',
    marginTop: 4,
    textAlign: 'center',
  },
});